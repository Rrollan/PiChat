import SwiftUI
import AppKit

// MARK: - Design System

enum DS {

    // MARK: Colors
    enum Colors {
        // Adaptive light/dark palette
        static let background      = Color(lightHex: "#FFFFFF", darkHex: "#101114")
        static let surface         = Color(lightHex: "#F9F9F9", darkHex: "#16181D")
        static let surfaceElevated = Color(lightHex: "#F3F3F3", darkHex: "#1E2128")
        static let border          = Color(lightHex: "#EAEAEA", darkHex: "#2A2F39")
        static let borderAccent    = Color(lightHex: "#D0D0D0", darkHex: "#3A404D")

        static let accent          = Color(lightHex: "#000000", darkHex: "#F5F7FA")
        static let accentDim       = Color(lightHex: "#000000", darkHex: "#FFFFFF").opacity(0.08)
        static let purple          = Color(hex: "#7C66DC")
        static let purpleDim       = Color(hex: "#7C66DC").opacity(0.15)
        static let green           = Color(hex: "#4D8B55")
        static let red             = Color(hex: "#C65345")
        static let yellow          = Color(hex: "#D49A36")
        static let orange          = Color(hex: "#D97757")

        static let textPrimary     = Color(lightHex: "#111111", darkHex: "#E8ECF2")
        static let textSecondary   = Color(lightHex: "#666666", darkHex: "#B5BCC9")
        static let textTertiary    = Color(lightHex: "#999999", darkHex: "#8891A1")
        static let textAccent      = accent

        static let userBubble      = Color(lightHex: "#F3F3F3", darkHex: "#20242C")
        static let assistantBubble = Color(lightHex: "#FFFFFF", darkHex: "#151922")
        static let toolBubble      = Color(lightHex: "#F9F9F9", darkHex: "#181C24")

        // Glow (soft shadow colors)
        static let glowBlue    = Color(lightHex: "#000000", darkHex: "#4C7DFF").opacity(0.12)
        static let glowPurple  = Color(lightHex: "#000000", darkHex: "#7C66DC").opacity(0.12)
    }

    // MARK: Gradients
    enum Gradients {
        static let accentLinear = LinearGradient(
            colors: [Color(hex: "#333333"), Color(hex: "#000000")],
            startPoint: .leading, endPoint: .trailing
        )
        static let backgroundRadial = RadialGradient(
            colors: [Color(hex: "#FFFFFF"), Color(hex: "#F9F9F9")],
            center: .top, startRadius: 0, endRadius: 600
        )
        static let glowTop = LinearGradient(
            colors: [Color.black.opacity(0.02), .clear],
            startPoint: .top, endPoint: .bottom
        )
        static let userBubble = LinearGradient(
            colors: [
                Color(lightHex: "#F3F3F3", darkHex: "#252A33"),
                Color(lightHex: "#ECECEC", darkHex: "#1E232C")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let pill: CGFloat = 100
    }

    // MARK: Typography helpers
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(lightHex: String, darkHex: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let best = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: best == .darkAqua ? darkHex : lightHex)
        })
    }
}

extension NSColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Glass Card
struct GlassCard: ViewModifier {
    var padding: CGFloat = DS.Spacing.lg
    var radius: CGFloat = DS.Radius.lg
    var borderColor: Color = DS.Colors.border
    var glowColor: Color = .clear

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.Colors.surface.opacity(0.8))
            .background(.ultraThinMaterial.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        LinearGradient(
                            colors: [borderColor.opacity(0.6), borderColor.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1
                    )
            )
            .shadow(color: glowColor, radius: 12, x: 0, y: 0)
    }
}

extension View {
    func glassCard(padding: CGFloat = DS.Spacing.lg, radius: CGFloat = DS.Radius.lg,
                   border: Color = DS.Colors.border, glow: Color = .clear) -> some View {
        modifier(GlassCard(padding: padding, radius: radius, borderColor: border, glowColor: glow))
    }
}

// MARK: - Pulsing Dot
struct PulsingDot: View {
    var color: Color = DS.Colors.accent
    var size: CGFloat = 8
    @State private var scale = 1.0
    @State private var opacity = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(scale)
                .opacity(1 - scale + 0.5)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scale = 1.5
            }
        }
    }
}

// MARK: - Shimmer / Loading
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let gradient = LinearGradient(
                stops: [
                    .init(color: DS.Colors.border.opacity(0.5), location: 0),
                    .init(color: DS.Colors.accent.opacity(0.15), location: 0.5),
                    .init(color: DS.Colors.border.opacity(0.5), location: 1)
                ],
                startPoint: .init(x: phase, y: 0),
                endPoint: .init(x: phase + 1, y: 0)
            )
            Rectangle().fill(gradient)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var dots: [Bool] = [false, false, false]
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    @State private var idx = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DS.Colors.accent)
                    .frame(width: 5, height: 5)
                    .scaleEffect(dots[i] ? 1.3 : 0.7)
                    .opacity(dots[i] ? 1 : 0.3)
                    .animation(.spring(response: 0.3), value: dots[i])
            }
        }
        .onReceive(timer) { _ in
            dots[idx % 3] = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dots[idx % 3] = false
            }
            idx += 1
        }
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    var color: Color = DS.Colors.accent
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(DS.mono(size, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    var label: String? = nil
    var color: Color = DS.Colors.textSecondary
    var hoverColor: Color = DS.Colors.accent
    var size: CGFloat = 15
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .medium))
                if let lbl = label {
                    Text(lbl).font(DS.body(12))
                }
            }
            .foregroundStyle(isHovered ? hoverColor : color)
            .padding(.horizontal, label != nil ? 8 : 6)
            .padding(.vertical, 5)
            .background(isHovered ? hoverColor.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let ic = icon {
                Image(systemName: ic)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Colors.textTertiary)
                .tracking(1.2)
            Spacer()
            trailing
        }
    }
}

// MARK: - Context Usage Bar
struct ContextBar: View {
    let percent: Double
    let tokens: Int
    let window: Int

    var color: Color {
        if percent > 85 { return DS.Colors.red }
        if percent > 65 { return DS.Colors.yellow }
        return DS.Colors.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Context")
                    .font(DS.body(11))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text("\(Int(percent))%")
                    .font(DS.mono(11, weight: .medium))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.border)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.7)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * CGFloat(min(percent, 100)) / 100)
                        .animation(.spring(response: 0.5), value: percent)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(formatK(tokens)) tokens")
                Spacer()
                Text("/ \(formatK(window))")
            }
            .font(DS.mono(10))
            .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    private func formatK(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }
}

// MARK: - Animated Gradient Border
struct AnimatedBorderModifier: ViewModifier {
    @State private var rotation: Double = 0
    var isActive: Bool = true
    var colors: [Color] = [DS.Colors.accent, DS.Colors.purple, DS.Colors.accent]
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .stroke(
                            AngularGradient(colors: colors, center: .center, angle: .degrees(rotation)),
                            lineWidth: lineWidth
                        )
                        .onAppear {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
            }
        )
    }
}

extension View {
    func animatedBorder(active: Bool = true) -> some View {
        modifier(AnimatedBorderModifier(isActive: active))
    }
}
