import SwiftUI

/// Spacing scale (4-pt).
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum Motion {
    static let quick = Animation.snappy(duration: 0.25)
    static let standard = Animation.smooth(duration: 0.4)
    static let bouncy = Animation.spring(duration: 0.5, bounce: 0.3)
}

/// The tally's color with its emoji (or initial) on it.
struct TallySwatch: View {
    @Environment(\.theme) private var theme
    let text: String
    let colorIndex: Int
    var size: CGFloat = 44
    var finished = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(theme.tally(colorIndex))
            Text(text)
                .font(.system(size: size * 0.46, weight: .heavy, design: theme.numeralDesign))
                .foregroundStyle(theme.onTally(colorIndex))
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if finished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(theme.onActionColor, theme.actionColor)
                    .offset(x: size * 0.12, y: size * 0.12)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A round glass button for chrome that floats over content.
struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 44
    var tint: Color? = nil
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

/// A small capsule label for tags.
struct TagChip: View {
    @Environment(\.theme) private var theme
    let text: String
    var selected = false

    var body: some View {
        Text("#" + text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? theme.onActionColor : theme.text2Color)
            .padding(.horizontal, Space.s)
            .padding(.vertical, 3)
            .background(selected ? theme.actionColor : theme.raisedColor, in: Capsule())
    }
}

/// Screen background in the active theme.
struct ThemeBackground: View {
    @Environment(\.theme) private var theme
    var body: some View {
        theme.backgroundColor.ignoresSafeArea()
    }
}

/// The primary action: a flat action-color capsule.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.onActionColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Space.l)
            .background(theme.actionColor, in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// A quiet secondary capsule.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.textColor)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Space.l)
            .background(theme.raisedColor, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// Press feedback for custom tappable things.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

extension View {
    /// Themed grouped-form background.
    func themedForm(_ theme: TallyTheme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor.ignoresSafeArea())
            .tint(theme.actionColor)
    }

    /// Row background for grouped forms.
    func themedRow(_ theme: TallyTheme) -> some View {
        self.listRowBackground(theme.surfaceColor)
    }

    /// Everything a sheet needs to wear the theme.
    func themedSheet(_ theme: TallyTheme) -> some View {
        self
            .environment(\.theme, theme)
            .tint(theme.actionColor)
            .preferredColorScheme(theme.colorScheme)
            .presentationBackground(theme.backgroundColor)
    }
}

/// Relative "3 days", "5 hours".
enum Format {
    static func duration(_ interval: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = interval >= 86_400 ? [.day, .hour] : interval >= 3600 ? [.hour, .minute] : [.minute]
        f.unitsStyle = .full
        f.maximumUnitCount = 1
        return f.string(from: max(60, interval)) ?? ""
    }

    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}
