import SwiftUI
import UIKit

// MARK: - Minimalist, Apple-native color system
// Flat surfaces, system semantic colors (so Light AND Dark both look right),
// a single Apple-blue accent. No gradients.

extension Color {
    static let mmAccent = Color(hex: "#007AFF")            // the single accent
    static let mmCard = Color(uiColor: .secondarySystemBackground)
    static let mmCard2 = Color(uiColor: .tertiarySystemBackground)
    static let mmField = Color(uiColor: .tertiarySystemFill)
    static let mmHair = Color(uiColor: .separator)
    static let mmGreen = Color(hex: "#34C759")             // correct / mastered
    static let mmRed = Color(hex: "#FF3B30")               // wrong
}

// MARK: - Flat surfaces (cards / pills / buttons)

extension View {
    func mmCard(cornerRadius: CGFloat = 20) -> some View {
        self.padding(16)
            .background(Color.mmCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func mmPill() -> some View {
        self.padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.mmCard, in: Capsule())
    }

    /// Primary action — a clean, flat Apple-blue filled capsule.
    func prominentButton() -> some View { self.buttonStyle(FilledAccentButtonStyle()) }
    /// Secondary action — flat tinted capsule.
    func softButton() -> some View { self.buttonStyle(SoftButtonStyle()) }
}

struct FilledAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .background(Color.mmAccent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Color.mmAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(Color.mmCard, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Background (flat, adapts to light/dark)

struct MMBackground: View {
    var body: some View { Color(uiColor: .systemBackground).ignoresSafeArea() }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7) }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
