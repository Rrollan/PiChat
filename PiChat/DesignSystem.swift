import SwiftUI
import AppKit

// MARK: - Design System

enum DS {

    // MARK: Colors
    enum Colors {
        // Claude-inspired monochrome palette: quiet surfaces, high contrast text, no color accent bias.
        static let background      = Color(lightHex: "#F7F6F2", darkHex: "#20201D")
        static let surface         = Color(lightHex: "#EEEDE8", darkHex: "#282824")
        static let surfaceElevated = Color(lightHex: "#FFFFFF", darkHex: "#30302B")
        static let border          = Color(lightHex: "#DDDAD1", darkHex: "#434239")
        static let borderAccent    = Color(lightHex: "#C6C1B6", darkHex: "#5A584E")

        static let accent          = Color(lightHex: "#2B2924", darkHex: "#D8D3C7")
        static let accentDim       = Color(lightHex: "#2B2924", darkHex: "#D8D3C7").opacity(0.09)
        static let purple          = Color(lightHex: "#68645B", darkHex: "#BDB7AA")
        static let purpleDim       = Color(lightHex: "#2B2924", darkHex: "#D8D3C7").opacity(0.09)
        static let green           = Color(lightHex: "#3F6B4A", darkHex: "#8DBA97")
        static let red             = Color(lightHex: "#A2433B", darkHex: "#E1847B")
        static let yellow          = Color(lightHex: "#8A6A2E", darkHex: "#D6BF79")
        static let orange          = Color(lightHex: "#6B6256", darkHex: "#C7BEB1")

        static let textPrimary     = Color(lightHex: "#25231F", darkHex: "#EEEAE0")
        static let textSecondary   = Color(lightHex: "#6B665D", darkHex: "#C2BCB0")
        static let textTertiary    = Color(lightHex: "#969085", darkHex: "#969084")
        static let textAccent      = accent

        static let userBubble      = Color(lightHex: "#E9E6DE", darkHex: "#38372F")
        static let assistantBubble = Color(lightHex: "#F7F6F2", darkHex: "#20201D")
        static let toolBubble      = Color(lightHex: "#EFEEE9", darkHex: "#2D2D28")

        // Glow (subtle monochrome shadows)
        static let glowBlue    = Color(lightHex: "#000000", darkHex: "#FFFFFF").opacity(0.08)
        static let glowPurple  = Color(lightHex: "#000000", darkHex: "#FFFFFF").opacity(0.08)
    }

    // MARK: Gradients
    enum Gradients {
        static let accentLinear = LinearGradient(
            colors: [Color(lightHex: "#3B3932", darkHex: "#6A675D"), Color(lightHex: "#24221E", darkHex: "#545147")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let backgroundRadial = RadialGradient(
            colors: [Color(lightHex: "#FFFFFF", darkHex: "#2A2A26"), Color(lightHex: "#F7F6F2", darkHex: "#20201D")],
            center: .top, startRadius: 0, endRadius: 720
        )
        static let glowTop = LinearGradient(
            colors: [Color.black.opacity(0.025), .clear],
            startPoint: .top, endPoint: .bottom
        )
        static let userBubble = LinearGradient(
            colors: [
                Color(lightHex: "#ECE9E1", darkHex: "#3A3932"),
                Color(lightHex: "#E3DFD5", darkHex: "#32312C")
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
struct ShiningText: View {
    let text: String
    var font: Font = DS.body(14)
    var duration: Double = 2.0
    @State private var phase = false

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: DS.Colors.textSecondary.opacity(0.55), location: 0.0),
                        .init(color: DS.Colors.textPrimary, location: 0.35),
                        .init(color: DS.Colors.textPrimary, location: 0.50),
                        .init(color: DS.Colors.textSecondary.opacity(0.55), location: 0.75),
                        .init(color: DS.Colors.textSecondary.opacity(0.55), location: 1.0)
                    ],
                    startPoint: UnitPoint(x: phase ? -1.0 : 1.35, y: 0.5),
                    endPoint: UnitPoint(x: phase ? 0.2 : 2.55, y: 0.5)
                )
            )
            .onAppear {
                phase = false
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = true
                }
            }
            .accessibilityLabel(text)
    }
}

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let gradient = LinearGradient(
                stops: [
                    .init(color: DS.Colors.border.opacity(0.5), location: 0),
                    .init(color: DS.Colors.accent.opacity(0.18), location: 0.5),
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
    var size: CGFloat = 17
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
            .frame(minWidth: label != nil ? 0 : 30, minHeight: 30)
            .padding(.horizontal, label != nil ? 8 : 4)
            .padding(.vertical, label != nil ? 6 : 4)
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
    var colors: [Color] = [DS.Colors.borderAccent, DS.Colors.accent.opacity(0.65), DS.Colors.borderAccent]
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
