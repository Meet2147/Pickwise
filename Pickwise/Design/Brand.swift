import SwiftUI
import AppKit

/// Pickwise design system.
/// Charcoal ground, translucent hairline surfaces, ONE accent. Type does the work;
/// color is spent only on the verdict and the primary action.
enum Brand {
    enum Color {
        /// The single accent.
        static let accent = SwiftUI.Color(red: 0.29, green: 0.87, blue: 1.00)      // #4ADDFF
        static let accentInk = SwiftUI.Color(red: 0.04, green: 0.11, blue: 0.13)   // text on accent
        static let win = adaptive(light: (0.05, 0.52, 0.31), dark: (0.44, 0.93, 0.68))
        static let warn = adaptive(light: (0.70, 0.40, 0.00), dark: (1.00, 0.72, 0.40))
        static let danger = adaptive(light: (0.76, 0.16, 0.22), dark: (1.00, 0.47, 0.52))

        /// Ground: near-black charcoal / warm paper.
        static let ground = adaptive(light: (0.96, 0.96, 0.97), dark: (0.059, 0.059, 0.067))   // #0F0F11
        static let ink2 = adaptive(light: (0.35, 0.36, 0.40), dark: (0.69, 0.70, 0.72))        // #B0B3B8
        static let ink3 = adaptive(light: (0.55, 0.56, 0.60), dark: (0.45, 0.47, 0.50))

        static let hairline = SwiftUI.Color.primary.opacity(0.10)
        static let hairlineStrong = SwiftUI.Color.primary.opacity(0.18)
        static let surface = SwiftUI.Color.primary.opacity(0.05)
        static let surface2 = SwiftUI.Color.primary.opacity(0.09)

        fileprivate static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { app in
                let c = app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
                return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
            })
        }
    }

    /// Type: SF Pro (the platform face) with tight display tracking; SF Mono for numbers and chips.
    enum Font {
        static let hero = SwiftUI.Font.system(size: 30, weight: .semibold)
        static let title = SwiftUI.Font.system(size: 21, weight: .semibold)
        static let headline = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 11, weight: .medium)
        static let mono = SwiftUI.Font.system(size: 12, weight: .medium, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(size: 10.5, weight: .medium, design: .monospaced)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
    }
    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8
    static let radiusLarge: CGFloat = 16
}

// MARK: - Surface (signature element): translucent panel with a hairline edge.
// `emphasis` is reserved for the verdict: accent hairline + a soft accent halo.

struct Surface<Content: View>: View {
    var emphasis = false
    var padding: CGFloat = Brand.Space.m
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: Brand.radiusLarge, style: .continuous))
            .background(Brand.Color.surface, in: RoundedRectangle(cornerRadius: Brand.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.radiusLarge, style: .continuous)
                    .strokeBorder(emphasis ? Brand.Color.accent.opacity(0.55) : Brand.Color.hairline, lineWidth: 1)
            )
            .shadow(color: emphasis ? Brand.Color.accent.opacity(0.18) : .clear, radius: 28, y: 8)
    }
}

/// Ground: flat charcoal with one soft-focused accent wash, top-left. Not a gradient mesh.
struct Ground: View {
    var body: some View {
        ZStack {
            Brand.Color.ground
            RadialGradient(colors: [Brand.Color.accent.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

/// Buttons: translucent pills. `.primary` is the only solid-accent control on screen.
struct PillButtonStyle: ButtonStyle {
    enum Role { case primary, secondary }
    var role: Role = .secondary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.Font.headline)
            .padding(.horizontal, Brand.Space.m).padding(.vertical, 9)
            .foregroundStyle(role == .primary ? Brand.Color.accentInk : .primary)
            .background(role == .primary ? AnyShapeStyle(Brand.Color.accent) : AnyShapeStyle(Brand.Color.surface2), in: Capsule())
            .overlay(Capsule().strokeBorder(role == .primary ? .clear : Brand.Color.hairlineStrong, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Keyboard shortcut chip, e.g. ⌘↵.
struct KeyChip: View {
    let keys: [String]
    var onAccent = false
    var body: some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { k in
                Text(k).font(Brand.Font.monoSmall)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(onAccent ? Color.black.opacity(0.10) : Brand.Color.surface2, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(onAccent ? Color.black.opacity(0.12) : Brand.Color.hairlineStrong, lineWidth: 1))
            }
        }
        .opacity(0.85)
    }
}

extension View {
    func field() -> some View {
        self.padding(.horizontal, 10).padding(.vertical, 8)
            .background(Brand.Color.surface, in: RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous)
                .strokeBorder(Brand.Color.hairline, lineWidth: 1))
    }
}
