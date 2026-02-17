# Phase 11: Accessibility - Research

**Researched:** 2026-02-17
**Domain:** SwiftUI Accessibility (VoiceOver, Dynamic Type, Reduce Motion, Color Blindness, Tap Targets)
**Confidence:** HIGH

## Summary

This phase adds accessibility to a fully-built SwiftUI app with 22 view files, 3 theme files, and zero existing accessibility modifiers. The codebase currently has **no** `.accessibilityLabel()`, `.accessibilityHint()`, `.accessibilityValue()`, `.accessibilityElement()`, `.accessibilityHidden()`, or `@Environment(\.accessibilityReduceMotion)` usage. There are also **no** animations in the codebase (`withAnimation`, `.animation()`, `.transition()` are all absent), which simplifies ACCS-03 considerably -- the app only needs to guard against future animation additions and handle any implicit SwiftUI animations.

The work decomposes naturally into five requirement areas that can be tackled in 2-3 plans: (1) VoiceOver labels on all interactive elements (ACCS-01), (2) Dynamic Type compliance (ACCS-02), (3) Reduce Motion support (ACCS-03), (4) HTTP method badge color luminance differentiation (ACCS-04), and (5) minimum 44pt tap targets (ACCS-05).

**Primary recommendation:** Add accessibility modifiers view-by-view using `.accessibilityElement(children: .combine)` for composite rows, `.accessibilityLabel()` for badges/icons/toggles, `@ScaledMetric` for fixed-size decorative elements, and enforce 44pt minimums via `.frame(minHeight:)` and `.contentShape()` on all chip/button targets.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI Accessibility API | iOS 17+ | `.accessibilityLabel()`, `.accessibilityElement()`, `.accessibilityHidden()`, `.accessibilityValue()`, `.accessibilityHint()`, `.accessibilityAddTraits()` | Built-in, no dependencies |
| `@ScaledMetric` | iOS 14+ | Scale fixed numeric values (icon sizes, padding) with Dynamic Type | Apple's standard property wrapper for non-text Dynamic Type scaling |
| `@Environment(\.accessibilityReduceMotion)` | iOS 14+ | Detect user's Reduce Motion preference | SwiftUI environment value, reactive |
| `@Environment(\.dynamicTypeSize)` | iOS 15+ | Detect current Dynamic Type size for layout adaptation | Enables conditional layout at accessibility sizes |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `DynamicTypeSize` enum | iOS 15+ | Compare type sizes (e.g., `.isAccessibilitySize`) | Adapt layouts when text exceeds xxxLarge |
| `UIAccessibility.isReduceMotionEnabled` | iOS 8+ | UIKit fallback for reduce motion check | Only if using `withAnimation()` wrapper function |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@ScaledMetric` for icons | Fixed `.font(.system(size:))` | Fixed sizes break Dynamic Type -- use `@ScaledMetric` |
| Manual luminance calculation | Xcode Accessibility Inspector | Inspector catches issues at dev time but not programmatically |
| `.contentShape(Rectangle())` for hit testing | `.frame(minWidth:minHeight:)` alone | `.contentShape()` extends tappable area without visual change |

**Installation:** None -- all APIs are built into SwiftUI/iOS SDK.

## Architecture Patterns

### Recommended Approach: View-by-View Audit

```
Views/                           # Add accessibility modifiers per view
  EndpointRowView.swift          # .accessibilityElement(children:), .accessibilityLabel
  RequestLogRowView.swift        # .accessibilityElement(children:), .accessibilityLabel
  LogFilterChipsView.swift       # chip .accessibilityLabel + .accessibilityAddTraits(.isSelected)
  CollectionFilterChipsView.swift # chip .accessibilityLabel + .accessibilityAddTraits(.isSelected)
  ServerStatusBarView.swift      # .accessibilityElement(children:), .accessibilityLabel, .accessibilityValue
  HTTPMethodPickerView.swift     # button .accessibilityLabel, .accessibilityAddTraits(.isSelected)
  StatusCodePickerView.swift     # button .accessibilityLabel, .accessibilityAddTraits(.isSelected)
  EmptyStateView.swift           # decorative image .accessibilityHidden
  ProPaywallView.swift           # feature rows, decorative images
  ...
Theme/
  MockPadColors.swift            # Adjust method colors for luminance differentiation
  MockPadMetrics.swift           # Already has minTouchHeight = 44, verify usage
  MockPadTypography.swift        # Already uses Font.system(.textStyle) -- good for Dynamic Type
```

### Pattern 1: Composite Row Grouping

**What:** Group multi-element rows into a single VoiceOver element with a descriptive label.
**When to use:** Any HStack/VStack that represents one conceptual item (endpoint row, log entry).

```swift
// EndpointRowView.swift
HStack(spacing: 12) {
    Text(endpoint.httpMethod).methodBadgeStyle(color: methodColor)
    Text(endpoint.path).endpointPathStyle()
    Spacer()
    Text("\(endpoint.responseStatusCode)")
    Toggle(isOn: ...) { EmptyView() }.labelsHidden()
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(endpoint.httpMethod) \(endpoint.path), status \(endpoint.responseStatusCode), \(endpoint.isEnabled ? "enabled" : "disabled")")
.accessibilityHint("Double tap to edit endpoint")
```

### Pattern 2: Toggle with Accessibility Label

**What:** Provide descriptive label for toggles that use `.labelsHidden()`.
**When to use:** Any hidden-label toggle.

```swift
Toggle(isOn: binding) { EmptyView() }
    .labelsHidden()
    .accessibilityLabel("Enable endpoint")
    .accessibilityValue(endpoint.isEnabled ? "On" : "Off")
```

### Pattern 3: Filter Chip with Selection State

**What:** Announce filter chip name and selection state.
**When to use:** LogFilterChipsView, CollectionFilterChipsView, HTTPMethodPickerView, StatusCodePickerView.

```swift
Button(action: action) {
    Text(label)
        // visual styling...
}
.accessibilityLabel("\(label) filter")
.accessibilityAddTraits(isActive ? .isSelected : [])
```

### Pattern 4: ScaledMetric for Decorative Icons

**What:** Scale fixed-size decorative SF Symbols with Dynamic Type.
**When to use:** EmptyStateView (48pt icon), RequestLogListView (40pt icons), ProPaywallView (42pt icon).

```swift
@ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 48

Image(systemName: "antenna.radiowaves.left.and.right.slash")
    .font(.system(size: iconSize))
```

### Pattern 5: Reduce Motion Guard

**What:** Wrap any animation with Reduce Motion check.
**When to use:** Currently no animations exist. Add the pattern in ServerStatusBarView (status dot could pulse) or as a utility for future use.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Apply animation only when allowed
.animation(reduceMotion ? nil : .easeInOut, value: someValue)
```

### Anti-Patterns to Avoid

- **Redundant VoiceOver announcements:** Do NOT add `.accessibilityLabel` to elements already inside a `.combine` group -- the parent label overrides children.
- **Fixed font sizes breaking Dynamic Type:** `.font(.system(size: 40))` does NOT scale with Dynamic Type. Use `@ScaledMetric` or `Font.system(.largeTitle)` instead.
- **Color-only meaning:** HTTP method badges rely solely on color. The text label ("GET", "POST") already provides text differentiation -- good. But colors must also have distinct luminance for color-blind users.
- **Decorative images not hidden:** Purely decorative SF Symbols (e.g., lock icon in paywall header, checkmarks in feature list) should use `.accessibilityHidden(true)`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dynamic Type text scaling | Manual font size math | `Font.system(.textStyle)` | Already scales automatically |
| Dynamic Type numeric scaling | Manual CGFloat scaling | `@ScaledMetric(relativeTo:)` | Apple's built-in property wrapper |
| Reduce Motion detection | Manual UserDefaults check | `@Environment(\.accessibilityReduceMotion)` | Reactive, SwiftUI-native |
| Color contrast checking | Runtime luminance calculator | Design-time Xcode Accessibility Inspector + manual hex verification | Contrast ratios are static design decisions |

**Key insight:** SwiftUI's existing font system (`.body`, `.callout`, `.caption`, etc.) already supports Dynamic Type. The typography tokens in MockPadTypography.swift use `Font.system(.textStyle)` throughout, which means text already scales. The gaps are: (1) fixed `.font(.system(size: N))` calls in 5 places, and (2) fixed frame sizes that constrain layout at large type sizes.

## Common Pitfalls

### Pitfall 1: `.accessibilityElement(children: .combine)` Swallows Toggle Actions

**What goes wrong:** Combining children on a row that contains a Toggle can prevent VoiceOver from activating the toggle independently.
**Why it happens:** `.combine` merges all children into one element -- the toggle's adjustable trait gets lost.
**How to avoid:** For EndpointRowView, keep the toggle as a separate accessibility element. Use `.accessibilityElement(children: .contain)` instead, or split the row and toggle into separate accessibility groups.
**Warning signs:** VoiceOver says "double tap to activate" but toggling doesn't work.

### Pitfall 2: Fixed Frame Heights Clipping Dynamic Type Text

**What goes wrong:** Text gets truncated at large Dynamic Type sizes because the container has a fixed height.
**Why it happens:** `MockPadMetrics.endpointCardHeight = 72` and `logRowHeight = 44` constrain row heights.
**How to avoid:** Use `minHeight` instead of fixed `height` where text content needs to grow. Already using `minHeight` on EndpointRowView (good). Check that List rows allow growth.
**Warning signs:** Text ellipsizes or clips at AX1+ text sizes.

### Pitfall 3: HStack Overflow at Large Dynamic Type

**What goes wrong:** Horizontal layouts with method badge + path + status code overflow when text is very large.
**Why it happens:** Dynamic Type scales all text, but HStack doesn't wrap.
**How to avoid:** Use `@Environment(\.dynamicTypeSize)` to switch to VStack layout at accessibility sizes, or use `.minimumScaleFactor()` on non-essential elements.
**Warning signs:** Path text truncates to nothing, badges overlap.

### Pitfall 4: Color Contrast Regression in Dark Mode

**What goes wrong:** Method badge text becomes unreadable when badge background color has similar luminance to text.
**Why it happens:** methodBadgeStyle uses `MockPadColors.background` (near-black #06060A) as foreground on colored background.
**How to avoid:** Verify each method color against the dark background text. Current colors: GET (#00FF66), POST (#FFB000), PUT (#00BFFF), PATCH (#7B68EE), DELETE (#FF4D4D). All have high luminance against the near-black text -- this is already good.
**Warning signs:** Xcode Accessibility Inspector flags contrast failures.

### Pitfall 5: ServerStatusBarView Button Too Small

**What goes wrong:** The START/STOP button text has minimal padding, creating a tap target below 44pt.
**Why it happens:** Only `paddingSmall (8)` horizontal and `paddingXSmall (4)` vertical padding applied.
**How to avoid:** Add `.frame(minWidth: 44, minHeight: 44)` or increase padding to meet the 44pt minimum.
**Warning signs:** Accessibility Inspector reports small touch target.

## Code Examples

### Example 1: EndpointRowView VoiceOver

```swift
// Current: no accessibility modifiers
// Proposed:
var body: some View {
    HStack(spacing: 12) {
        Text(endpoint.httpMethod)
            .methodBadgeStyle(color: methodColor)
            .accessibilityHidden(true)  // grouped in parent

        Text(endpoint.path)
            .endpointPathStyle()
            .lineLimit(1)
            .accessibilityHidden(true)  // grouped in parent

        Spacer()

        Text("\(endpoint.responseStatusCode)")
            .accessibilityHidden(true)  // grouped in parent

        Toggle(isOn: ...) { EmptyView() }
            .labelsHidden()
            .accessibilityLabel("\(endpoint.httpMethod) endpoint enabled")
            .accessibilityValue(endpoint.isEnabled ? "On" : "Off")
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(endpoint.httpMethod) \(endpoint.path), status \(endpoint.responseStatusCode)")
}
```

### Example 2: ServerStatusBarView Accessibility

```swift
var body: some View {
    HStack(spacing: MockPadMetrics.rowSpacing) {
        Circle()
            .fill(serverStore.isRunning ? MockPadColors.serverRunning : MockPadColors.serverStopped)
            .frame(width: MockPadMetrics.serverDotSize, height: MockPadMetrics.serverDotSize)
            .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
            Text(serverStore.isRunning ? "SERVER: RUNNING" : "SERVER: STOPPED")
            Text(serverStore.serverURL)
        }
        .accessibilityElement(children: .combine)

        Spacer()

        Button { /* toggle server */ } label: {
            Text(serverStore.isRunning ? "STOP" : "START")
        }
        .accessibilityLabel(serverStore.isRunning ? "Stop server" : "Start server")
        .accessibilityHint("Double tap to \(serverStore.isRunning ? "stop" : "start") the mock server")
        .frame(minWidth: 44, minHeight: 44)  // 44pt minimum
    }
}
```

### Example 3: Filter Chip Accessibility

```swift
private func chipButton(label: String, color: Color, isActive: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(MockPadTypography.badge)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: MockPadMetrics.minTouchHeight)  // 44pt min
    }
    .accessibilityLabel("\(label) filter")
    .accessibilityAddTraits(isActive ? .isSelected : [])
    .accessibilityRemoveTraits(isActive ? [] : .isSelected)
}
```

### Example 4: ScaledMetric for Large Icons

```swift
// Before: fixed size, doesn't scale with Dynamic Type
Image(systemName: "antenna.radiowaves.left.and.right.slash")
    .font(.system(size: 48))

// After: scales with Dynamic Type
@ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 48

Image(systemName: "antenna.radiowaves.left.and.right.slash")
    .font(.system(size: iconSize))
```

### Example 5: HTTP Method Colors with Distinct Luminance (ACCS-04)

Current method colors and their approximate relative luminance:
- GET: #00FF66 (green) -- luminance ~0.71
- POST: #FFB000 (amber) -- luminance ~0.55
- PUT: #00BFFF (sky blue) -- luminance ~0.49
- PATCH: #7B68EE (slate purple) -- luminance ~0.22
- DELETE: #FF4D4D (red) -- luminance ~0.22

**Problem:** PATCH and DELETE have nearly identical luminance (~0.22). Color-blind users (especially deuteranopia/protanopia) may struggle to distinguish them.

**Recommendation:** Adjust DELETE to a brighter/lighter red to increase luminance separation. For example:
- DELETE: #FF6B6B (lighter red) -- luminance ~0.28, or
- DELETE: #FF7070 -- luminance ~0.30

Alternatively, adjust PATCH to be darker/dimmer:
- PATCH: #6050CC (already exists as `accentSecondary`) -- luminance ~0.15

This ensures all five method colors have distinct luminance bands:
1. GET: ~0.71 (brightest)
2. POST: ~0.55
3. PUT: ~0.49
4. DELETE: ~0.28 (adjusted)
5. PATCH: ~0.15 (adjusted)

## Detailed Codebase Audit

### Files with zero accessibility modifiers (all 22 views):

| View File | Issues Found | Priority |
|-----------|-------------|----------|
| EndpointRowView | No label on row, toggle has `.labelsHidden()` with no accessibility label | HIGH |
| EndpointListView | Swipe actions need labels (already have text labels via `Label()` -- OK) | LOW |
| EndpointEditorView | Form sections auto-accessible via Form/Section -- OK but PRO overlay needs label | MEDIUM |
| RequestLogListView | Empty state icons decorative, clear log button needs label | MEDIUM |
| RequestLogRowView | No composite label on log entry row | HIGH |
| RequestDetailView | DisclosureGroups auto-accessible, copy button needs label | MEDIUM |
| LogFilterChipsView | Chips missing selection state, tap targets potentially too small | HIGH |
| CollectionFilterChipsView | Chips missing selection state, PRO overlay blocks accessibility | HIGH |
| HTTPMethodPickerView | Buttons missing selection state trait | HIGH |
| StatusCodePickerView | Buttons missing selection state trait, custom code "..." needs label | HIGH |
| ServerStatusBarView | Status dot decorative needs hiding, button too small | HIGH |
| EmptyStateView | Decorative icon needs hiding or label | LOW |
| SettingsView | Form auto-accessible -- OK, ecosystem links need labels | LOW |
| SidebarView | Same issues as EndpointListView | LOW |
| ContentView | TabView items auto-accessible -- OK | LOW |
| AddEndpointSheet | Form auto-accessible -- OK | LOW |
| ProPaywallView | Feature list needs grouping, decorative icon needs hiding, purchase button OK | MEDIUM |
| TemplatePickerView | Template buttons auto-accessible via text -- OK, PRO lock needs label | MEDIUM |
| SaveTemplateSheet | Form auto-accessible -- OK | LOW |
| ImportPreviewSheet | Method badges in rows need composite labels | MEDIUM |
| OpenAPIPreviewSheet | Checkbox buttons need labels, method badges need composite labels | MEDIUM |
| ResponseBodyEditorView | Validation badge needs label, format button OK | MEDIUM |
| ResponseHeadersEditorView | Remove button needs label, header field pairs need grouping | MEDIUM |

### Dynamic Type Issues (5 fixed-size font occurrences):

| File | Line | Current | Fix |
|------|------|---------|-----|
| EmptyStateView | 19 | `.font(.system(size: 48))` | `@ScaledMetric` |
| RequestLogListView | 81, 90, 99 | `.font(.system(size: 40))` | `@ScaledMetric` |
| ProPaywallView | 33 | `.font(.system(size: 42))` | `@ScaledMetric` |

### Tap Target Issues:

| Element | Current Size | Issue |
|---------|-------------|-------|
| Filter chips (LogFilterChipsView) | ~24pt height (6+6 padding + text) | Below 44pt |
| Collection chips (CollectionFilterChipsView) | ~24pt height | Below 44pt |
| HTTP method picker buttons | minHeight: 36 | Below 44pt |
| Status code picker buttons | minHeight: 36 | Below 44pt |
| ServerStatusBarView START/STOP button | ~20pt height (4+4 padding + text) | Well below 44pt |
| ResponseHeadersEditorView minus button | Icon only, no frame | Below 44pt |
| Custom "..." button (StatusCodePickerView) | minHeight: 36 | Below 44pt |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `UIAccessibility` labels | SwiftUI `.accessibilityLabel()` | iOS 14 (2020) | Declarative, reactive |
| Manual font scaling | `@ScaledMetric` property wrapper | iOS 14 (2020) | Automatic numeric scaling |
| `UIAccessibility.isReduceMotionEnabled` | `@Environment(\.accessibilityReduceMotion)` | iOS 14 (2020) | Reactive, no notification observer needed |
| Fixed layouts at large type | `@Environment(\.dynamicTypeSize)` + `AnyLayout` | iOS 15/16 (2021/2022) | Adaptive layout switching |
| `.accessibility(label:)` (deprecated) | `.accessibilityLabel()` | iOS 15 (2021) | New naming convention |

## Open Questions

1. **Toggle inside combined accessibility element**
   - What we know: `.accessibilityElement(children: .combine)` can swallow toggle adjustable trait
   - What's unclear: Whether `.contain` vs `.combine` works better for EndpointRowView
   - Recommendation: Use `.contain` and let toggle remain independently activatable, add `.accessibilityLabel` to the row as a whole using a separate approach. Test with VoiceOver on device.

2. **TextEditor accessibility at large Dynamic Type**
   - What we know: ResponseBodyEditorView uses `TextEditor` with `minHeight: 200`
   - What's unclear: Whether TextEditor handles very large Dynamic Type gracefully
   - Recommendation: Test at AX5 size. TextEditor should grow with content. The `minHeight` should still work since it's a minimum, not fixed.

3. **PRO overlay accessibility**
   - What we know: Color.clear overlay with `.onTapGesture` blocks taps for non-PRO users
   - What's unclear: How VoiceOver handles the overlay -- does it announce the blocked state?
   - Recommendation: Add `.accessibilityLabel("PRO feature, locked")` and `.accessibilityHint("Double tap to view PRO upgrade")` to the overlay.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: [Accessibility modifiers](https://developer.apple.com/documentation/swiftui/view-accessibility)
- Apple Developer Documentation: [DynamicTypeSize](https://developer.apple.com/documentation/swiftui/dynamictypesize)
- Apple Developer Documentation: [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- Apple HIG: [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- Codebase audit: All 22 view files, 3 theme files read and analyzed

### Secondary (MEDIUM confidence)
- SwiftUI by Example: [Detect Reduce Motion setting](https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-the-reduce-motion-accessibility-setting)
- SwiftUI by Example: [ScaledMetric](https://www.avanderlee.com/swiftui/scaledmetric-dynamic-type-support/)
- Create with Swift: [VoiceOver accessibility labels](https://www.createwithswift.com/preparing-your-app-for-voiceover-use-accessibility-label/)
- WCAG 2.1: [Use of Color](https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html)
- Hacking with Swift: [Grouping accessibility data](https://www.hackingwithswift.com/books/ios-swiftui/hiding-and-grouping-accessibility-data)

### Tertiary (LOW confidence)
- Luminance calculations for HTTP method colors are approximate (relative luminance formula applied to hex values). Exact values should be verified with Xcode Accessibility Inspector or WebAIM Contrast Checker.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All SwiftUI built-in APIs, no external dependencies
- Architecture: HIGH - View-by-view modifier addition is straightforward, codebase fully audited
- Pitfalls: HIGH - Common SwiftUI accessibility pitfalls well-documented, specific to this codebase
- Color luminance: MEDIUM - Approximate calculations, needs design-time verification

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable APIs, 30-day validity)
