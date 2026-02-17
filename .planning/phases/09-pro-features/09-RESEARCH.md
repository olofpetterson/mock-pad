# Phase 9: PRO Features - Research

**Researched:** 2026-02-17
**Domain:** StoreKit 2 non-consumable purchase, paywall UI, PRO feature gating, purchase restoration
**Confidence:** HIGH

## Summary

Phase 9 replaces the placeholder "PRO Required" alerts with a full StoreKit 2 integration. The current codebase already has comprehensive PRO gating infrastructure: ProManager (@Observable singleton with Keychain-backed isPro state), canAddEndpoint/canImportEndpoints limit enforcement methods, and PRO-gated UI across 6 views using opacity/allowsHitTesting and conditional rendering patterns. What remains is: (1) adding StoreKit 2 Product.products() fetching and product.purchase() flow to ProManager, (2) building a ProPaywallView sheet that replaces the current basic alerts, (3) creating a StoreKit Configuration File for local testing, and (4) wiring Transaction.updates and Transaction.currentEntitlements for purchase state synchronization including restore.

The technical domain is well-understood. StoreKit 2 provides async/await APIs for product fetching, purchasing, and entitlement checking. For a single non-consumable product ($5.99 one-time purchase), the implementation is minimal: one product ID, one purchase call, one entitlement check. The existing ProManager.setPro() method already handles Keychain persistence -- StoreKit 2 adds the purchase flow that calls it. The paywall UI is a custom SwiftUI sheet themed with MockPad's Slate Blueprint design system (no SubscriptionStoreView, which is for subscriptions only).

The primary risk is testing: StoreKit 2 purchases can only be tested via Xcode's StoreKit Configuration File or TestFlight sandbox. Unit tests for the purchase flow require either protocol-based mocking of Product/Transaction types or focusing on the state management layer (ProManager) which is already tested.

**Primary recommendation:** Extend ProManager with StoreKit 2 Product.products() and product.purchase() methods, build a ProPaywallView sheet with the feature list and purchase button, replace all existing "PRO Required" alerts with paywall sheet presentation, and create a StoreKit Configuration File for local testing. Use Transaction.currentEntitlements at app launch and Transaction.updates for real-time purchase monitoring.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| StoreKit 2 | iOS 15+ (using iOS 26+) | Non-consumable in-app purchase: product fetch, purchase, entitlement check, restore | Apple's modern IAP API with async/await. Cryptographically signed transactions with on-device verification. No server-side receipt validation needed for this use case. |
| SwiftUI | iOS 26+ | ProPaywallView sheet UI with feature list, purchase button, restore button | Project's UI framework. Themed with existing MockPadColors/MockPadTypography/MockPadMetrics design tokens. |
| Observation | iOS 17+ | @Observable on ProManager for reactive isPro state across all views | Already in use. ProManager is @Observable. Purchase state changes automatically propagate to all views reading isPro. |
| Security | iOS 26+ | Keychain persistence for isPro state (already implemented) | Already in use via KeychainService. Purchase state cached in Keychain survives reinstall and is harder to tamper with than UserDefaults. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Swift Testing | Xcode 26+ | Unit tests for ProManager purchase state logic | Test canAddEndpoint/canImportEndpoints with purchase state changes. StoreKit purchase flow itself tested via StoreKit Configuration File in Xcode, not unit tests. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom ProPaywallView | ProductView (StoreKit SwiftUI) | ProductView provides Apple-styled product display with automatic price formatting, but does not allow custom feature lists, "No subscription" messaging, or themed styling. For a branded paywall with specific design requirements (feature list, price messaging, blueprint theme), a custom view is necessary. ProductView could be embedded within the custom view for the purchase button only, but adds complexity without significant benefit for a single product. |
| Custom ProPaywallView | SubscriptionStoreView | SubscriptionStoreView is designed for auto-renewable subscriptions, not one-time purchases. Not applicable to this use case. |
| Manual Product.purchase() | RevenueCat SDK | Third-party IAP wrapper. Adds external dependency (project constraint: zero dependencies). Overkill for a single non-consumable product. StoreKit 2's native API is sufficient. |
| Keychain for purchase state | StoreKit Transaction.currentEntitlements only | currentEntitlements requires iterating an async sequence. Keychain provides instant synchronous access for UI rendering. The pattern is: check Keychain first (fast), verify with currentEntitlements in background (authoritative). Both are needed. |

## Architecture Patterns

### Recommended File Structure

```
MockPad/MockPad/
├── App/
│   ├── ProManager.swift              # MODIFY: Add StoreKit 2 product fetch, purchase, restore, transaction listener
│   └── MockPadApp.swift              # MODIFY: Add StoreKit Configuration File reference in scheme (manual Xcode step)
│
├── Views/
│   ├── ProPaywallView.swift          # NEW: Full paywall sheet with feature list, purchase button, restore button
│   ├── EndpointListView.swift        # MODIFY: Replace alert with paywall sheet presentation
│   └── [other views with PRO alerts] # MODIFY: Replace alerts with paywall sheet
│
├── Theme/
│   ├── MockPadColors.swift           # EXISTING: Already has PRO color tokens (proGradientStart/End, proBorder, proBadge, lockOverlay)
│   ├── MockPadTypography.swift       # EXISTING: Already has proLabel font token
│   └── MockPadMetrics.swift          # EXISTING: Already has proOverlayBlur, lockIconSize metrics
│
└── MockPad.storekit                  # NEW: StoreKit Configuration File with non-consumable product definition
```

### Pattern 1: ProManager with StoreKit 2 Integration

**What:** Extend the existing ProManager singleton to add StoreKit 2 product fetching, purchasing, and transaction monitoring. The existing isPro/setPro/canAddEndpoint/canImportEndpoints interface remains unchanged -- StoreKit 2 becomes the mechanism that calls setPro(true).

**When to use:** This is the core integration point. All views already read proManager.isPro -- they do not need to change their gating logic.

**Why this pattern:** ProManager is already injected via .environment() everywhere. Adding StoreKit 2 methods to it keeps the purchase flow centralized. Views present the paywall sheet and call proManager.purchase() -- ProManager handles the StoreKit interaction and updates isPro.

**Example:**
```swift
// Source: Apple StoreKit 2 documentation + verified web sources
import StoreKit

@Observable
final class ProManager {
    static let shared = ProManager()
    static let freeEndpointLimit = 3
    static let productID = "com.olof.petterson.MockPad.pro"

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState {
        case idle
        case purchasing
        case purchased
        case failed(String)
        case pending
    }

    private var transactionListener: Task<Void, Never>?

    private init() {
        self.isPro = KeychainService.loadBool(forKey: "isPro") ?? false
        // Start listening for transaction updates
        transactionListener = Task {
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }

    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            // Product fetch failed -- will retry on next paywall open
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
        var found = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                found = true
                setPro(true)
                break
            }
        }
        if !found {
            purchaseState = .failed("No previous purchase found.")
        }
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
        // If we iterated all entitlements and didn't find ours, the user is not PRO
        // (handles refunds)
        if isPro {
            setPro(false)
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        if let transaction = try? result.payloadValue,
           transaction.productID == Self.productID {
            if transaction.revocationDate == nil {
                setPro(true)
            } else {
                setPro(false)
            }
            await transaction.finish()
        }
    }

    // Existing methods unchanged
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
}
```

**Gotcha:** Transaction.updates is an infinite async sequence. The listener Task must be stored and cancelled on deinit (but since ProManager is a singleton that lives for the app's lifetime, cancellation is not strictly needed -- store it for correctness). Transaction.currentEntitlements is a finite async sequence that terminates after yielding all current entitlements.

### Pattern 2: Custom ProPaywallView Sheet

**What:** A themed SwiftUI sheet that shows the PRO feature list, price, purchase button, and restore button. Replaces the current basic "PRO Required" alerts throughout the app.

**When to use:** Presented as a .sheet() when any PRO-gated action is attempted by a free tier user.

**Why this pattern:** The requirements specify a specific paywall layout: feature list, $5.99 one-time price, "No subscription" messaging. Apple's ProductView/SubscriptionStoreView cannot achieve this branded layout. A custom view themed with MockPad's Slate Blueprint design system provides full control.

**Example structure:**
```swift
struct ProPaywallView: View {
    @Environment(ProManager.self) private var proManager
    @Environment(\.dismiss) private var dismiss

    private let features = [
        ("infinity", "Unlimited Endpoints"),
        ("doc.badge.gearshape", "OpenAPI Import"),
        ("doc.text", "Custom Templates"),
        ("folder", "Collections"),
        ("clock", "Response Delay"),
        ("square.and.arrow.up", "Export & Share"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MockPadMetrics.paddingLarge) {
                    // Header
                    // Feature list
                    // Price + purchase button
                    // "No subscription" messaging
                    // Restore button
                }
            }
            .background(MockPadColors.background)
            .navigationTitle("MockPad PRO")
            .toolbar { /* dismiss */ }
        }
    }
}
```

**Design tokens already available:**
- `MockPadColors.proGradientStart`, `.proGradientEnd` -- gradient background
- `MockPadColors.proBorder` -- accent border on feature items
- `MockPadColors.proBadge` -- badge background
- `MockPadColors.lockOverlay` -- overlay color
- `MockPadTypography.proLabel` -- PRO label font
- `MockPadMetrics.proOverlayBlur`, `.lockIconSize` -- sizing

### Pattern 3: Paywall Trigger Replacement

**What:** Replace all existing "PRO Required" alerts with the paywall sheet.

**Current state (6 PRO alert triggers in the codebase):**
1. EndpointListView: `showProAlert` -- adding 4th endpoint
2. EndpointListView: `showExportProAlert` -- export to file / share
3. EndpointListView: `showOpenAPIProAlert` -- import OpenAPI spec
4. EndpointEditorView: opacity/allowsHitTesting on collection section (no alert, just disabled)
5. EndpointEditorView: opacity/allowsHitTesting on delay section (no alert, just disabled)
6. CollectionFilterChipsView: opacity/allowsHitTesting (no alert, just disabled)
7. TemplatePickerView: lock icon for custom templates (no alert)
8. ImportPreviewSheet: limit exceeded message
9. OpenAPIPreviewSheet: limit exceeded message

**Approach:** Consolidate the 3 separate alert booleans in EndpointListView into a single `showPaywall` boolean. The opacity/allowsHitTesting pattern on disabled sections can remain (they provide correct visual feedback) but should show the paywall when tapped. The import preview sheets already show inline limit messages -- these remain as-is since the paywall is triggered at the gate (before the sheet opens).

**Example:**
```swift
// Before (3 separate alerts):
.alert("PRO Required", isPresented: $showProAlert) { ... }
.alert("PRO Required", isPresented: $showExportProAlert) { ... }
.alert("PRO Required", isPresented: $showOpenAPIProAlert) { ... }

// After (1 paywall sheet):
@State private var showPaywall = false

// ... in the guard clauses:
guard proManager.isPro else {
    showPaywall = true
    return
}

.sheet(isPresented: $showPaywall) {
    ProPaywallView()
}
```

### Pattern 4: StoreKit Configuration File for Testing

**What:** A `.storekit` file in the Xcode project that defines the non-consumable product for local testing.

**When to use:** Development and testing. Xcode uses this file to simulate the App Store without requiring App Store Connect configuration.

**Setup:**
1. File > New > File > StoreKit Configuration File
2. Name: `MockPad.storekit`
3. Add Non-Consumable product:
   - Product ID: `com.olof.petterson.MockPad.pro`
   - Reference Name: "MockPad PRO"
   - Price: $5.99
4. Edit Scheme > Run > Options > StoreKit Configuration: select `MockPad.storekit`

**Testing flow:**
- Run app in Xcode, tap purchase, transaction completes locally
- Debug > StoreKit > Manage Transactions to refund/reset for re-testing
- No App Store Connect setup needed during development

### Anti-Patterns to Avoid

- **Using SubscriptionStoreView for a non-consumable:** SubscriptionStoreView is designed for auto-renewable subscription groups. It does not work with non-consumable products. Use a custom paywall view.

- **Relying only on Keychain without StoreKit verification:** The Keychain cache is fast for UI reads but must be reconciled with Transaction.currentEntitlements on app launch. A user who received a refund should have PRO revoked. Always check entitlements and update Keychain accordingly.

- **Forgetting to call transaction.finish():** Every verified transaction MUST be finished by calling `await transaction.finish()`. Unfinished transactions will be re-delivered on every app launch via Transaction.updates, causing duplicate processing.

- **Hardcoding prices in the UI:** Always use `product.displayPrice` from the fetched Product object. Apple formats the price according to the user's locale and currency. Never display "$5.99" as a string literal -- use the StoreKit-provided formatted price.

- **Blocking the main thread with product fetch:** Product.products(for:) is async. Call it early (e.g., in MockPadApp.init or on first paywall presentation) so the product is cached when the paywall appears. Show a loading state if the product is not yet fetched.

- **Making ProManager an actor:** ProManager must remain on MainActor (default isolation) because it is @Observable and injected into SwiftUI views. StoreKit 2 APIs are async but MainActor-safe. Do NOT make ProManager a custom actor.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Receipt validation | Custom receipt parsing / server-side validation | StoreKit 2 on-device VerificationResult | StoreKit 2 cryptographically signs transactions and verifies them on-device. For a $5.99 one-time purchase, server-side validation is overkill. VerificationResult.payloadValue handles verification. |
| Transaction monitoring | Custom polling or notification-based checking | Transaction.updates async sequence | Apple provides a real-time async sequence that delivers transaction changes. Handles pending purchases, refunds, and Family Sharing changes automatically. |
| Purchase restoration | Custom "re-check receipt" flow | Transaction.currentEntitlements | Iterating currentEntitlements finds all active non-consumable purchases, including those made on other devices. No manual receipt refresh needed. |
| Price formatting | String interpolation ("$5.99") | Product.displayPrice | Apple formats the price for the user's locale and currency. A Japanese user sees the yen equivalent, a European user sees euros. |

**Key insight:** StoreKit 2 eliminates most of the complexity of the original StoreKit. For a single non-consumable product, the entire purchase flow is ~50 lines of code in ProManager. The paywall UI is the larger effort.

## Common Pitfalls

### Pitfall 1: Product.products() Returns Empty Array

**What goes wrong:** `Product.products(for:)` returns an empty array, and the paywall shows no purchase option.

**Why it happens:** The product ID passed to `Product.products(for:)` does not match the ID defined in the StoreKit Configuration File (during development) or App Store Connect (in production). Even a single character difference causes a silent failure -- no error is thrown, just an empty array.

**How to avoid:** Define the product ID as a static constant (`ProManager.productID`) used both in the code and verified against the StoreKit Configuration File. Log when the products array is empty for debugging.

**Warning signs:** Paywall appears but purchase button is disabled or shows "Loading..." indefinitely.

### Pitfall 2: Transaction.finish() Never Called

**What goes wrong:** Transactions are not marked as finished. They re-appear in Transaction.updates on every app launch, causing duplicate purchase processing or unexpected state changes.

**Why it happens:** Developer handles the success case but forgets `await transaction.finish()`, or an early return skips it.

**How to avoid:** Always call `transaction.finish()` after processing a verified transaction, regardless of whether the product is already unlocked. It is safe to finish a transaction multiple times.

**Warning signs:** Transaction.updates delivers the same transaction repeatedly across app launches.

### Pitfall 3: Paywall Shows Before Product Is Loaded

**What goes wrong:** User triggers the paywall, but Product.products() has not completed yet. The paywall shows a loading spinner or empty state instead of the price and purchase button.

**Why it happens:** Product.products() is async and requires a network request on first call (cached afterward). If the user hits a PRO trigger immediately after launch, the product may not be fetched yet.

**How to avoid:** Call `proManager.loadProduct()` early -- either in MockPadApp.init() via a Task, or on the first .onAppear of the root view. The paywall should show a loading state if product is nil, then update when loaded. Pre-fetching makes the paywall feel instant in most cases.

**Warning signs:** Brief flash of loading state when opening the paywall for the first time.

### Pitfall 4: Refund Not Handled

**What goes wrong:** A user purchases PRO, then requests a refund via Apple. The app continues showing PRO features because the Keychain still has isPro = true.

**Why it happens:** Keychain is a local cache. Refunds are processed server-side. Without checking Transaction.currentEntitlements, the app never learns about the refund.

**How to avoid:** Call `checkEntitlements()` on app launch (scenePhase .active transition). If the entitlement is not found, set isPro to false. The Transaction.updates listener also handles this in real-time if the app is running when the refund is processed (the transaction's revocationDate becomes non-nil).

**Warning signs:** User support tickets about being charged and then refunded but still having PRO access.

### Pitfall 5: Concurrency Issues with @Observable and async

**What goes wrong:** Compiler warnings about mutating @Observable properties from a non-MainActor context when StoreKit 2 async methods complete.

**Why it happens:** StoreKit 2's Product.purchase() and Transaction iteration return on arbitrary contexts. Setting isPro (an @Observable property on MainActor) from these contexts triggers concurrency warnings.

**How to avoid:** Since `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, ProManager is implicitly MainActor-isolated. All its methods are MainActor by default. StoreKit 2 async calls made from MainActor methods will resume on MainActor after the await, so property mutations are safe. No special handling needed -- the default isolation handles this correctly.

**Warning signs:** Compiler warnings about "cannot mutate property from nonisolated context."

## Code Examples

Verified patterns from StoreKit 2 documentation and multiple sources:

### Fetching a Single Non-Consumable Product

```swift
// Source: Apple StoreKit 2 docs + createwithswift.com
func loadProduct() async {
    guard product == nil else { return }
    do {
        let products = try await Product.products(for: ["com.olof.petterson.MockPad.pro"])
        product = products.first
    } catch {
        // Network error or invalid product ID -- product stays nil
        // Paywall shows loading state until retry succeeds
    }
}
```

### Purchasing a Non-Consumable

```swift
// Source: Apple StoreKit 2 docs + swiftwithmajid.com + superwall.com
func purchase() async {
    guard let product else { return }
    do {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if let transaction = try? verification.payloadValue {
                setPro(true)
                await transaction.finish()
            }
        case .userCancelled:
            break // User dismissed the purchase dialog
        case .pending:
            // Purchase requires approval (e.g., Ask to Buy)
            // Transaction.updates will deliver the result later
            break
        @unknown default:
            break
        }
    } catch {
        // Purchase failed (network error, etc.)
    }
}
```

### Checking Entitlements at App Launch

```swift
// Source: Apple StoreKit 2 docs + createwithswift.com
func checkEntitlements() async {
    for await result in Transaction.currentEntitlements {
        if let transaction = try? result.payloadValue,
           transaction.productID == "com.olof.petterson.MockPad.pro",
           transaction.revocationDate == nil {
            setPro(true)
            return
        }
    }
    // No valid entitlement found -- may be a refund or never purchased
    if isPro {
        setPro(false)
    }
}
```

### Transaction Updates Listener

```swift
// Source: Apple StoreKit 2 docs + wwdcbysundell.com
// Start in init(), store as property, runs for app lifetime
transactionListener = Task {
    for await result in Transaction.updates {
        if let transaction = try? result.payloadValue,
           transaction.productID == Self.productID {
            if transaction.revocationDate == nil {
                setPro(true)
            } else {
                setPro(false)
            }
            await transaction.finish()
        }
    }
}
```

### Displaying Localized Price

```swift
// Source: Apple StoreKit 2 docs
// NEVER hardcode "$5.99" -- always use product.displayPrice
if let product = proManager.product {
    Text(product.displayPrice)
        .font(MockPadTypography.title)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| StoreKit 1 (SKProduct, SKPaymentQueue) | StoreKit 2 (Product, Transaction, async/await) | iOS 15 / WWDC21 | Modern Swift-native API with on-device verification, no receipt parsing needed |
| Server-side receipt validation | On-device VerificationResult | iOS 15 / WWDC21 | For non-consumable purchases, server-side validation is no longer necessary. StoreKit 2 cryptographically signs transactions. |
| SKStoreProductViewController for paywall | ProductView / custom SwiftUI | iOS 17 / WWDC23 | Apple provides SwiftUI views for product merchandising. Custom views give full design control. |
| Manual restore purchase button with SKPaymentQueue.restoreCompletedTransactions() | Transaction.currentEntitlements | iOS 15 / WWDC21 | Iterating currentEntitlements replaces manual restore. Apple still recommends a "Restore Purchase" button for user confidence. |
| NSNotificationCenter for transaction updates | Transaction.updates async sequence | iOS 15 / WWDC21 | Type-safe async sequence replaces notification-based observation |

**Deprecated/outdated:**
- `SKProduct`, `SKPayment`, `SKPaymentQueue`: Legacy StoreKit 1. Still works but is not recommended for new projects. StoreKit 2 is the replacement.
- `SKReceiptRefreshRequest`: Replaced by Transaction.currentEntitlements for entitlement checking.
- `appStoreReceiptURL` + receipt parsing: Replaced by on-device VerificationResult in StoreKit 2.

## Open Questions

1. **Should the paywall use ProductView for the purchase button or a fully custom button?**
   - What we know: ProductView provides automatic price formatting, purchase flow, and loading states. A custom Button with product.purchase() gives full design control.
   - What's unclear: Whether ProductView's built-in styling can be sufficiently themed to match MockPad's blueprint aesthetic.
   - Recommendation: Use a custom button calling proManager.purchase(). Display price via product.displayPrice. This keeps full design control and is simpler than fighting ProductViewStyle for a single product. The purchase() method already handles all states.

2. **Should disabled PRO sections (opacity/allowsHitTesting) also trigger the paywall?**
   - What we know: Currently, collection assignment, response delay, and collection filter chips are visually dimmed with no tap feedback. Users might not understand why these sections are unresponsive.
   - What's unclear: Whether adding paywall triggers to dimmed sections improves or hurts UX. The PRD says the paywall should appear "from any locked feature."
   - Recommendation: Add an overlay Button on the dimmed sections that presents the paywall. The opacity/allowsHitTesting pattern prevents interaction with the actual controls, and the overlay button catches taps to show the paywall. This gives users clear feedback about why the feature is locked.

3. **Where should product pre-fetching happen?**
   - What we know: Product.products() is async and may take 1-2 seconds on first call. The paywall needs the product to show the price.
   - What's unclear: Whether fetching in MockPadApp.init() (via a Task) or on first paywall presentation is better.
   - Recommendation: Fetch in a .task modifier on the root ContentView. This runs once at app launch, asynchronously, and does not block UI. The product is cached in ProManager for all subsequent paywall presentations.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation -- StoreKit 2](https://developer.apple.com/storekit/) -- Product, Transaction, VerificationResult APIs
- [Apple Developer Documentation -- Transaction.currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements) -- Entitlement checking for non-consumables
- [Apple Developer Documentation -- Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode) -- StoreKit Configuration File setup
- [WWDC21 -- Meet StoreKit 2](https://developer.apple.com/videos/play/wwdc2021/10114/) -- Architecture overview, Transaction.updates, purchase flow
- [WWDC23 -- Meet StoreKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10013/) -- ProductView, StoreView, ProductViewStyle
- Project codebase: `MockPad/MockPad/App/ProManager.swift` -- existing isPro, setPro, canAddEndpoint interface
- Project codebase: `MockPad/MockPad/Utilities/KeychainService.swift` -- existing Keychain wrapper
- Project codebase: `MockPad/MockPad/Theme/MockPadColors.swift` -- existing PRO color tokens
- Project codebase: `MockPad/MockPad/Views/EndpointListView.swift` -- existing PRO alert triggers (3 separate alerts)

### Secondary (MEDIUM confidence)
- [Implementing Non-Consumable In-App Purchases with StoreKit 2 -- createwithswift.com](https://www.createwithswift.com/implementing-non-consumable-in-app-purchases-with-storekit-2/) -- Complete non-consumable purchase flow
- [Mastering StoreKit 2 -- Swift with Majid](https://swiftwithmajid.com/2023/08/01/mastering-storekit2/) -- Product.products(), Transaction.updates, currentEntitlements patterns
- [StoreKit 2 Tutorial -- Superwall](https://superwall.com/blog/make-a-swiftui-app-with-in-app-purchases-and-subscriptions-using-storekit-2/) -- Transaction listener setup at app startup
- [Mastering StoreKit 2: ProductView -- Swift with Majid](https://swiftwithmajid.com/2023/08/08/mastering-storekit2-productview-in-swiftui/) -- ProductView and custom ProductViewStyle
- [StoreKit views guide -- RevenueCat](https://www.revenuecat.com/blog/engineering/storekit-views-guide-paywall-swift-ui/) -- ProductView vs SubscriptionStoreView comparison

### Tertiary (LOW confidence)
- None -- all findings verified with Apple documentation or multiple secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- StoreKit 2 is Apple's native IAP framework, well-documented, and the project already uses the Security framework for Keychain. No new dependencies.
- Architecture: HIGH -- ProManager extension pattern is straightforward. Existing infrastructure (isPro, setPro, Keychain, environment injection) handles 80% of the work. StoreKit 2 async/await integrates cleanly with MainActor isolation.
- Pitfalls: HIGH -- Transaction.finish() requirement, product ID matching, entitlement checking at launch, and refund handling are well-documented across multiple sources.
- Code examples: HIGH -- Patterns verified against Apple documentation and multiple tutorial sources. The non-consumable use case is the simplest StoreKit 2 scenario.

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (StoreKit 2 API is stable; 60-day window)
