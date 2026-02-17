//
//  ProPaywallView.swift
//  MockPad
//

import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @Environment(ProManager.self) private var proManager
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String)] = [
        ("infinity", "Unlimited Endpoints"),
        ("doc.badge.gearshape", "OpenAPI Import"),
        ("doc.text", "Custom Templates"),
        ("folder", "Collections"),
        ("clock", "Response Delay"),
        ("square.and.arrow.up", "Export & Share")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MockPadMetrics.paddingLarge) {
                    // MARK: - Header
                    VStack(spacing: MockPadMetrics.paddingSmall) {
                        ZStack {
                            Circle()
                                .fill(MockPadColors.proGradientEnd)
                                .frame(width: 80, height: 80)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(MockPadColors.accent)
                        }

                        Text("MockPad PRO")
                            .font(MockPadTypography.title)
                            .foregroundStyle(MockPadColors.textPrimary)

                        Text("Unlock the full power of MockPad")
                            .font(MockPadTypography.bodySmall)
                            .foregroundStyle(MockPadColors.textMuted)
                    }
                    .padding(.top, MockPadMetrics.paddingLarge)

                    // MARK: - Feature List
                    VStack(spacing: MockPadMetrics.paddingSmall) {
                        ForEach(0..<features.count, id: \.self) { index in
                            HStack {
                                Image(systemName: features[index].icon)
                                    .foregroundStyle(MockPadColors.accent)
                                    .frame(width: 24, height: 24)

                                Text(features[index].title)
                                    .font(MockPadTypography.monoSmall)
                                    .foregroundStyle(MockPadColors.textPrimary)

                                Spacer()

                                Image(systemName: "checkmark")
                                    .foregroundStyle(MockPadColors.accent)
                                    .opacity(0.6)
                            }
                            .padding(MockPadMetrics.panelContentPadding)
                            .background(MockPadColors.panel)
                            .cornerRadius(MockPadMetrics.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadius)
                                    .stroke(MockPadColors.proBorder, lineWidth: MockPadMetrics.borderWidth)
                            )
                        }
                    }

                    // MARK: - Price
                    VStack(spacing: MockPadMetrics.paddingXSmall) {
                        if let product = proManager.product {
                            Text(product.displayPrice)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(MockPadColors.accent)

                            Text("One-time purchase")
                                .font(MockPadTypography.bodySmall)
                                .foregroundStyle(MockPadColors.textMuted)

                            Text("No subscription. Pay once, unlock forever.")
                                .font(MockPadTypography.bodySmall)
                                .foregroundStyle(MockPadColors.textMuted)
                        } else {
                            ProgressView()
                            Text("Loading...")
                                .font(MockPadTypography.bodySmall)
                                .foregroundStyle(MockPadColors.textMuted)
                        }
                    }

                    // MARK: - Purchase Button
                    VStack(spacing: MockPadMetrics.paddingSmall) {
                        Button {
                            Task { await proManager.purchase() }
                        } label: {
                            Group {
                                if proManager.purchaseState == .purchasing {
                                    ProgressView()
                                } else {
                                    Text("Unlock PRO")
                                        .font(MockPadTypography.button)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(MockPadColors.accent)
                        .disabled(proManager.product == nil || proManager.purchaseState == .purchasing)

                        // Error display
                        if case .failed(let message) = proManager.purchaseState {
                            Text(message)
                                .font(MockPadTypography.bodySmall)
                                .foregroundStyle(MockPadColors.status5xx)
                                .multilineTextAlignment(.center)
                        }

                        // Pending display
                        if proManager.purchaseState == .pending {
                            Text("Purchase pending approval.")
                                .font(MockPadTypography.bodySmall)
                                .foregroundStyle(MockPadColors.status4xx)
                        }
                    }

                    // MARK: - Restore
                    VStack(spacing: MockPadMetrics.paddingXSmall) {
                        Button("Restore Purchase") {
                            Task { await proManager.restorePurchases() }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MockPadColors.accent)
                        .font(MockPadTypography.bodySmall)

                        Text("Previously purchased? Tap to restore.")
                            .font(MockPadTypography.logTimestamp)
                            .foregroundStyle(MockPadColors.textMuted)
                    }
                    .padding(.bottom, MockPadMetrics.paddingLarge)
                }
                .padding(.horizontal, MockPadMetrics.panelPadding)
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [MockPadColors.proGradientStart, MockPadColors.proGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("MockPad PRO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onChange(of: proManager.isPro) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}
