import SwiftUI

/// WhosBetter design system — Glassmorphism.
/// Deep aurora background, frosted glass panels, one signature glow accent.
enum Brand {
    // MARK: Colors
    enum Color {
        /// Primary accent — electric cyan.
        static let accent = SwiftUI.Color(red: 0.29, green: 0.87, blue: 1.00)
        /// Secondary accent — orchid magenta (used in gradients + the verdict glow).
        static let accent2 = SwiftUI.Color(red: 0.80, green: 0.45, blue: 1.00)
        /// Success / "winner" green.
        static let win = SwiftUI.Color(red: 0.44, green: 0.93, blue: 0.68)
        /// Warning / cons amber.
        static let warn = SwiftUI.Color(red: 1.00, green: 0.72, blue: 0.40)
        /// Danger.
        static let danger = SwiftUI.Color(red: 1.00, green: 0.45, blue: 0.50)

        /// Aurora background stops (dark appearance).
        static let bgDarkTop = SwiftUI.Color(red: 0.06, green: 0.07, blue: 0.16)
        static let bgDarkBottom = SwiftUI.Color(red: 0.02, green: 0.03, blue: 0.08)
        /// Aurora background stops (light appearance).
        static let bgLightTop = SwiftUI.Color(red: 0.90, green: 0.93, blue: 1.00)
        static let bgLightBottom = SwiftUI.Color(red: 0.96, green: 0.95, blue: 1.00)

        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary

        static let accentGradient = LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Typography (SF Pro Rounded for display, SF Pro for body, SF Mono for data)
    enum Font {
        static let hero = SwiftUI.Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 13, weight: .regular, design: .default)
        static let caption = SwiftUI.Font.system(size: 11, weight: .medium, design: .default)
        static let mono = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: Spacing & shape
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
    }
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 10
}

// MARK: - Signature element: GlassCard

/// The signature WhosBetter surface: frosted material, 1px luminous border,
/// soft drop shadow. `glow: true` adds the accent halo used for the verdict.
struct GlassCard<Content: View>: View {
    var glow = false
    var padding: CGFloat = Brand.Space.m
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Brand.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.radius, style: .continuous)
                    .strokeBorder(
                        glow ? AnyShapeStyle(Brand.Color.accentGradient)
                             : AnyShapeStyle(Color.white.opacity(scheme == .dark ? 0.16 : 0.55)),
                        lineWidth: glow ? 1.5 : 1)
            )
            .shadow(color: glow ? Brand.Color.accent.opacity(0.35) : .black.opacity(scheme == .dark ? 0.35 : 0.08),
                    radius: glow ? 24 : 14, y: 6)
    }
}

/// Aurora background used behind every screen.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Brand.Color.bgDarkTop, Brand.Color.bgDarkBottom]
                    : [Brand.Color.bgLightTop, Brand.Color.bgLightBottom],
                startPoint: .top, endPoint: .bottom)
            Circle().fill(Brand.Color.accent.opacity(scheme == .dark ? 0.28 : 0.35))
                .frame(width: 520).blur(radius: 120).offset(x: -260, y: -220)
            Circle().fill(Brand.Color.accent2.opacity(scheme == .dark ? 0.26 : 0.30))
                .frame(width: 560).blur(radius: 130).offset(x: 300, y: 260)
        }
        .ignoresSafeArea()
    }
}

/// Primary button: gradient pill with glass highlight.
struct GlassButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.Font.headline)
            .padding(.horizontal, Brand.Space.m).padding(.vertical, Brand.Space.s + 2)
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : Color.primary)
            .background(
                Group {
                    if prominent { Capsule().fill(Brand.Color.accentGradient) }
                    else { Capsule().fill(.ultraThinMaterial) }
                }
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func glassField() -> some View {
        self.padding(Brand.Space.s + 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }
}
