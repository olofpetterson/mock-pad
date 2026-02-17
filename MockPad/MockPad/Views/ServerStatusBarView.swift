//
//  ServerStatusBarView.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import SwiftUI

struct ServerStatusBarView: View {
    @Environment(ServerStore.self) private var serverStore
    @Environment(EndpointStore.self) private var endpointStore

    var body: some View {
        HStack(spacing: MockPadMetrics.rowSpacing) {
            Circle()
                .fill(serverStore.isRunning ? MockPadColors.serverRunning : MockPadColors.serverStopped)
                .frame(width: MockPadMetrics.serverDotSize, height: MockPadMetrics.serverDotSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(serverStore.isRunning ? "SERVER: RUNNING" : "SERVER: STOPPED")
                    .font(MockPadTypography.serverStatus)
                    .foregroundStyle(serverStore.isRunning ? MockPadColors.serverRunning : MockPadColors.serverStopped)

                Text(serverStore.serverURL)
                    .font(MockPadTypography.logTimestamp)
                    .foregroundStyle(MockPadColors.textMuted)
            }

            Spacer()

            Button {
                Task {
                    if serverStore.isRunning {
                        await serverStore.stopServer()
                    } else {
                        await serverStore.startServer(endpointStore: endpointStore)
                    }
                }
            } label: {
                Text(serverStore.isRunning ? "STOP" : "START")
                    .font(MockPadTypography.badge)
                    .foregroundStyle(serverStore.isRunning ? MockPadColors.serverStopped : MockPadColors.serverRunning)
                    .padding(.horizontal, MockPadMetrics.paddingSmall)
                    .padding(.vertical, MockPadMetrics.paddingXSmall)
                    .background(
                        RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                            .fill((serverStore.isRunning ? MockPadColors.serverStopped : MockPadColors.serverRunning).opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, MockPadMetrics.panelPadding)
        .frame(height: MockPadMetrics.serverStatusBarHeight)
        .background(MockPadColors.panel)
        .overlay(alignment: .bottom) {
            MockPadColors.elevated
                .frame(height: 1)
        }
    }
}
