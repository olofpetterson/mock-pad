//
//  TemplatePickerView.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import SwiftUI
import SwiftData

struct TemplatePickerView: View {
    @Bindable var endpoint: MockEndpoint
    var onApplied: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(ProManager.self) private var proManager

    @Query(sort: \ResponseTemplate.createdAt, order: .reverse)
    private var customTemplates: [ResponseTemplate]

    @State private var showingSaveSheet = false

    var body: some View {
        Section {
            ForEach(BuiltInTemplates.all) { template in
                Button {
                    applyTemplate(template)
                } label: {
                    HStack {
                        Image(systemName: template.icon)
                            .foregroundStyle(MockPadColors.accent)
                        Text(template.name)
                            .font(MockPadTypography.monoSmall)
                        Spacer()
                        Text("\(template.statusCode)")
                            .font(MockPadTypography.badge)
                            .foregroundStyle(MockPadColors.statusCodeColor(code: template.statusCode))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                MockPadColors.statusCodeColor(code: template.statusCode).opacity(0.15)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall))
                    }
                }
                .listRowBackground(MockPadColors.panel)
            }
        } header: {
            Text("> TEMPLATES_")
                .blueprintLabelStyle()
        }

        if !customTemplates.isEmpty || proManager.isPro {
            Section {
                if proManager.isPro {
                    ForEach(customTemplates) { ct in
                        Button {
                            applyCustomTemplate(ct)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(MockPadColors.accent)
                                Text(ct.name)
                                    .font(MockPadTypography.monoSmall)
                                Spacer()
                                Text("\(ct.statusCode)")
                                    .font(MockPadTypography.badge)
                                    .foregroundStyle(MockPadColors.statusCodeColor(code: ct.statusCode))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        MockPadColors.statusCodeColor(code: ct.statusCode).opacity(0.15)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall))
                            }
                        }
                        .listRowBackground(MockPadColors.panel)
                    }
                    .onDelete(perform: deleteCustomTemplate)

                    Button {
                        showingSaveSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Save Current as Template")
                        }
                        .foregroundStyle(MockPadColors.accent)
                    }
                    .listRowBackground(MockPadColors.panel)
                } else {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(MockPadColors.accent)
                        Text("PRO")
                            .font(MockPadTypography.proLabel)
                            .foregroundStyle(MockPadColors.accent)
                    }
                    .listRowBackground(MockPadColors.panel)
                }
            } header: {
                Text("> CUSTOM TEMPLATES_")
                    .blueprintLabelStyle()
            }
        }

        EmptyView()
            .sheet(isPresented: $showingSaveSheet) {
                SaveTemplateSheet(endpoint: endpoint)
            }
    }

    // MARK: - Actions

    private func applyTemplate(_ template: BuiltInTemplates.Template) {
        endpoint.responseStatusCode = template.statusCode
        endpoint.responseBody = template.responseBody
        endpoint.responseHeaders = template.responseHeaders
        onApplied()
    }

    private func applyCustomTemplate(_ ct: ResponseTemplate) {
        endpoint.responseStatusCode = ct.statusCode
        endpoint.responseBody = ct.responseBody
        endpoint.responseHeaders = ct.responseHeaders
        onApplied()
    }

    private func deleteCustomTemplate(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(customTemplates[index])
        }
        try? modelContext.save()
    }
}
