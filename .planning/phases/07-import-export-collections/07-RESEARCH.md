# Phase 7: Import/Export + Collections - Research

**Researched:** 2026-02-17
**Domain:** SwiftData collections model, JSON export/import, iOS share sheet, duplicate handling
**Confidence:** HIGH

## Summary

Phase 7 adds three capabilities: endpoint collections (grouping endpoints by name), JSON export/import (data portability), and iOS share sheet integration. The technical domain spans SwiftData relationship modeling (MockEndpoint belongs to an optional EndpointCollection), Codable-based JSON serialization for a custom export format, SwiftUI `fileImporter`/`fileExporter` modifiers for file I/O, and `ShareLink` with `Transferable` for sharing. Duplicate detection during import requires a user-choice UI (skip/replace/import as new) implemented via `.confirmationDialog()`.

The codebase already has the patterns needed: `@Model` with JSON-encoded Data fields, `@Observable` EndpointStore with CRUD, ProManager for PRO gating, and the `Group + opacity/allowsHitTesting` pattern for PRO feature UI lockout. The primary new challenge is the SwiftData relationship between MockEndpoint and a new EndpointCollection model, the JSON export format design (versioned, self-describing), and security-scoped file access during import.

The app has NOT shipped yet (still in development through Phase 6), so SwiftData schema changes can be made without VersionedSchema migration -- no users have existing data stores. The new EndpointCollection model can be added directly to the ModelContainer registration alongside the existing models. This significantly simplifies the data layer work.

**Primary recommendation:** Add an optional `collectionName: String?` property to MockEndpoint (no relationship model needed -- simple string grouping avoids SwiftData many-to-many complexity). Build a Codable `MockPadExport` struct for the JSON format. Use `fileExporter`/`fileImporter` for file I/O and `ShareLink` with `FileRepresentation` for sharing. Use `.confirmationDialog()` for duplicate resolution.

## Standard Stack

### Core

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftData | iOS 26+ | Add optional `collectionName` to MockEndpoint, persist collections | Already in use. Adding an optional String property is the simplest migration-safe approach. |
| SwiftUI | iOS 26+ | `fileImporter`, `fileExporter`, `ShareLink`, `confirmationDialog` for UI | Native file I/O and sharing modifiers. No UIKit wrapping needed. |
| UniformTypeIdentifiers | iOS 26+ | `UTType.json` for file type identification in import/export | Required by `fileImporter`/`fileExporter` to specify allowed content types. |
| Foundation | iOS 26+ | `JSONEncoder`/`JSONDecoder` for export format, `FileManager` for temp files | Standard serialization. Zero dependencies. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| CoreTransferable | iOS 16+ | `Transferable` protocol conformance for `ShareLink` file sharing | MockPadExportFile type conforms to Transferable with FileRepresentation for share sheet. |
| Swift Testing | Xcode 26+ | Unit tests for export/import service, collection filtering, duplicate detection | All test files in this phase. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `collectionName: String?` on MockEndpoint | Separate `EndpointCollection` @Model with @Relationship | SwiftData many-to-many relationships are fragile (iOS 17 alphabetical ordering bug, must insert before manipulating arrays). A simple optional String is migration-safe, queryable via `#Predicate`, and avoids relationship complexity. Endpoints that belong to no collection have `nil`. Collections are derived from distinct `collectionName` values. |
| `fileExporter` + `FileDocument` | Writing to temp file + `UIActivityViewController` | `fileExporter` is the SwiftUI-native approach, handles the Files app picker UI automatically. `ShareLink` with `Transferable` covers the share sheet. No need for UIKit bridging. |
| Custom `.mockpad` UTType | Standard `.json` UTType | A custom UTType requires Info.plist `UTExportedTypeDeclarations` and system registration. Since the export format is plain JSON, using `.json` is simpler and more portable. Users can open the file in any JSON viewer. The file content includes a `"format": "mockpad-collection"` key for identification on import. |
| `confirmationDialog` for duplicates | Custom sheet with preview | `confirmationDialog` is the standard iOS pattern for 3+ action choices. Cleaner, simpler, and matches platform conventions. |

## Architecture Patterns

### Recommended Project Structure

```
MockPad/MockPad/
├── Models/
│   └── MockEndpoint.swift          # ADD: optional collectionName: String?
│
├── Services/
│   ├── CollectionExporter.swift    # NEW: Codable export format, JSON encoding
│   └── CollectionImporter.swift    # NEW: JSON decoding, duplicate detection, import logic
│
├── Views/
│   ├── EndpointListView.swift      # MODIFY: collection filter chips/picker
│   ├── EndpointEditorView.swift    # MODIFY: collection assignment section (PRO)
│   ├── CollectionManagerView.swift # NEW: create/rename/delete collections
│   └── ImportPreviewSheet.swift    # NEW: import preview with duplicate resolution
│
└── App/
    ├── EndpointStore.swift         # MODIFY: collection CRUD, filtered queries
    └── MockPadApp.swift            # NO CHANGE: no new @Model types needed
```

### Pattern 1: Optional String for Collection Grouping (Not a Relationship)

**What:** Add `var collectionName: String?` to MockEndpoint. Endpoints with `nil` belong to no collection. Collections are derived dynamically from distinct non-nil `collectionName` values.

**When to use:** When the grouping is simple (name-based), many-to-one, and doesn't require metadata on the collection itself (no collection icon, no collection description).

**Why this pattern:** SwiftData many-to-many relationships require `@Relationship(inverse:)`, both models inserted before array manipulation, and have had platform bugs (iOS 17 alphabetical ordering). A String property avoids all of this complexity. It is queryable via `#Predicate { $0.collectionName == name }`, sortable, and migration-safe (optional property with nil default = lightweight migration).

**Example:**
```swift
// Adding to existing MockEndpoint model
@Model
final class MockEndpoint {
    // ... existing properties ...
    var collectionName: String?  // nil = no collection, "My API" = belongs to "My API" collection

    // ... existing init gains new parameter ...
    init(
        path: String,
        // ... existing params ...
        collectionName: String? = nil
    ) {
        // ... existing assignments ...
        self.collectionName = collectionName
    }
}
```

**Deriving collections list:**
```swift
// In EndpointStore
var collectionNames: [String] {
    let names = Set(endpoints.compactMap(\.collectionName))
    return names.sorted()
}
```

### Pattern 2: Versioned JSON Export Format

**What:** A Codable struct hierarchy that serializes endpoint collections to a self-describing JSON format with a version number for forward compatibility.

**When to use:** Every export operation produces this format. Every import operation parses it.

**Why this pattern:** Including a `version` field allows future format changes without breaking older exports. The `format` field identifies the file as a MockPad export (important since we use standard `.json` extension, not a custom UTType).

**Example:**
```swift
// Source: JSON format design best practices
struct MockPadExport: Codable {
    let format: String           // "mockpad-collection" (constant identifier)
    let version: Int             // 1 (increment on breaking changes)
    let exportedAt: Date
    let collectionName: String?  // nil if exporting unassigned endpoints
    let endpoints: [ExportedEndpoint]
}

struct ExportedEndpoint: Codable {
    let path: String
    let httpMethod: String
    let responseStatusCode: Int
    let responseBody: String
    let responseHeaders: [String: String]
    let isEnabled: Bool
    let responseDelayMs: Int
}
```

### Pattern 3: FileDocument for Export

**What:** A `FileDocument` conforming struct that wraps JSON-encoded `MockPadExport` data for use with `fileExporter`.

**When to use:** When the user taps "Export" on a collection.

**Example:**
```swift
import UniformTypeIdentifiers

struct MockPadDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(export: MockPadExport) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.data = try encoder.encode(export)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
```

### Pattern 4: ShareLink with Transferable for Share Sheet

**What:** A `Transferable` conforming struct that writes the export JSON to a temp file and provides it via `FileRepresentation` for the iOS share sheet.

**When to use:** When the user taps "Share" on an exported collection.

**Example:**
```swift
struct MockPadExportFile: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { exportFile in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(exportFile.filename)
                .appendingPathExtension("json")
            try exportFile.data.write(to: tempURL)
            return SentTransferredFile(tempURL)
        }
    }
}

// In view:
ShareLink(
    item: MockPadExportFile(data: jsonData, filename: collectionName ?? "endpoints"),
    preview: SharePreview("MockPad Endpoints", image: Image(systemName: "doc.text"))
)
```

### Pattern 5: Duplicate Detection on Import

**What:** When importing endpoints, compare each imported endpoint against existing endpoints by path + method combination. If duplicates are found, present a `.confirmationDialog()` with skip/replace/import-as-new options.

**When to use:** Every import operation that finds matching path+method pairs.

**Example:**
```swift
enum DuplicateResolution: String, CaseIterable {
    case skip = "Skip"
    case replace = "Replace Existing"
    case importAsNew = "Import as New"
}

// Detection:
func findDuplicates(
    imported: [ExportedEndpoint],
    existing: [MockEndpoint]
) -> [ExportedEndpoint] {
    imported.filter { imp in
        existing.contains { ex in
            ex.path == imp.path && ex.httpMethod == imp.httpMethod
        }
    }
}
```

### Pattern 6: Security-Scoped File Access on Import

**What:** Files selected via `fileImporter` from outside the app sandbox require security-scoped access. Always call `startAccessingSecurityScopedResource()` before reading and `stopAccessingSecurityScopedResource()` after.

**When to use:** Every `fileImporter` completion handler.

**Example:**
```swift
.fileImporter(
    isPresented: $showImporter,
    allowedContentTypes: [.json],
    allowsMultipleSelection: false
) { result in
    guard let url = try? result.get().first else { return }
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }

    guard let data = try? Data(contentsOf: url) else { return }
    // Parse and validate MockPadExport from data...
}
```

### Anti-Patterns to Avoid

- **SwiftData @Relationship for simple grouping:** Many-to-many relationships in SwiftData have known bugs and require careful insertion ordering. A simple optional String property is sufficient for collection membership and avoids all relationship complexity.

- **Custom UTType for exports:** Declaring `UTExportedTypeDeclarations` in Info.plist for a custom file type is unnecessary when the content is standard JSON. Use `.json` UTType and include a `format` identifier field in the JSON content itself.

- **UIActivityViewController via UIViewControllerRepresentable:** SwiftUI's `ShareLink` with `Transferable` replaces the need for UIKit bridging. Available since iOS 16, fully native SwiftUI.

- **Asking per-duplicate during batch import:** For batch imports with many duplicates, showing a dialog for each duplicate is unusable. Provide a single "Apply to All" choice or let the user choose once for the entire batch.

- **Exporting without `.sortedKeys`:** JSON output without sorted keys produces non-deterministic output. Use `JSONEncoder.OutputFormatting.sortedKeys` for consistent, testable output.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File picker UI | Custom document browser | `fileImporter` / `fileExporter` SwiftUI modifiers | Native, handles security scoping, sandbox-aware |
| Share sheet | UIActivityViewController wrapper | `ShareLink` with `Transferable` | Pure SwiftUI, no UIKit bridging needed |
| JSON serialization | Custom string building | `JSONEncoder`/`JSONDecoder` with Codable | Type-safe, handles escaping, date formatting, nested objects |
| File type identification | Manual extension checking | `UniformTypeIdentifiers` UTType.json | System-level type identification, forward-compatible |
| Temp file management | Manual temp directory cleanup | `FileManager.default.temporaryDirectory` | OS manages cleanup of temp files automatically |

**Key insight:** Every file I/O and sharing component uses Apple's built-in SwiftUI modifiers. The only custom code needed is the JSON format definition (Codable structs), the duplicate detection logic, and the collection management UI.

## Common Pitfalls

### Pitfall 1: fileImporter Security Scope Not Accessed

**What goes wrong:** Reading a file selected via `fileImporter` fails with a permission error because the security-scoped resource was not accessed.

**Why it happens:** Files selected from outside the app sandbox (e.g., iCloud Drive, other app containers) require explicit security scope access. The URL returned by `fileImporter` has an associated security token that must be activated.

**How to avoid:** Always call `url.startAccessingSecurityScopedResource()` before reading, and `url.stopAccessingSecurityScopedResource()` after (use `defer`). Check the return value -- if `false`, the URL is already accessible (within sandbox).

**Warning signs:** `NSCocoaErrorDomain Code=257` "The file couldn't be opened because you don't have permission to view it."

### Pitfall 2: SwiftData Model Changes Without Migration

**What goes wrong:** Adding a new property to MockEndpoint causes a crash on launch for users with existing data.

**Why it happens:** SwiftData requires either a lightweight-compatible change (optional property with nil default, or property with default value) or an explicit VersionedSchema migration.

**How to avoid:** Since the app has NOT shipped yet (still in Phase 6 development), no migration is needed. Adding `collectionName: String?` (optional, defaults to nil) is a safe additive change even if there were existing data. No VersionedSchema required.

**Warning signs:** `fatalError("Could not create ModelContainer")` on launch after adding new properties.

### Pitfall 3: JSON Import Format Validation Missing

**What goes wrong:** Importing a non-MockPad JSON file (or a corrupt file) crashes the app or silently inserts garbage data.

**Why it happens:** The app assumes the JSON file is a valid MockPadExport without checking the `format` and `version` fields.

**How to avoid:** Parse the JSON into `MockPadExport`, verify `format == "mockpad-collection"` and `version == 1` before processing. Show a user-facing error alert if validation fails. Handle `DecodingError` gracefully.

**Warning signs:** App crashes when importing a random `.json` file. Endpoints appear with empty paths or invalid HTTP methods.

### Pitfall 4: Duplicate Detection by Path Only (Ignoring Method)

**What goes wrong:** GET /api/users and POST /api/users are treated as duplicates when they are distinct endpoints.

**Why it happens:** Duplicate detection compares only the path, not the path+method combination.

**How to avoid:** Use the (path, httpMethod) tuple as the uniqueness key for duplicate detection. Two endpoints with the same path but different methods are NOT duplicates.

**Warning signs:** Import reports false positives for endpoints that differ only by HTTP method.

### Pitfall 5: PRO Gating Allows Import to Bypass Endpoint Limit

**What goes wrong:** A free-tier user imports a collection of 10 endpoints, bypassing the 3-endpoint limit.

**Why it happens:** The import path does not check `ProManager.canImportEndpoints()` before inserting.

**How to avoid:** Check `proManager.canImportEndpoints(currentCount:importCount:)` before allowing import to proceed. The ProManager already has this method from Phase 1. Import is available to all users, but collections (organizing endpoints) and export are PRO-only.

**Warning signs:** Free users end up with more than 3 endpoints after importing.

### Pitfall 6: Export Includes responseDelayMs But Import on Free Tier

**What goes wrong:** An exported collection includes PRO-only fields (responseDelayMs). When imported by a free user, the delay is applied even though delay is a PRO feature.

**Why it happens:** The import blindly copies all fields from the export format without PRO-checking individual features.

**How to avoid:** Import all fields including responseDelayMs. The delay is stored on the model but is only applied when the server runs (and the server delay feature is PRO-gated at the UI level, not the model level). This is acceptable -- the data is stored but the PRO gating in the editor prevents free users from changing it. When they upgrade, their imported endpoints already have the correct delay values.

**Warning signs:** None -- this is actually the correct behavior. Store the data, gate the UI.

## Code Examples

Verified patterns from project conventions and Apple documentation:

### Collection Filtering in EndpointStore

```swift
// Source: Existing EndpointStore pattern + SwiftData FetchDescriptor
func endpoints(inCollection name: String?) -> [MockEndpoint] {
    let descriptor = FetchDescriptor<MockEndpoint>(
        predicate: #Predicate<MockEndpoint> { endpoint in
            endpoint.collectionName == name
        },
        sortBy: [SortDescriptor(\.sortOrder)]
    )
    return (try? modelContext.fetch(descriptor)) ?? []
}
```

### Export Service (caseless enum pattern)

```swift
// Source: Matches BuiltInTemplates, EndpointMatcher, PathParamReplacer caseless enum pattern
enum CollectionExporter {
    static func export(
        endpoints: [MockEndpoint],
        collectionName: String?
    ) throws -> Data {
        let exported = endpoints.map { ep in
            ExportedEndpoint(
                path: ep.path,
                httpMethod: ep.httpMethod,
                responseStatusCode: ep.responseStatusCode,
                responseBody: ep.responseBody,
                responseHeaders: ep.responseHeaders,
                isEnabled: ep.isEnabled,
                responseDelayMs: ep.responseDelayMs
            )
        }
        let exportData = MockPadExport(
            format: "mockpad-collection",
            version: 1,
            exportedAt: Date(),
            collectionName: collectionName,
            endpoints: exported
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportData)
    }
}
```

### Import Service with Duplicate Detection

```swift
// Source: Matches caseless enum service pattern
enum CollectionImporter {
    enum ImportError: Error, LocalizedError {
        case invalidFormat
        case unsupportedVersion(Int)
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "This file is not a MockPad export."
            case .unsupportedVersion(let v): return "Unsupported export version: \(v)"
            case .decodingFailed(let msg): return "Failed to read file: \(msg)"
            }
        }
    }

    static func parse(data: Data) throws -> MockPadExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export: MockPadExport
        do {
            export = try decoder.decode(MockPadExport.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }
        guard export.format == "mockpad-collection" else {
            throw ImportError.invalidFormat
        }
        guard export.version == 1 else {
            throw ImportError.unsupportedVersion(export.version)
        }
        return export
    }

    static func findDuplicates(
        imported: [ExportedEndpoint],
        existing: [MockEndpoint]
    ) -> [ExportedEndpoint] {
        imported.filter { imp in
            existing.contains { ex in
                ex.path.lowercased() == imp.path.lowercased()
                    && ex.httpMethod.uppercased() == imp.httpMethod.uppercased()
            }
        }
    }
}
```

### Import with fileImporter + Security Scope

```swift
// Source: Apple docs + useyourloaf.com security-scoped access pattern
.fileImporter(
    isPresented: $showImporter,
    allowedContentTypes: [.json],
    allowsMultipleSelection: false
) { result in
    switch result {
    case .success(let urls):
        guard let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let export = try CollectionImporter.parse(data: data)
            pendingImport = export
            // Check for duplicates, present UI...
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    case .failure(let error):
        importError = error.localizedDescription
        showImportError = true
    }
}
```

### Collection Assignment in EndpointEditorView (PRO-gated)

```swift
// Source: Matches existing PRO gating pattern (Group + opacity/allowsHitTesting)
Section {
    Group {
        Picker("> COLLECTION_", selection: $endpoint.collectionName) {
            Text("None").tag(String?.none)
            ForEach(endpointStore.collectionNames, id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
        }
    }
    .opacity(proManager.isPro ? 1 : 0.4)
    .allowsHitTesting(proManager.isPro)
} header: {
    Text("> COLLECTION_")
        .blueprintLabelStyle()
}
.listRowBackground(MockPadColors.panel)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIActivityViewController in UIViewControllerRepresentable | ShareLink + Transferable | iOS 16 / WWDC22 | Pure SwiftUI share sheet, no UIKit bridging |
| UIDocumentPickerViewController | fileImporter / fileExporter modifiers | iOS 14 / WWDC20 | Declarative file I/O, SwiftUI-native |
| NSItemProvider for sharing | Transferable protocol | iOS 16 / WWDC22 | Declarative, type-safe, CodableRepresentation/FileRepresentation |
| Core Data relationships with NSManagedObject | SwiftData @Relationship | iOS 17 / WWDC23 | Swift-native, but many-to-many still fragile |

**Deprecated/outdated:**
- `UIActivityViewController`: Still works but `ShareLink` is the SwiftUI replacement. No reason to use UIKit bridging.
- `UIDocumentPickerViewController`: Still works but `fileImporter`/`fileExporter` are the SwiftUI replacements.
- `NSItemProvider`: Replaced by `Transferable` protocol for modern sharing.

## Open Questions

1. **Should collection filter be a Picker or filter chips (like request log)?**
   - What we know: The request log uses filter chips (LogFilterChipsView) for method/status filtering. A Picker dropdown saves space. Collections could have many names.
   - What's unclear: How many collections a typical user will create (3-5 likely for a mock server tool).
   - Recommendation: Use a horizontal ScrollView with filter chips matching the existing LogFilterChipsView pattern. "All" chip + one chip per collection name. Consistent with existing UI language. If collections exceed ~8, the horizontal scroll handles overflow.

2. **Should "Import as New" modify the endpoint path to avoid confusion?**
   - What we know: When importing a duplicate as new, both the old and new endpoints will have identical path+method. The server will match the first one (by sortOrder).
   - What's unclear: Whether users would expect the imported endpoint to have a modified path (e.g., "/api/users-copy").
   - Recommendation: Import as-is without modifying the path. The user can edit the path after import. The endpoint list already supports multiple endpoints with the same path (they are distinguished by sortOrder). Modifying paths automatically could break the user's intended configuration.

3. **Should the duplicate resolution apply per-endpoint or per-import batch?**
   - What we know: Per-endpoint resolution is tedious for large imports. Per-batch is simpler but less granular.
   - What's unclear: How many endpoints a typical import will contain.
   - Recommendation: Per-batch resolution. When duplicates are found, show a count ("3 of 8 endpoints already exist") and let the user choose one action for all duplicates: skip all, replace all, or import all as new. This avoids dialog fatigue and matches the batch import pattern from iOS Contacts and similar apps.

## Sources

### Primary (HIGH confidence)
- [ShareLink | Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/ShareLink) -- SwiftUI native share sheet
- [fileExporter | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttype:defaultfilename:oncompletion:)-32vwk) -- SwiftUI file export modifier
- [Transferable | Apple Developer Documentation](https://developer.apple.com/documentation/coretransferable/transferable) -- Protocol for shareable content
- [FileRepresentation | Apple Developer Documentation](https://developer.apple.com/documentation/coretransferable/filerepresentation) -- File-based transfer representation
- [UTType | Apple Developer Documentation](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct) -- Uniform Type Identifiers
- Project codebase: `MockEndpoint.swift`, `EndpointStore.swift`, `ProManager.swift`, `EndpointListView.swift`, `EndpointEditorView.swift` -- existing patterns verified
- Project codebase: `BuiltInTemplates.swift`, `EndpointMatcher.swift`, `PathParamReplacer.swift` -- caseless enum service pattern

### Secondary (MEDIUM confidence)
- [Hacking with Swift -- How to export files using fileExporter()](https://www.hackingwithswift.com/quick-start/swiftui/how-to-export-files-using-fileexporter) -- FileDocument pattern
- [Hacking with Swift -- How to create many-to-many relationships](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships) -- SwiftData relationship pitfalls (many-to-many fragility)
- [Swift with Majid -- File importing and exporting in SwiftUI](https://swiftwithmajid.com/2023/05/10/file-importing-and-exporting-in-swiftui/) -- fileImporter/fileExporter patterns
- [Use Your Loaf -- Accessing Security Scoped Files](https://useyourloaf.com/blog/accessing-security-scoped-files/) -- Security-scoped resource access pattern
- [Understanding the Transferable Protocol in Swift](https://www.createwithswift.com/understanding-the-transferable-protocol-in-swift/) -- CodableRepresentation vs FileRepresentation guidance
- [fatbobman.com -- Relationships in SwiftData](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/) -- SwiftData relationship considerations and limitations
- [AppCoda -- SwiftUI ShareLink](https://www.appcoda.com/swiftui-sharelink/) -- ShareLink usage patterns
- [An Unauthorized Guide to SwiftData Migrations](https://atomicrobot.com/blog/an-unauthorized-guide-to-swiftdata-migrations/) -- Migration behavior without VersionedSchema

### Tertiary (LOW confidence)
- None -- all findings verified with official or multiple secondary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All Apple-native frameworks (SwiftUI, SwiftData, UniformTypeIdentifiers, CoreTransferable). Well-documented, used extensively in prior projects.
- Architecture: HIGH -- Extends existing patterns (caseless enum services, @Model properties, EndpointStore CRUD, PRO gating). No novel architecture needed.
- Pitfalls: HIGH -- Security-scoped file access, SwiftData migration safety, format validation, duplicate detection all verified across multiple sources. App not yet shipped eliminates migration risk.
- Code examples: HIGH -- Patterns derived from project conventions (caseless enum, PRO gating opacity pattern, filter chips) and verified against Apple documentation.

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (stable frameworks, 60-day window)
