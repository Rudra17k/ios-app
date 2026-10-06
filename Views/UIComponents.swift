import SwiftUI

// MARK: - Apple Design Award Micro-Interaction Styles

/// Bouncy scale button style for cards and primary buttons
struct BouncyButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var bounceAnimation: Animation = .spring(response: 0.28, dampingFraction: 0.65)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(bounceAnimation, value: configuration.isPressed)
    }
}

/// Subtle tap feedback button style for list rows & filter chips
struct SubtlePressStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers & Card Styling

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var strokeOpacity: Double = 0.08
    var shadowRadius: CGFloat = 8

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(strokeOpacity)
                            : Color.black.opacity(strokeOpacity * 0.7),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04),
                radius: shadowRadius,
                x: 0,
                y: 3
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, strokeOpacity: Double = 0.08, shadowRadius: CGFloat = 8) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, shadowRadius: shadowRadius))
    }
}
