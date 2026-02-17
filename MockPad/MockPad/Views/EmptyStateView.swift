//
//  EmptyStateView.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import SwiftUI

struct EmptyStateView: View {
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ServerStore.self) private var serverStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion // Reduce Motion: guard any future animations with this property (ACCS-03)
    @ScaledMetric(relativeTo: .largeTitle) private var emptyIconSize: CGFloat = 48

    var body: some View {
        VStack(spacing: MockPadMetrics.panelSpacing) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: emptyIconSize))
                .foregroundStyle(MockPadColors.textDisabled)
                .accessibilityHidden(true)

            Text("No Endpoints")
                .font(MockPadTypography.sectionTitle)
                .foregroundStyle(MockPadColors.textMuted)

            Text("Create a sample REST API to get started")
                .font(MockPadTypography.bodySmall)
                .foregroundStyle(MockPadColors.textMuted)

            Button {
                createSampleAPI()
            } label: {
                Text("Create Sample API")
            }
            .buttonStyle(.bordered)
            .foregroundStyle(MockPadColors.accent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(MockPadColors.background)
    }

    private func createSampleAPI() {
        let endpoints = SampleEndpointGenerator.createSampleEndpoints()
        for endpoint in endpoints {
            endpointStore.addEndpoint(endpoint)
        }
        Task {
            await serverStore.startServer(endpointStore: endpointStore)
        }
    }
}
