import SwiftUI

extension Color {
    static let dqBackground = Color(red: 0.045, green: 0.065, blue: 0.09)
    static let dqPanel = Color(red: 0.075, green: 0.105, blue: 0.135)
    static let dqPanelRaised = Color(red: 0.105, green: 0.14, blue: 0.18)
    static let dqRow = Color(red: 0.09, green: 0.12, blue: 0.15)
    static let dqMuted = Color.white.opacity(0.62)

    static func dqAccent(_ accent: AppColor) -> Color {
        switch accent {
        case .blue: .blue
        case .orange: .orange
        case .green: .green
        case .pink: .pink
        case .purple: .purple
        }
    }
}

struct DQPanelModifier: ViewModifier {
    var radius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .background(Color.dqPanel)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.07)))
    }
}

extension View {
    func dqPanel(radius: CGFloat = 12) -> some View { modifier(DQPanelModifier(radius: radius)) }
}

struct DQBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct DQIconButton: View {
    let systemName: String
    let title: String?
    var tint: Color = .white
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: prominent ? 21 : 16, weight: .semibold))
                if let title { Text(title).font(.system(size: 13, weight: .medium)) }
            }
            .frame(maxWidth: .infinity, minHeight: prominent ? 72 : 54)
            .foregroundStyle(tint)
            .background(prominent ? tint.opacity(0.9) : Color.dqPanelRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct DQPerformanceButtonStyle: ButtonStyle {
    var tint: Color = .blue
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .imageScale(.small)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(prominent ? Color.white : Color.white.opacity(0.9))
            .frame(minHeight: 28)
            .padding(.horizontal, 10)
            .background(prominent ? tint.opacity(configuration.isPressed ? 0.65 : 0.9) : Color.dqPanelRaised.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(tint.opacity(prominent ? 0.9 : 0.45), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
