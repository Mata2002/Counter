import SwiftUI

/// A named palette. Values live in ThemeCatalog.swift, generated from design/themes/themes.js (audited for contrast).
struct TallyTheme: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable { case everyday, holiday }
    enum Scheme: String, Sendable { case light, dark }
    /// How big numbers are set.
    enum Numeral: String, Sendable { case rounded, `default`, serif, mono }
    /// Celebration confetti style.
    enum Particles: String, Sendable { case tally, fireworks, hearts, clovers, eggs, stars, bats, leaves, snow, spring }
    /// Optional texture on the counting stage.
    enum Stage: String, Sendable { case none, grid, riso }

    let id: String
    let name: String
    let kind: Kind
    let scheme: Scheme
    let numeral: Numeral
    let particles: Particles
    let stage: Stage
    let mood: String
    let signature: String?

    let background: UInt32
    let surface: UInt32
    let raised: UInt32
    let divider: UInt32
    let text: UInt32
    let text2: UInt32
    let action: UInt32
    let onAction: UInt32
    /// Six colors a tally can wear.
    let tallies: [UInt32]
    /// The unfilled part of the counting stage for each tally color.
    let talliesBase: [UInt32]
    /// Ink for text on each tally color.
    let talliesOn: [UInt32]
    /// Ink for text on each tally's unfilled stage color.
    let talliesOnBase: [UInt32]

    static func == (lhs: TallyTheme, rhs: TallyTheme) -> Bool { lhs.id == rhs.id && lhs.scheme == rhs.scheme }

    static let tallyColorCount = 6
    static var fallback: TallyTheme { all[0] }
    static var everyday: [TallyTheme] { all.filter { $0.kind == .everyday } }
    static var holidays: [TallyTheme] { all.filter { $0.kind == .holiday } }
    static func named(_ id: String?) -> TallyTheme? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    var colorScheme: ColorScheme { scheme == .dark ? .dark : .light }

    /// This theme in the given appearance. Every theme has a light and a dark version.
    func resolved(_ appearance: ColorScheme) -> TallyTheme {
        let wanted: Scheme = appearance == .dark ? .dark : .light
        if scheme == wanted { return self }
        return (Self.all + Self.alternates).first { $0.id == id && $0.scheme == wanted } ?? self
    }
}

/// Light, dark, or whatever the device is set to. Stored outside the tally data, in the shared app group
/// so widgets match.
enum ThemeAppearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }
    static let storageKey = "theme.appearance"

    var title: String {
        switch self {
        case .system: return "Device"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Nil means follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Color roles

extension TallyTheme {
    var backgroundColor: Color { Color(rgb: background) }
    var surfaceColor: Color { Color(rgb: surface) }
    var raisedColor: Color { Color(rgb: raised) }
    var dividerColor: Color { Color(rgb: divider) }
    var textColor: Color { Color(rgb: text) }
    var text2Color: Color { Color(rgb: text2) }
    var actionColor: Color { Color(rgb: action) }
    var onActionColor: Color { Color(rgb: onAction) }

    private func index(_ i: Int) -> Int {
        let n = Self.tallyColorCount
        return ((i % n) + n) % n
    }
    func tally(_ i: Int) -> Color { Color(rgb: tallies[index(i)]) }
    func tallyBase(_ i: Int) -> Color { Color(rgb: talliesBase[index(i)]) }
    func onTally(_ i: Int) -> Color { Color(rgb: talliesOn[index(i)]) }
    func onTallyBase(_ i: Int) -> Color { Color(rgb: talliesOnBase[index(i)]) }

    /// Font design for big numbers.
    var numeralDesign: Font.Design {
        switch numeral {
        case .rounded: return .rounded
        case .default: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    /// A big number in this theme's voice.
    func numeralFont(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: numeral == .serif ? .bold : weight, design: numeralDesign)
    }

    /// Text-style numerals that scale with Dynamic Type.
    func numeralFont(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: numeralDesign, weight: weight)
    }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: TallyTheme = TallyTheme.fallback
}

extension EnvironmentValues {
    /// The theme views draw with. The app injects the active theme; widgets and the watch inject theirs.
    var theme: TallyTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
