import Testing
@testable import VVTerm

struct ThemeColorParserTests {
    @Test
    func darkSplitDividerUsesGhosttyDarkBackgroundFactor() throws {
        let components = try #require(
            ThemeColorParser.splitDividerComponents(for: "#204060")
        )

        #expect(abs(components.red - (32.0 / 255.0 * 0.6)) < 0.000_001)
        #expect(abs(components.green - (64.0 / 255.0 * 0.6)) < 0.000_001)
        #expect(abs(components.blue - (96.0 / 255.0 * 0.6)) < 0.000_001)
        #expect(components.alpha == 1)
    }

    @Test
    func lightSplitDividerUsesGhosttyLightBackgroundFactor() throws {
        let components = try #require(
            ThemeColorParser.splitDividerComponents(for: "#80C0FF")
        )

        #expect(abs(components.red - (128.0 / 255.0 * 0.92)) < 0.000_001)
        #expect(abs(components.green - (192.0 / 255.0 * 0.92)) < 0.000_001)
        #expect(abs(components.blue - 0.92) < 0.000_001)
        #expect(components.alpha == 1)
    }

    @Test
    func splitDividerSupportsShortAndAlphaHexColors() throws {
        let short = try #require(ThemeColorParser.splitDividerComponents(for: "#abc"))
        let alpha = try #require(ThemeColorParser.splitDividerComponents(for: "80ABCDEF"))

        #expect(abs(short.red - (170.0 / 255.0 * 0.92)) < 0.000_001)
        #expect(abs(short.green - (187.0 / 255.0 * 0.92)) < 0.000_001)
        #expect(abs(short.blue - (204.0 / 255.0 * 0.92)) < 0.000_001)
        #expect(abs(alpha.alpha - (128.0 / 255.0)) < 0.000_001)
    }

    @Test
    func splitDividerRejectsInvalidHex() {
        #expect(ThemeColorParser.splitDividerComponents(for: "not-a-color") == nil)
        #expect(ThemeColorParser.splitDividerComponents(for: "#12") == nil)
    }

    @Test
    func previewValuesIgnoresInvalidEntries() {
        let content = """
        foreground = not-a-color
        nope
        palette = one=#ffffff
        """

        let parsed = ThemeColorParser.previewValues(fromThemeContent: content)
        #expect(parsed.backgroundHex == ThemeColorParser.ThemePreviewValues.default.backgroundHex)
        #expect(parsed.foregroundHex == ThemeColorParser.ThemePreviewValues.default.foregroundHex)
        #expect(parsed.cursorColorHex == ThemeColorParser.ThemePreviewValues.default.cursorColorHex)
        #expect(parsed.cursorTextHex == ThemeColorParser.ThemePreviewValues.default.cursorTextHex)
        #expect(parsed.selectionBackgroundHex == ThemeColorParser.ThemePreviewValues.default.selectionBackgroundHex)
        #expect(parsed.selectionForegroundHex == ThemeColorParser.ThemePreviewValues.default.selectionForegroundHex)
        #expect(parsed.paletteHex == ThemeColorParser.ThemePreviewValues.default.paletteHex)
    }

    @Test
    func previewValuesParsesKnownKeysAndPalette() {
        let content = """
        background = 0a0b0c
        foreground = #d0d1d2
        cursor-color = 112233
        cursor-text = #fafbfc
        selection-background = 334455
        selection-foreground = #667788
        palette = 2=00ff00
        palette = 10=#aa11bb
        palette = 99=#ffffff
        """

        let parsed = ThemeColorParser.previewValues(fromThemeContent: content)
        #expect(parsed.backgroundHex == "#0A0B0C")
        #expect(parsed.foregroundHex == "#D0D1D2")
        #expect(parsed.cursorColorHex == "#112233")
        #expect(parsed.cursorTextHex == "#FAFBFC")
        #expect(parsed.selectionBackgroundHex == "#334455")
        #expect(parsed.selectionForegroundHex == "#667788")
        #expect(parsed.paletteHex[2] == "#00FF00")
        #expect(parsed.paletteHex[10] == "#AA11BB")
        #expect(parsed.paletteHex[0] == ThemeColorParser.ThemePreviewValues.default.paletteHex[0])
    }

    @Test
    func previewValuesUsesBackgroundAsCursorTextFallback() {
        let content = """
        background = #1b2b34
        foreground = #d8dee9
        """

        let parsed = ThemeColorParser.previewValues(fromThemeContent: content)
        #expect(parsed.backgroundHex == "#1B2B34")
        #expect(parsed.foregroundHex == "#D8DEE9")
        #expect(parsed.cursorColorHex == "#D8DEE9")
        #expect(parsed.cursorTextHex == "#1B2B34")
        #expect(parsed.selectionBackgroundHex == "#D8DEE9")
        #expect(parsed.selectionForegroundHex == "#1B2B34")
    }

    @Test
    func previewValuesKeepsExplicitFallbackOverridesRegardlessOfOrder() {
        let content = """
        cursor-text = #112233
        selection-foreground = #445566
        selection-background = #778899
        cursor-color = #aabbcc
        background = #1b2b34
        foreground = #d8dee9
        """

        let parsed = ThemeColorParser.previewValues(fromThemeContent: content)
        #expect(parsed.cursorColorHex == "#AABBCC")
        #expect(parsed.cursorTextHex == "#112233")
        #expect(parsed.selectionBackgroundHex == "#778899")
        #expect(parsed.selectionForegroundHex == "#445566")
    }
}
