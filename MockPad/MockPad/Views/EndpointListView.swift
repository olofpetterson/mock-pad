//
//  EndpointListView.swift
//  MockPad
//

import SwiftUI
import UniformTypeIdentifiers

struct EndpointListView: View {
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @Environment(ProManager.self) private var proManager
    @State private var showAddSheet = false
    @State private var showProAlert = false
    @State private var syncTask: Task<Void, Never>?
    @State private var selectedCollection: String?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: MockPadDocument?
    @State private var pendingImport: MockPadExport?
    @State private var showImportPreview = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var showExportProAlert = false

    private var filteredEndpoints: [MockEndpoint] {
        selectedCollection == nil
            ? endpointStore.endpoints
            : endpointStore.endpoints.filter { $0.collectionName == selectedCollection }
    }

    private var shareExportFile: MockPadExportFile? {
        guard !filteredEndpoints.isEmpty else { return nil }
        guard let data = try? CollectionExporter.export(endpoints: filteredEndpoints, collectionName: selectedCollection) else { return nil }
        return MockPadExportFile(data: data, filename: selectedCollection ?? "endpoints")
    }

    var body: some View {
        VStack(spacing: 0) {
            CollectionFilterChipsView(selectedCollection: $selectedCollection)
                .padding(.vertical, MockPadMetrics.paddingSmall)

            List {
                ForEach(filteredEndpoints) { endpoint in
                    NavigationLink {
                        EndpointEditorView(endpoint: endpoint)
                    } label: {
                        EndpointRowView(endpoint: endpoint) { newValue in
                            endpoint.isEnabled = newValue
                            endpointStore.updateEndpoint()
                            debouncedSyncEngine()
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            duplicateEndpoint(endpoint)
                        } label: {
                            Label("Duplicate", systemImage: "square.on.square")
                        }
                        .tint(MockPadColors.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            endpointStore.deleteEndpoint(endpoint)
                            debouncedSyncEngine()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(MockPadColors.background)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveEndpoints)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MockPadColors.background)
        }
        .background(MockPadColors.background)
        .navigationTitle("Endpoints")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Export to File", systemImage: "square.and.arrow.down") {
                        guard proManager.isPro else {
                            showExportProAlert = true
                            return
                        }
                        do {
                            exportDocument = try CollectionExporter.exportDocument(
                                endpoints: filteredEndpoints,
                                collectionName: selectedCollection
                            )
                            showExporter = true
                        } catch {
                            importError = error.localizedDescription
                            showImportError = true
                        }
                    }
                    .disabled(filteredEndpoints.isEmpty)

                    if proManager.isPro, let file = shareExportFile {
                        ShareLink(
                            item: file,
                            preview: SharePreview("MockPad Endpoints", image: Image(systemName: "doc.text"))
                        )
                    } else {
                        Button("Share Collection", systemImage: "square.and.arrow.up.on.square") {
                            showExportProAlert = true
                        }
                        .disabled(!proManager.isPro || filteredEndpoints.isEmpty)
                    }

                    Divider()

                    Button("Import from File", systemImage: "square.and.arrow.down.on.square") {
                        showImporter = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if proManager.canAddEndpoint(currentCount: endpointStore.endpointCount) {
                        showAddSheet = true
                    } else {
                        showProAlert = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: (selectedCollection ?? "endpoints") + ".json"
        ) { result in
            if case .failure(let error) = result {
                importError = error.localizedDescription
                showImportError = true
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard let url = (try? result.get())?.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let export = try CollectionImporter.parse(data: data)
                pendingImport = export
                showImportPreview = true
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEndpointSheet()
        }
        .sheet(isPresented: $showImportPreview, onDismiss: {
            pendingImport = nil
            debouncedSyncEngine()
        }) {
            if let export = pendingImport {
                ImportPreviewSheet(export: export)
            }
        }
        .alert("PRO Required", isPresented: $showProAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Upgrade to PRO to add more than \(ProManager.freeEndpointLimit) endpoints.")
        }
        .alert("PRO Required", isPresented: $showExportProAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Upgrade to PRO to export endpoint collections.")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func duplicateEndpoint(_ source: MockEndpoint) {
        let maxSortOrder = endpointStore.endpoints.map(\.sortOrder).max() ?? 0
        let copy = MockEndpoint(
            path: source.path,
            httpMethod: source.httpMethod,
            responseStatusCode: source.responseStatusCode,
            responseBody: source.responseBody,
            responseHeaders: source.responseHeaders,
            isEnabled: source.isEnabled,
            sortOrder: maxSortOrder + 1,
            collectionName: source.collectionName
        )
        endpointStore.addEndpoint(copy)
        debouncedSyncEngine()
    }

    private func moveEndpoints(from source: IndexSet, to destination: Int) {
        var items = endpointStore.endpoints
        items.move(fromOffsets: source, toOffset: destination)
        for (index, endpoint) in items.enumerated() {
            endpoint.sortOrder = index
        }
        endpointStore.updateEndpoint()
        debouncedSyncEngine()
    }

    private func debouncedSyncEngine() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await serverStore.updateEngineEndpoints(endpointStore: endpointStore)
        }
    }
}
