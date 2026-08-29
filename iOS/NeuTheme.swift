import SwiftUI

/// Neumorphism design system for Pickwise on iOS.
/// One soft material everywhere: elements are extruded from (or pressed into)
/// the background with a light shadow top-left and a dark shadow bottom-right.
enum Neu {
    // Base surface — everything is cut from this.
    static let bg = adaptive(light: Color(red: 0.895, green: 0.913, blue: 0.949),
                             dark: Color(red: 0.153, green: 0.165, blue: 0.196))
    static let shadowDark = adaptive(light: Color(red: 0.639, green: 0.694, blue: 0.776).opacity(0.65),
                                     dark: Color.black.opacity(0.55))
    static let shadowLight = adaptive(light: Color.white.opacity(0.95),
                                      dark: Color.white.opacity(0.075))
    static let ink = adaptive(light: Color(red: 0.173, green: 0.208, blue: 0.278),
                              dark: Color(red: 0.92, green: 0.93, blue: 0.96))
    static let ink2 = adaptive(light: Color(red: 0.42, green: 0.46, blue: 0.54),
                               dark: Color(red: 0.62, green: 0.65, blue: 0.72))
    static let accent = adaptive(light: Color(red: 0.05, green: 0.62, blue: 0.78),
                                 dark: Color(red: 0.29, green: 0.87, blue: 1.0))
    static let win = adaptive(light: Color(red: 0.08, green: 0.55, blue: 0.33),
                              dark: Color(red: 0.44, green: 0.93, blue: 0.68))
    static let danger = adaptive(light: Color(red: 0.78, green: 0.20, blue: 0.26),
                                 dark: Color(red: 1.0, green: 0.47, blue: 0.52))

    static let radius: CGFloat = 22
    static let radiusSmall: CGFloat = 14

    enum Font {
        static let hero = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 20, weight: .bold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 14, weight: .medium, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 12, weight: .medium, design: .rounded)
        static let mono = SwiftUI.Font.system(size: 12, weight: .medium, design: .monospaced)
    }

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

/// Raised, extruded panel.
struct NeuRaised: ViewModifier {
    var radius: CGFloat = Neu.radius
    var depth: CGFloat = 7
    func body(content: Content) -> some View {
        content
            .background(Neu.bg, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Neu.shadowDark, radius: depth, x: depth, y: depth)
            .shadow(color: Neu.shadowLight, radius: depth, x: -depth, y: -depth)
    }
}

/// Pressed-in well: for text fields and readouts.
struct NeuInset: ViewModifier {
    var radius: CGFloat = Neu.radiusSmall
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Neu.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Neu.shadowDark, lineWidth: 3)
                        .blur(radius: 3)
                        .offset(x: 2, y: 2)
                        .mask(RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Neu.shadowLight, lineWidth: 3)
                        .blur(radius: 3)
                        .offset(x: -2, y: -2)
                        .mask(RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)))
                )
        )
    }
}

extension View {
    func neuRaised(radius: CGFloat = Neu.radius, depth: CGFloat = 7) -> some View {
        modifier(NeuRaised(radius: radius, depth: depth))
    }
    func neuInset(radius: CGFloat = Neu.radiusSmall) -> some View {
        modifier(NeuInset(radius: radius))
    }
}

/// Soft extruded button; presses flatten into the surface. `prominent` fills with the accent.
struct NeuButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Neu.Font.headline)
            .foregroundStyle(prominent ? Color.white : Neu.ink)
            .padding(.horizontal, 20).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Neu.radiusSmall + 2, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(Neu.accent) : AnyShapeStyle(Neu.bg))
            )
            .shadow(color: pressed ? .clear : Neu.shadowDark, radius: 6, x: 5, y: 5)
            .shadow(color: pressed ? .clear : Neu.shadowLight, radius: 6, x: -5, y: -5)
            .scaleEffect(pressed ? 0.98 : 1)
            .opacity(enabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}
