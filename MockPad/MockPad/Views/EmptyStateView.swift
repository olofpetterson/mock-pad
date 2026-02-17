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

    var body: some View {
        VStack(spacing: MockPadMetrics.panelSpacing) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundStyle(MockPadColors.textDisabled)

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
