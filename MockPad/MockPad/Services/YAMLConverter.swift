//
//  YAMLConverter.swift
//  MockPad
//
//  Created with GSD workflow on 2026-02-17.
//

import Foundation

enum YAMLConverter {
    enum ConversionError: Error, LocalizedError, Equatable {
        case invalidYAML(String)

        var errorDescription: String? {
            switch self {
            case .invalidYAML(let detail):
                "Invalid YAML: \(detail)"
            }
        }
    }

    /// Convert YAML string to JSON-compatible Data
    static func toJSON(_ yaml: String) throws -> Data {
        let trimmed = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ConversionError.invalidYAML("Empty input")
        }

        let parsed = try parseDocument(trimmed)
        return try JSONSerialization.data(withJSONObject: parsed)
    }

    // MARK: - Document Parsing

    private static func parseDocument(_ yaml: String) throws -> Any {
        var lines = preprocessLines(yaml)
        guard !lines.isEmpty else {
            throw ConversionError.invalidYAML("No content after preprocessing")
        }

        var index = 0
        return try parseNode(lines: &lines, index: &index, parentIndent: -1)
    }

    // MARK: - Line Preprocessing

    private struct YAMLLine {
        let indent: Int
        let content: String
        let originalIndex: Int
    }

    private static func preprocessLines(_ yaml: String) -> [YAMLLine] {
        let rawLines = yaml.components(separatedBy: "\n")
        var result: [YAMLLine] = []

        for (i, line) in rawLines.enumerated() {
            let expanded = line.replacingOccurrences(of: "\t", with: "  ")
            let stripped = stripInlineComment(expanded)
            let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let indent = expanded.prefix(while: { $0 == " " }).count
            result.append(YAMLLine(indent: indent, content: trimmed, originalIndex: i))
        }

        return result
    }

    // MARK: - Comment Stripping

    private static func stripInlineComment(_ line: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if ch == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if ch == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if ch == "#" && !inSingleQuote && !inDoubleQuote {
                // Check for space before # (or start of line)
                if i == 0 || chars[i - 1] == " " {
                    return String(chars[..<i])
                }
            }

            i += 1
        }

        return line
    }

    // MARK: - Node Parsing

    private static func parseNode(
        lines: inout [YAMLLine],
        index: inout Int,
        parentIndent: Int
    ) throws -> Any {
        guard index < lines.count else {
            throw ConversionError.invalidYAML("Unexpected end of input")
        }

        let line = lines[index]

        // Is this an array item?
        if line.content.hasPrefix("- ") || line.content == "-" {
            return try parseArray(lines: &lines, index: &index, arrayIndent: line.indent)
        }

        // Is this a key-value or mapping?
        if isKeyValueLine(line.content) {
            return try parseMapping(lines: &lines, index: &index, mappingIndent: line.indent)
        }

        // Bare scalar
        let value = parseScalar(line.content)
        index += 1
        return value
    }

    // MARK: - Mapping Parsing

    private static func parseMapping(
        lines: inout [YAMLLine],
        index: inout Int,
        mappingIndent: Int
    ) throws -> [String: Any] {
        var dict: [String: Any] = [:]

        while index < lines.count {
            let line = lines[index]
            guard line.indent == mappingIndent else {
                if line.indent < mappingIndent { break }
                // Indented beyond mapping level - skip (shouldn't happen in well-formed YAML)
                throw ConversionError.invalidYAML("Unexpected indentation at line \(line.originalIndex + 1)")
            }

            // Handle array items at mapping level -- this means the top-level is an array
            if line.content.hasPrefix("- ") || line.content == "-" {
                break
            }

            guard let (key, valueStr) = splitKeyValue(line.content) else {
                break
            }

            if let valueStr = valueStr {
                // Check for multiline block indicators
                if valueStr == "|" || valueStr == ">" {
                    let joinChar = valueStr == "|" ? "\n" : " "
                    index += 1
                    let blockValue = collectMultilineBlock(
                        lines: &lines,
                        index: &index,
                        blockIndent: line.indent
                    )
                    dict[key] = blockValue.joined(separator: joinChar)
                } else {
                    dict[key] = parseScalar(valueStr)
                    index += 1
                }
            } else {
                // No value -- check if next line is indented (nested structure)
                index += 1
                if index < lines.count && lines[index].indent > mappingIndent {
                    dict[key] = try parseNode(
                        lines: &lines,
                        index: &index,
                        parentIndent: mappingIndent
                    )
                } else {
                    // Empty value
                    dict[key] = NSNull()
                }
            }
        }

        return dict
    }

    // MARK: - Array Parsing

    private static func parseArray(
        lines: inout [YAMLLine],
        index: inout Int,
        arrayIndent: Int
    ) throws -> [Any] {
        var arr: [Any] = []

        while index < lines.count {
            let line = lines[index]
            guard line.indent == arrayIndent else {
                if line.indent < arrayIndent { break }
                // Indented beyond array level -- part of previous item
                break
            }

            guard line.content.hasPrefix("- ") || line.content == "-" else {
                break
            }

            let itemContent: String
            if line.content == "-" {
                itemContent = ""
            } else {
                itemContent = String(line.content.dropFirst(2))
            }

            if itemContent.isEmpty {
                // Nested structure under array item
                index += 1
                if index < lines.count && lines[index].indent > arrayIndent {
                    let nested = try parseNode(
                        lines: &lines,
                        index: &index,
                        parentIndent: arrayIndent
                    )
                    arr.append(nested)
                } else {
                    arr.append(NSNull())
                }
            } else if isKeyValueLine(itemContent) {
                // Array item is a mapping: - key: value
                // We need to parse this item and any continuation lines at deeper indent as a mapping
                let itemIndent = arrayIndent + 2
                guard let (key, valueStr) = splitKeyValue(itemContent) else {
                    arr.append(parseScalar(itemContent))
                    index += 1
                    continue
                }

                var itemDict: [String: Any] = [:]

                if let valueStr = valueStr {
                    if valueStr == "|" || valueStr == ">" {
                        let joinChar = valueStr == "|" ? "\n" : " "
                        index += 1
                        let blockValue = collectMultilineBlock(
                            lines: &lines,
                            index: &index,
                            blockIndent: arrayIndent
                        )
                        itemDict[key] = blockValue.joined(separator: joinChar)
                    } else {
                        itemDict[key] = parseScalar(valueStr)
                        index += 1
                    }
                } else {
                    index += 1
                    if index < lines.count && lines[index].indent > arrayIndent {
                        itemDict[key] = try parseNode(
                            lines: &lines,
                            index: &index,
                            parentIndent: arrayIndent
                        )
                    } else {
                        itemDict[key] = NSNull()
                    }
                }

                // Collect remaining key-value pairs at item indent level
                while index < lines.count && lines[index].indent == itemIndent {
                    let subLine = lines[index]
                    if subLine.content.hasPrefix("- ") { break }
                    if let (subKey, subValueStr) = splitKeyValue(subLine.content) {
                        if let subValueStr = subValueStr {
                            if subValueStr == "|" || subValueStr == ">" {
                                let joinChar = subValueStr == "|" ? "\n" : " "
                                index += 1
                                let blockValue = collectMultilineBlock(
                                    lines: &lines,
                                    index: &index,
                                    blockIndent: itemIndent - 1
                                )
                                itemDict[subKey] = blockValue.joined(separator: joinChar)
                            } else {
                                itemDict[subKey] = parseScalar(subValueStr)
                                index += 1
                            }
                        } else {
                            index += 1
                            if index < lines.count && lines[index].indent > itemIndent {
                                itemDict[subKey] = try parseNode(
                                    lines: &lines,
                                    index: &index,
                                    parentIndent: itemIndent
                                )
                            } else {
                                itemDict[subKey] = NSNull()
                            }
                        }
                    } else {
                        break
                    }
                }

                arr.append(itemDict)
            } else {
                // Simple scalar array item
                arr.append(parseScalar(itemContent))
                index += 1
            }
        }

        return arr
    }

    // MARK: - Multiline Block Collection

    private static func collectMultilineBlock(
        lines: inout [YAMLLine],
        index: inout Int,
        blockIndent: Int
    ) -> [String] {
        var blockLines: [String] = []

        while index < lines.count {
            let line = lines[index]
            guard line.indent > blockIndent else { break }
            blockLines.append(line.content)
            index += 1
        }

        return blockLines
    }

    // MARK: - Key-Value Detection and Splitting

    private static func isKeyValueLine(_ content: String) -> Bool {
        // Check if the line contains a colon that indicates a key-value pair
        // Must not be inside quotes
        guard let colonIdx = findKeyColon(content) else { return false }
        let key = content[content.startIndex..<colonIdx]
            .trimmingCharacters(in: .whitespaces)
        return !key.isEmpty
    }

    private static func splitKeyValue(_ content: String) -> (String, String?)? {
        guard let colonIdx = findKeyColon(content) else { return nil }

        let key = String(content[content.startIndex..<colonIdx])
            .trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        let afterColon: String
        if content.index(after: colonIdx) < content.endIndex {
            afterColon = String(content[content.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)
        } else {
            afterColon = ""
        }

        if afterColon.isEmpty {
            return (key, nil)
        }
        return (key, afterColon)
    }

    private static func findKeyColon(_ content: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false

        for i in content.indices {
            let ch = content[i]

            if ch == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if ch == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if ch == ":" && !inSingleQuote && !inDoubleQuote {
                // The colon must be followed by a space, end of string, or be at the end
                let nextIdx = content.index(after: i)
                if nextIdx == content.endIndex || content[nextIdx] == " " {
                    return i
                }
            }
        }

        return nil
    }

    // MARK: - Scalar Parsing

    private static func parseScalar(_ value: String) -> Any {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }

        // Double-quoted string
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }

        // Single-quoted string
        if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }

        // Flow collection: inline JSON array or object
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            if let data = trimmed.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                return parsed
            }
            // If JSONSerialization fails, return as string
            return trimmed
        }

        // Boolean
        switch trimmed {
        case "true", "True", "TRUE": return true
        case "false", "False", "FALSE": return false
        default: break
        }

        // Null
        switch trimmed {
        case "null", "~", "Null", "NULL": return NSNull()
        default: break
        }

        // Integer
        if let intVal = Int(trimmed) {
            return intVal
        }

        // Float (must contain a dot to distinguish from integer)
        if trimmed.contains("."), let doubleVal = Double(trimmed) {
            return doubleVal
        }

        // Default: unquoted string
        return trimmed
    }
}
