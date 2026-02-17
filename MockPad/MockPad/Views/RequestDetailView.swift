//
//  RequestDetailView.swift
//  MockPad
//

import SwiftUI

struct RequestDetailView: View {
    let log: RequestLog
    @Environment(ServerStore.self) private var serverStore
    @State private var showCopiedFeedback = false
    @State private var requestExpanded = true
    @State private var responseExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MockPadMetrics.panelSpacing) {
                requestSummarySection
                requestDetailsSection
                responseDetailsSection
                copyAsCurlButton
            }
            .padding(MockPadMetrics.panelPadding)
        }
        .background(MockPadColors.background)
        .navigationTitle("\(log.method) \(log.path)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showCopiedFeedback) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showCopiedFeedback = false
                }
            }
        }
    }

    // MARK: - Section 1: Request Summary

    private var requestSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(log.method)
                    .methodBadgeStyle(color: MockPadColors.methodColor(for: log.method))

                Text(log.path)
                    .endpointPathStyle()
                    .lineLimit(1)

                Spacer()

                Text("\(log.responseStatusCode)")
                    .font(MockPadTypography.statusCode)
                    .foregroundColor(MockPadColors.statusCodeColor(code: log.responseStatusCode))
            }

            HStack {
                Text(log.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(MockPadTypography.logTimestamp)
                    .foregroundColor(MockPadColors.textMuted)

                Spacer()

                Text(String(format: "%.1fms", log.responseTimeMs))
                    .font(MockPadTypography.badge)
                    .foregroundColor(MockPadColors.textMuted)
            }
        }
        .padding(MockPadMetrics.panelContentPadding)
        .background(
            RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadius)
                .fill(MockPadColors.panel)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section 2: Request Details

    private var requestDetailsSection: some View {
        DisclosureGroup(isExpanded: $requestExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !log.queryParameters.isEmpty {
                    Text("Query Parameters")
                        .font(MockPadTypography.badge)
                        .foregroundColor(MockPadColors.textMuted)

                    ForEach(log.queryParameters.keys.sorted(), id: \.self) { key in
                        Text("\(key): \(log.queryParameters[key] ?? "")")
                            .font(MockPadTypography.monoSmall)
                            .foregroundColor(MockPadColors.textPrimary)
                    }
                }

                if !log.requestHeaders.isEmpty {
                    Text("Headers")
                        .font(MockPadTypography.badge)
                        .foregroundColor(MockPadColors.textMuted)
                        .padding(.top, log.queryParameters.isEmpty ? 0 : 4)

                    ForEach(log.requestHeaders.keys.sorted(), id: \.self) { key in
                        Text("\(key): \(log.requestHeaders[key] ?? "")")
                            .font(MockPadTypography.monoSmall)
                            .foregroundColor(MockPadColors.textPrimary)
                    }
                }

                if let body = log.requestBody, !body.isEmpty {
                    Text("Body")
                        .font(MockPadTypography.badge)
                        .foregroundColor(MockPadColors.textMuted)
                        .padding(.top, 4)

                    Text(body)
                        .codeEditorStyle()
                        .padding(MockPadMetrics.paddingSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                                .fill(MockPadColors.panel2)
                        )
                }
            }
            .padding(.top, 4)
        } label: {
            Text("> REQUEST_")
                .blueprintLabelStyle()
        }
        .tint(MockPadColors.accent)
        .padding(MockPadMetrics.panelContentPadding)
        .background(
            RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadius)
                .fill(MockPadColors.panel)
        )
    }

    // MARK: - Section 3: Response Details

    private var responseDetailsSection: some View {
        DisclosureGroup(isExpanded: $responseExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let matchedPath = log.matchedEndpointPath {
                    Text("Matched: \(matchedPath)")
                        .font(MockPadTypography.monoSmall)
                        .foregroundColor(MockPadColors.textAccent)
                }

                if !log.responseHeaders.isEmpty {
                    Text("Headers")
                        .font(MockPadTypography.badge)
                        .foregroundColor(MockPadColors.textMuted)
                        .padding(.top, log.matchedEndpointPath == nil ? 0 : 4)

                    ForEach(log.responseHeaders.keys.sorted(), id: \.self) { key in
                        Text("\(key): \(log.responseHeaders[key] ?? "")")
                            .font(MockPadTypography.monoSmall)
                            .foregroundColor(MockPadColors.textPrimary)
                    }
                }

                if let body = log.responseBody, !body.isEmpty {
                    Text("Body")
                        .font(MockPadTypography.badge)
                        .foregroundColor(MockPadColors.textMuted)
                        .padding(.top, 4)

                    Text(body)
                        .codeEditorStyle()
                        .padding(MockPadMetrics.paddingSmall)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                                .fill(MockPadColors.panel2)
                        )
                }
            }
            .padding(.top, 4)
        } label: {
            Text("> RESPONSE_")
                .blueprintLabelStyle()
        }
        .tint(MockPadColors.accent)
        .padding(MockPadMetrics.panelContentPadding)
        .background(
            RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadius)
                .fill(MockPadColors.panel)
        )
    }

    // MARK: - Section 4: Copy as cURL

    private var copyAsCurlButton: some View {
        Button {
            let curl = CurlGenerator.generate(
                method: log.method,
                path: log.path,
                headers: log.requestHeaders,
                body: log.requestBody,
                baseURL: serverStore.serverURL
            )
            UIPasteboard.general.string = curl
            showCopiedFeedback = true
        } label: {
            HStack {
                Spacer()
                Label(
                    showCopiedFeedback ? "Copied!" : "Copy as cURL",
                    systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc"
                )
                .font(MockPadTypography.button)
                .foregroundColor(MockPadColors.background)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadius)
                    .fill(MockPadColors.accent)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showCopiedFeedback ? "Copied to clipboard" : "Copy as cURL command")
    }
}
