//
//  SettingsView.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager

    @State private var portText: String = ""
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: MockPadDocument?
    @State private var importError: String?
    @State private var showImportError = false
    @State private var pendingImport: MockPadExport?
    @State private var showImportPreview = false
    @State private var showPaywall = false

    var body: some View {
        Form {
            // MARK: - SERVER
            Section {
                HStack {
                    Text("Port")
                        .foregroundStyle(MockPadColors.textPrimary)
                    Spacer()
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .foregroundStyle(MockPadColors.textPrimary)
                }

                Toggle("Localhost Only", isOn: Binding(
                    get: { serverStore.localhostOnly },
                    set: { serverStore.localhostOnly = $0 }
                ))
                .foregroundStyle(MockPadColors.textPrimary)

                Text("When enabled, server only accepts connections from this device")
                    .font(.caption)
                    .foregroundStyle(MockPadColors.textMuted)

                Toggle("CORS Headers", isOn: Binding(
                    get: { serverStore.corsEnabled },
                    set: { serverStore.corsEnabled = $0 }
                ))
                .foregroundStyle(MockPadColors.textPrimary)

                Toggle("Auto-start Server", isOn: Binding(
                    get: { serverStore.autoStart },
                    set: { serverStore.autoStart = $0 }
                ))
                .foregroundStyle(MockPadColors.textPrimary)
            } header: {
                Text("> SERVER_")
                    .font(MockPadTypography.sectionTitle)
                    .foregroundStyle(MockPadColors.accent)
            }
            .listRowBackground(MockPadColors.panel)

            // MARK: - DATA
            Section {
                Button(role: .destructive) {
                    endpointStore.clearLog()
                } label: {
                    Label("Clear Request Log", systemImage: "trash")
                }
                .accessibilityLabel("Clear request log")

                Button {
                    showImporter = true
                } label: {
                    Label("Import Endpoints", systemImage: "square.and.arrow.down.on.square")
                        .foregroundStyle(MockPadColors.textPrimary)
                }

                Button {
                    guard proManager.isPro else {
                        showPaywall = true
                        return
                    }
                    exportEndpoints()
                } label: {
                    HStack {
                        Label("Export Endpoints", systemImage: "square.and.arrow.down")
                            .foregroundStyle(MockPadColors.textPrimary)
                        Spacer()
                        if !proManager.isPro {
                            Text("PRO")
                                .font(MockPadTypography.badge)
                                .foregroundStyle(MockPadColors.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MockPadColors.accentMuted)
                                .clipShape(RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall))
                        }
                    }
                }
            } header: {
                Text("> DATA_")
                    .font(MockPadTypography.sectionTitle)
                    .foregroundStyle(MockPadColors.accent)
            }
            .listRowBackground(MockPadColors.panel)

            // MARK: - ABOUT
            Section {
                HStack {
                    Text("Version")
                        .foregroundStyle(MockPadColors.textPrimary)
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(MockPadColors.textMuted)
                }
            } header: {
                Text("> ABOUT_")
                    .font(MockPadTypography.sectionTitle)
                    .foregroundStyle(MockPadColors.accent)
            }
            .listRowBackground(MockPadColors.panel)

            // MARK: - MORE APPS
            Section {
                ecosystemLink(name: "ProbePad", subtitle: "API Client", urlString: "itms-apps://apps.apple.com/app/id6504769581")
                ecosystemLink(name: "DeltaPad", subtitle: "Developer Tools", urlString: "itms-apps://apps.apple.com/app/id6746745710")
                ecosystemLink(name: "GuardPad", subtitle: "Security Scanner", urlString: "itms-apps://apps.apple.com/app/id6756938498")
                ecosystemLink(name: "BeaconPad", subtitle: "Network Monitor", urlString: "itms-apps://apps.apple.com/app/id6764609109")
            } header: {
                Text("> MORE APPS_")
                    .font(MockPadTypography.sectionTitle)
                    .foregroundStyle(MockPadColors.accent)
            }
            .listRowBackground(MockPadColors.panel)
        }
        .scrollContentBackground(.hidden)
        .background(MockPadColors.background)
        .navigationTitle("Settings")
        .tint(MockPadColors.accent)
        .onAppear {
            portText = String(serverStore.port)
        }
        .onChange(of: portText) { _, newValue in
            guard let value = UInt16(newValue) else { return }
            let clamped = max(1024, min(65535, value))
            serverStore.port = clamped
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "endpoints.json"
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
        .sheet(isPresented: $showImportPreview, onDismiss: {
            pendingImport = nil
        }) {
            if let export = pendingImport {
                ImportPreviewSheet(export: export)
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    // MARK: - Helpers

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func exportEndpoints() {
        let endpoints = endpointStore.endpoints
        guard !endpoints.isEmpty else { return }
        do {
            exportDocument = try CollectionExporter.exportDocument(
                endpoints: endpoints,
                collectionName: nil
            )
            showExporter = true
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func ecosystemLink(name: String, subtitle: String, urlString: String) -> some View {
        Link(destination: URL(string: urlString)!) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(MockPadColors.textPrimary)
                    Text(subtitle)
                        .font(MockPadTypography.logTimestamp)
                        .foregroundStyle(MockPadColors.textMuted)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(MockPadColors.textMuted)
            }
        }
        .accessibilityLabel("\(name), \(subtitle), opens App Store")
    }
}
