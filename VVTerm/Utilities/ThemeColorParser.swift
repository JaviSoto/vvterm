//
//  ThemeColorParser.swift
//  VVTerm
//

import SwiftUI
import Foundation

/// Parses terminal theme files to extract colors
struct ThemeColorParser {
    struct ThemePreviewValues {
        static let defaultPaletteHex = [
            "#1D1F21", "#CC6666", "#B5BD68", "#F0C674",
            "#81A2BE", "#B294BB", "#8ABEB7", "#C5C8C6",
            "#666666", "#D54E53", "#B9CA4A", "#E7C547",
            "#7AA6DA", "#C397D8", "#70C0B1", "#EAEAEA"
        ]

        static let `default` = ThemePreviewValues(
            backgroundHex: "#101418",
            foregroundHex: "#D8E0EA",
            cursorColorHex: "#F8B26A",
            cursorTextHex: "#101418",
            selectionBackgroundHex: "#2E3A46",
            selectionForegroundHex: "#D8E0EA",
            paletteHex: defaultPaletteHex
        )

        var backgroundHex: String
        var foregroundHex: String
        var cursorColorHex: String
        var cursorTextHex: String
        var selectionBackgroundHex: String
        var selectionForegroundHex: String
        var paletteHex: [String]

        var backgroundColor: Color { Color.fromHex(backgroundHex) }
        var foregroundColor: Color { Color.fromHex(foregroundHex) }
        var cursorColor: Color { Color.fromHex(cursorColorHex) }
        var cursorTextColor: Color { Color.fromHex(cursorTextHex) }
        var selectionBackgroundColor: Color { Color.fromHex(selectionBackgroundHex) }
        var selectionForegroundColor: Color { Color.fromHex(selectionForegroundHex) }

        func paletteColor(at index: Int) -> Color {
            guard paletteHex.indices.contains(index) else {
                return Color.fromHex(Self.defaultPaletteHex[0])
            }
            return Color.fromHex(paletteHex[index])
        }
    }

    /// Extracts background color from a Ghostty theme file
    /// - Parameter themeName: The name of the theme (e.g., "Aizen Dark")
    /// - Returns: The background Color if found, nil otherwise
    nonisolated static func backgroundColor(for themeName: String) -> Color? {
        guard let content = themeContent(for: themeName),
              let colorHex = value(for: "background", in: content) else {
            return nil
        }

        return Color.fromHex(colorHex)
    }

    /// Computes the split divider color based on the background color
    /// Uses Ghostty's algorithm: darken by 8% for light backgrounds, 40% for dark
    nonisolated static func splitDividerColor(for themeName: String) -> Color {
        guard let bgColor = backgroundColor(for: themeName) else {
            return Color(white: 0.3)
        }

        #if os(macOS)
        let nsColor = NSColor(bgColor)
        let brightness = nsColor.brightnessComponent
        let isLight = brightness > 0.5

        // Darken by 8% for light, 40% for dark (matching Ghostty)
        let factor = isLight ? 0.92 : 0.6
        let adjusted = NSColor(
            hue: nsColor.hueComponent,
            saturation: nsColor.saturationComponent,
            brightness: nsColor.brightnessComponent * factor,
            alpha: nsColor.alphaComponent
        )
        return Color(adjusted)
        #else
        // iOS fallback
        return Color(white: 0.3)
        #endif
    }

    /// Returns tmux mode-style string for selection highlighting.
    /// Format: "fg=#RRGGBB,bg=#RRGGBB"
    nonisolated static func tmuxModeStyle(for themeName: String) -> String {
        let fallbackForegroundHex = "cdd6f4"
        let fallbackSelectionBackgroundHex = "45475a"
        guard let content = themeContent(for: themeName) else {
            return "fg=#\(fallbackForegroundHex),bg=#\(fallbackSelectionBackgroundHex)"
        }

        let selectionForeground = value(for: "selection-foreground", in: content)
        let foreground = value(for: "foreground", in: content)
        let selectionBackground = value(for: "selection-background", in: content)

        let fg = normalizeHex(selectionForeground ?? foreground ?? fallbackForegroundHex)
        let bg = normalizeHex(selectionBackground ?? fallbackSelectionBackgroundHex)
        return "fg=#\(fg),bg=#\(bg)"
    }

    nonisolated static func previewValues(for themeName: String) -> ThemePreviewValues {
        guard let content = themeContent(for: themeName) else {
            return .default
        }
        return previewValues(fromThemeContent: content)
    }

    nonisolated static func previewValues(fromThemeContent content: String) -> ThemePreviewValues {
        var preview = ThemePreviewValues.default

        for rawLine in content.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            if key == "palette" {
                let paletteParts = value.split(separator: "=", maxSplits: 1)
                guard
                    paletteParts.count == 2,
                    let paletteIndex = Int(paletteParts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                    (0..<16).contains(paletteIndex),
                    let paletteColor = TerminalThemeValidator.normalizeHexColor(String(paletteParts[1]))
                else {
                    continue
                }
                preview.paletteHex[paletteIndex] = paletteColor
                continue
            }

            guard let normalized = TerminalThemeValidator.normalizeHexColor(value) else { continue }

            switch key {
            case "background":
                preview.backgroundHex = normalized
                if TerminalThemeValidator.normalizeHexColor(preview.cursorTextHex) == TerminalThemeValidator.normalizeHexColor(ThemePreviewValues.default.cursorTextHex) {
                    preview.cursorTextHex = normalized
                }
            case "foreground":
                preview.foregroundHex = normalized
            case "cursor-color":
                preview.cursorColorHex = normalized
            case "cursor-text":
                preview.cursorTextHex = normalized
            case "selection-background":
                preview.selectionBackgroundHex = normalized
            case "selection-foreground":
                preview.selectionForegroundHex = normalized
            default:
                continue
            }
        }

        return preview
    }

    private nonisolated static func themeContent(for themeName: String) -> String? {
        guard let themeFile = themeFilePath(for: themeName) else { return nil }
        return try? String(contentsOfFile: themeFile, encoding: .utf8)
    }

    private nonisolated static func themeFilePath(for themeName: String) -> String? {
        // Try custom themes first.
        let customThemeFile = TerminalThemeStoragePaths.customThemeFilePath(for: themeName)
        if FileManager.default.fileExists(atPath: customThemeFile) {
            return customThemeFile
        }

        guard let resourcePath = Bundle.main.resourcePath else { return nil }

        // Try structured path first
        let structuredThemesPath = (resourcePath as NSString).appendingPathComponent("ghostty/themes")
        let structuredThemeFile = (structuredThemesPath as NSString).appendingPathComponent(themeName)
        if FileManager.default.fileExists(atPath: structuredThemeFile) {
            return structuredThemeFile
        }

        // Fall back to temp directory where themes are copied at runtime
        let tempThemesPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("ghostty_themes")
        let tempThemeFile = (tempThemesPath as NSString).appendingPathComponent(themeName)
        if FileManager.default.fileExists(atPath: tempThemeFile) {
            return tempThemeFile
        }

        // Fall back to flattened resources (theme file directly in bundle)
        let flattenedThemeFile = (resourcePath as NSString).appendingPathComponent(themeName)
        if FileManager.default.fileExists(atPath: flattenedThemeFile) {
            return flattenedThemeFile
        }

        // Try temp config directory
        let ghosttyConfigDir = (NSTemporaryDirectory() as NSString).appendingPathComponent(".config/ghostty/themes")
        let configThemeFile = (ghosttyConfigDir as NSString).appendingPathComponent(themeName)
        if FileManager.default.fileExists(atPath: configThemeFile) {
            return configThemeFile
        }

        return nil
    }

    private nonisolated static func value(for key: String, in content: String) -> String? {
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            guard name == key else { continue }
            return parts[1].trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private nonisolated static func normalizeHex(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }
}
