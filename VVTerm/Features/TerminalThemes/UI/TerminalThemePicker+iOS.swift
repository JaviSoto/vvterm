#if os(iOS)
import SwiftUI

enum TerminalThemePickerContext: String, Identifiable {
    case singleTheme
    case darkTheme
    case lightTheme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleTheme:
            String(localized: "Theme")
        case .darkTheme:
            String(localized: "Dark Theme")
        case .lightTheme:
            String(localized: "Light Theme")
        }
    }
}

struct TerminalThemePickerScreen: View {
    let title: String
    @Binding var selectedTheme: String
    let builtInThemeOptions: [String]
    let customThemeOptions: [String]
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TerminalThemePickerPreview(themeName: selectedTheme)
                Text("This sample uses each theme's background, text, cursor, selection, and ANSI palette colors.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(.regularMaterial)

            List {
                if !builtInThemeOptions.isEmpty {
                    Section("Built-in") {
                        ForEach(builtInThemeOptions, id: \.self, content: themeRow)
                    }
                }
                if !customThemeOptions.isEmpty {
                    Section("Custom") {
                        ForEach(customThemeOptions, id: \.self, content: themeRow)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply", action: onApply)
                    .fontWeight(.semibold)
            }
        }
    }

    private func themeRow(_ theme: String) -> some View {
        Button {
            selectedTheme = theme
        } label: {
            HStack(spacing: 10) {
                Text(theme)
                Spacer(minLength: 0)
                if selectedTheme == theme {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TerminalThemePickerPreview: View {
    let themeName: String

    private var preview: ThemeColorParser.ThemePreviewValues {
        ThemeColorParser.previewValues(for: themeName)
    }

    private func paletteColor(_ index: Int) -> Color {
        preview.paletteColor(at: index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(themeName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(preview.foregroundColor.opacity(0.88))

            Text("vvterm@prod-web-01:~$ ./deploy --env prod")

            HStack(spacing: 8) {
                Text("INFO")
                    .fontWeight(.semibold)
                    .foregroundStyle(paletteColor(6))
                Text("ok")
                    .foregroundStyle(paletteColor(2))
                Text("warn")
                    .italic()
                    .foregroundStyle(paletteColor(3))
                Text("err")
                    .fontWeight(.semibold)
                    .foregroundStyle(paletteColor(1))
            }

            HStack(spacing: 6) {
                Text("cursor>")
                    .foregroundStyle(preview.foregroundColor.opacity(0.8))
                Text("A")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(preview.cursorColor)
                    .foregroundStyle(preview.cursorTextColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("selection")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(preview.selectionBackgroundColor)
                    .foregroundStyle(preview.selectionForegroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Rectangle()
                .fill(preview.foregroundColor.opacity(0.16))
                .frame(height: 1)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 20), spacing: 5), count: 8),
                spacing: 5
            ) {
                ForEach(0..<16, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(paletteColor(index))
                        .frame(height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(preview.foregroundColor.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .foregroundStyle(preview.foregroundColor)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(preview.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(preview.foregroundColor.opacity(0.15), lineWidth: 1)
        )
    }
}
#endif
