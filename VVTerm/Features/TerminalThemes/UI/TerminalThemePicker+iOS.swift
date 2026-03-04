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

    private var palette: TerminalThemePreviewPalette {
        ThemeColorParser.previewPalette(for: themeName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(themeName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.foreground.opacity(0.82))

            Text("vvterm@prod-web-01:~$ ./deploy --env prod")

            HStack(spacing: 6) {
                Text("connected")
                    .foregroundStyle(palette.foreground.opacity(0.72))
                Text("A")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(palette.cursor)
                    .foregroundStyle(palette.cursorText)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .foregroundStyle(palette.foreground)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.foreground.opacity(0.15), lineWidth: 1)
        )
    }
}
#endif
