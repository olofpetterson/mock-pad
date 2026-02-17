//
//  CollectionFilterChipsView.swift
//  MockPad
//

import SwiftUI

struct CollectionFilterChipsView: View {
    @Binding var selectedCollection: String?
    @Environment(EndpointStore.self) private var endpointStore
    @Environment(ProManager.self) private var proManager
    @State private var showPaywall = false

    var body: some View {
        let names = endpointStore.collectionNames
        if !names.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chipButton(
                        label: "All",
                        isActive: selectedCollection == nil
                    ) {
                        selectedCollection = nil
                    }

                    ForEach(names, id: \.self) { name in
                        chipButton(
                            label: name,
                            isActive: selectedCollection == name
                        ) {
                            if selectedCollection == name {
                                selectedCollection = nil
                            } else {
                                selectedCollection = name
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, MockPadMetrics.panelPadding)
            .opacity(proManager.isPro ? 1 : 0.4)
            .allowsHitTesting(proManager.isPro)
            .overlay {
                if !proManager.isPro {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showPaywall = true }
                        .accessibilityLabel("Collections require PRO")
                        .accessibilityHint("Double tap to view PRO upgrade")
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }

    private func chipButton(
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(MockPadTypography.badge)
                .foregroundColor(isActive ? MockPadColors.background : MockPadColors.accent)
                .padding(.horizontal, 12)
                .frame(minHeight: MockPadMetrics.minTouchHeight)
                .background(isActive ? MockPadColors.accent : MockPadColors.panel2)
                .cornerRadius(MockPadMetrics.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: MockPadMetrics.cornerRadiusSmall)
                        .stroke(isActive ? MockPadColors.accent : MockPadColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) collection filter")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityRemoveTraits(isActive ? [] : .isSelected)
    }
}
