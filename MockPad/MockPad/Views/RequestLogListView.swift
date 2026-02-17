//
//  RequestLogListView.swift
//  MockPad
//

import SwiftData
import SwiftUI

struct RequestLogListView: View {
    @Query(sort: \RequestLog.timestamp, order: .reverse) private var logs: [RequestLog]
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @State private var activeMethodFilters: Set<String> = []
    @State private var activeStatusFilters: Set<String> = []
    @State private var searchText: String = ""
    @ScaledMetric(relativeTo: .title) private var emptyIconSize: CGFloat = 40

    private var filteredLogs: [RequestLog] {
        logs.filter { log in
            let matchesMethod = activeMethodFilters.isEmpty || activeMethodFilters.contains(log.method.uppercased())
            let matchesStatus = activeStatusFilters.isEmpty || activeStatusFilters.contains(statusCategory(log.responseStatusCode))
            let matchesSearch = searchText.isEmpty || log.path.localizedCaseInsensitiveContains(searchText)
            return matchesMethod && matchesStatus && matchesSearch
        }
    }

    private func statusCategory(_ code: Int) -> String {
        switch code {
        case 200..<300: return "2xx"
        case 400..<500: return "4xx"
        case 500..<600: return "5xx"
        default: return "other"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            LogFilterChipsView(
                activeMethodFilters: $activeMethodFilters,
                activeStatusFilters: $activeStatusFilters
            )
            .padding(.vertical, 8)

            if filteredLogs.isEmpty {
                emptyStateView
            } else {
                List(filteredLogs) { log in
                    NavigationLink {
                        RequestDetailView(log: log)
                    } label: {
                        RequestLogRowView(log: log)
                    }
                    .listRowBackground(MockPadColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(MockPadColors.background)
            }
        }
        .searchable(text: $searchText, prompt: "Filter by path...")
        .navigationTitle("Request Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    endpointStore.clearLog()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Clear request log")
                .disabled(logs.isEmpty)
            }
        }
        .background(MockPadColors.background)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()
            if !serverStore.isRunning && logs.isEmpty {
                Image(systemName: "server.rack")
                    .font(.system(size: emptyIconSize))
                    .foregroundColor(MockPadColors.textDisabled)
                    .accessibilityHidden(true)
                    .padding(.bottom, 8)
                Text("Start the server to begin logging requests.")
                    .font(MockPadTypography.bodySmall)
                    .foregroundColor(MockPadColors.textMuted)
                    .multilineTextAlignment(.center)
            } else if logs.isEmpty {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: emptyIconSize))
                    .foregroundColor(MockPadColors.textDisabled)
                    .accessibilityHidden(true)
                    .padding(.bottom, 8)
                Text("Waiting for requests...")
                    .font(MockPadTypography.bodySmall)
                    .foregroundColor(MockPadColors.textMuted)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: emptyIconSize))
                    .foregroundColor(MockPadColors.textDisabled)
                    .accessibilityHidden(true)
                    .padding(.bottom, 8)
                Text("No requests match your filters.")
                    .font(MockPadTypography.bodySmall)
                    .foregroundColor(MockPadColors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
                Button("Clear Filters") {
                    activeMethodFilters = []
                    activeStatusFilters = []
                    searchText = ""
                }
                .font(MockPadTypography.buttonSmall)
                .foregroundColor(MockPadColors.accent)
            }
            Spacer()
        }
    }
}
