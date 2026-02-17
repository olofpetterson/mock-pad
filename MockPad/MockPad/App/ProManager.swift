//
//  ProManager.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
//

import Foundation
import StoreKit

@Observable
final class ProManager {
    static let shared = ProManager()
    static let freeEndpointLimit = 3
    static let productID = "com.olof.petterson.mockpad.pro"

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var purchaseState: PurchaseState = .idle

    private var transactionListener: Task<Void, Never>?

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case failed(String)
        case pending
    }

    private init() {
        self.isPro = KeychainService.loadBool(forKey: "isPro") ?? false
        transactionListener = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }

    func setPro(_ value: Bool) {
        isPro = value
        KeychainService.saveBool(value, forKey: "isPro")
    }

    func canAddEndpoint(currentCount: Int) -> Bool {
        isPro || currentCount < 3
    }

    func canImportEndpoints(currentCount: Int, importCount: Int) -> Bool {
        isPro || (currentCount + importCount) <= 3
    }

    // MARK: - StoreKit 2

    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            // Product stays nil; paywall shows loading state
        }
    }

    func purchase() async {
        guard let product else { return }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? verification.payloadValue {
                    setPro(true)
                    purchaseState = .purchased
                    await transaction.finish()
                } else {
                    purchaseState = .failed("Purchase verification failed.")
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                setPro(true)
                return
            }
        }
        purchaseState = .failed("No previous purchase found.")
    }

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                setPro(true)
                return
            }
        }
        if isPro {
            setPro(false)
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? result.payloadValue,
              transaction.productID == Self.productID else { return }
        if transaction.revocationDate == nil {
            setPro(true)
        } else {
            setPro(false)
        }
        await transaction.finish()
    }
}
