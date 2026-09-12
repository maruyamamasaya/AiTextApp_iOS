import SwiftUI

// MARK: - Primitive

enum ThemePrimitive {
    static let cyan = Color(red: 0.33, green: 0.87, blue: 0.88)
    static let blue = Color(red: 0.30, green: 0.49, blue: 1.00)
    static let violet = Color(red: 0.55, green: 0.42, blue: 1.00)
    static let magenta = Color(red: 0.84, green: 0.39, blue: 0.78)
    static let emerald = Color(red: 0.35, green: 0.84, blue: 0.63)
    static let ink = Color(red: 0.02, green: 0.03, blue: 0.06)
    static let navy = Color(red: 0.02, green: 0.06, blue: 0.15)

    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 18
    static let radiusLarge: CGFloat = 28
    static let motionUI = 0.22
    static let motionAmbient = 28.0
}

// MARK: - Semantic

struct ThemeSemanticColors {
    let background: Color
    let backgroundSecondary: Color
    let surface: Color
    let surfaceElevated: Color
    let text: Color
    let textSecondary: Color
    let accent: Color
    let accentSecondary: Color
    let edge: Color
    let aiAccent: Color
}

struct ThemeSurfaceTokens {
    let radius: CGFloat
    let borderOpacity: Double
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let material: Material?
}

struct ThemeTypographyTokens {
    let usesTechnicalMetadata: Bool
    let headingWeight: Font.Weight
}

struct ThemeMotionTokens {
    let uiDuration: Double
    let ambientDuration: Double
    let ambientStrength: Double
}

struct ThemeEffectTokens {
    let particleCount: Int
    let glowOpacity: Double
    let aiGlowOpacity: Double
    let supportsSignal: Bool
    let supportsStars: Bool
    let supportsAurora: Bool
}

struct AppThemeTokens {
    let colors: ThemeSemanticColors
    let surface: ThemeSurfaceTokens
    let typography: ThemeTypographyTokens
    let motion: ThemeMotionTokens
    let effects: ThemeEffectTokens
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case `default`
    case dynamicAurora
    case pulseNeon
    case blueCosmos

    var id: String { rawValue }

    var name: String {
        switch self {
        case .default: return "デフォルト"
        case .dynamicAurora: return "ダイナミック・オーロラ"
        case .pulseNeon: return "パルス・ネオン"
        case .blueCosmos: return "ブルー・コスモス"
        }
    }

    var summary: String {
        switch self {
        case .default: return "静かで読みやすい標準スタイル"
        case .dynamicAurora: return "流れる光と反応するGlass Surface"
        case .pulseNeon: return "精密なSignal、Pulse、控えめなGlow"
        case .blueCosmos: return "深い青、星、ゆっくり漂うNebula"
        }
    }

    var tokens: AppThemeTokens {
        switch self {
        case .default:
            return AppThemeTokens(
                colors: .init(
                    background: Color(uiColor: .systemBackground),
                    backgroundSecondary: Color(uiColor: .secondarySystemBackground),
                    surface: Color(uiColor: .secondarySystemBackground),
                    surfaceElevated: Color(uiColor: .tertiarySystemBackground),
                    text: Color(uiColor: .label), textSecondary: Color(uiColor: .secondaryLabel),
                    accent: .accentColor, accentSecondary: .blue,
                    edge: Color(uiColor: .separator), aiAccent: .indigo
                ),
                surface: .init(radius: 14, borderOpacity: 0.18, shadowColor: .clear, shadowRadius: 0, shadowY: 0, material: nil),
                typography: .init(usesTechnicalMetadata: false, headingWeight: .semibold),
                motion: .init(uiDuration: 0.18, ambientDuration: 0, ambientStrength: 0),
                effects: .init(particleCount: 0, glowOpacity: 0, aiGlowOpacity: 0.08, supportsSignal: false, supportsStars: false, supportsAurora: false)
            )
        case .dynamicAurora:
            return AppThemeTokens(
                colors: .init(
                    background: ThemePrimitive.ink, backgroundSecondary: Color(red: 0.03, green: 0.04, blue: 0.09),
                    surface: Color.white.opacity(0.075), surfaceElevated: Color.white.opacity(0.11),
                    text: Color(red: 0.93, green: 0.95, blue: 1), textSecondary: Color(red: 0.68, green: 0.72, blue: 0.83),
                    accent: ThemePrimitive.cyan, accentSecondary: ThemePrimitive.violet,
                    edge: Color.white, aiAccent: ThemePrimitive.magenta
                ),
                surface: .init(radius: ThemePrimitive.radiusMedium, borderOpacity: 0.16, shadowColor: ThemePrimitive.violet.opacity(0.22), shadowRadius: 22, shadowY: 9, material: .ultraThinMaterial),
                typography: .init(usesTechnicalMetadata: false, headingWeight: .semibold),
                motion: .init(uiDuration: ThemePrimitive.motionUI, ambientDuration: 34, ambientStrength: 0.72),
                effects: .init(particleCount: 10, glowOpacity: 0.24, aiGlowOpacity: 0.22, supportsSignal: false, supportsStars: false, supportsAurora: true)
            )
        case .pulseNeon:
            return AppThemeTokens(
                colors: .init(
                    background: Color(red: 0.01, green: 0.04, blue: 0.05), backgroundSecondary: Color(red: 0.025, green: 0.075, blue: 0.095),
                    surface: Color(red: 0.035, green: 0.09, blue: 0.11), surfaceElevated: Color(red: 0.045, green: 0.12, blue: 0.14),
                    text: Color(red: 0.88, green: 1, blue: 1), textSecondary: Color(red: 0.55, green: 0.72, blue: 0.74),
                    accent: Color(red: 0.27, green: 0.94, blue: 0.94), accentSecondary: ThemePrimitive.violet,
                    edge: ThemePrimitive.cyan, aiAccent: ThemePrimitive.emerald
                ),
                surface: .init(radius: ThemePrimitive.radiusSmall, borderOpacity: 0.14, shadowColor: ThemePrimitive.cyan.opacity(0.15), shadowRadius: 12, shadowY: 4, material: nil),
                typography: .init(usesTechnicalMetadata: true, headingWeight: .medium),
                motion: .init(uiDuration: 0.16, ambientDuration: 12, ambientStrength: 0.48),
                effects: .init(particleCount: 0, glowOpacity: 0.18, aiGlowOpacity: 0.28, supportsSignal: true, supportsStars: false, supportsAurora: false)
            )
        case .blueCosmos:
            return AppThemeTokens(
                colors: .init(
                    background: Color(red: 0.008, green: 0.025, blue: 0.08), backgroundSecondary: ThemePrimitive.navy,
                    surface: Color(red: 0.035, green: 0.085, blue: 0.18).opacity(0.82), surfaceElevated: Color(red: 0.05, green: 0.13, blue: 0.27).opacity(0.88),
                    text: Color(red: 0.90, green: 0.95, blue: 1), textSecondary: Color(red: 0.62, green: 0.72, blue: 0.86),
                    accent: Color(red: 0.41, green: 0.65, blue: 1), accentSecondary: Color(red: 0.72, green: 0.86, blue: 1),
                    edge: Color(red: 0.72, green: 0.86, blue: 1), aiAccent: ThemePrimitive.cyan
                ),
                surface: .init(radius: 20, borderOpacity: 0.14, shadowColor: Color.blue.opacity(0.25), shadowRadius: 24, shadowY: 12, material: .ultraThinMaterial),
                typography: .init(usesTechnicalMetadata: false, headingWeight: .medium),
                motion: .init(uiDuration: ThemePrimitive.motionUI, ambientDuration: 58, ambientStrength: 0.42),
                effects: .init(particleCount: 22, glowOpacity: 0.18, aiGlowOpacity: 0.20, supportsSignal: false, supportsStars: true, supportsAurora: false)
            )
        }
    }
}

final class ThemeController: ObservableObject {
    static let defaultsKey = "appearance.theme.v1"

    @Published var selection: AppTheme {
        didSet { defaults.set(selection.rawValue, forKey: Self.defaultsKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") && !arguments.contains("--ui-testing-theme-persistence") {
            selection = .default
        } else if let rawValue = defaults.string(forKey: Self.defaultsKey), let saved = AppTheme(rawValue: rawValue) {
            selection = saved
        } else {
            selection = .default
        }
    }
}

private struct AppThemeTokensKey: EnvironmentKey {
    static let defaultValue = AppTheme.default.tokens
}

extension EnvironmentValues {
    var appTheme: AppThemeTokens {
        get { self[AppThemeTokensKey.self] }
        set { self[AppThemeTokensKey.self] = newValue }
    }
}

enum ThemeScreenIntensity {
    case calm
    case expressive

    var multiplier: Double { self == .calm ? 0.62 : 1.0 }
}

// MARK: - Effect

struct ThemeHost<Content: View>: View {
    @ObservedObject var controller: ThemeController
    let content: Content

    init(controller: ThemeController, @ViewBuilder content: () -> Content) {
        self.controller = controller
        self.content = content()
    }

    var body: some View {
        let tokens = controller.selection.tokens
        ZStack {
            tokens.colors.background.ignoresSafeArea()
            content
        }
        .environment(\.appTheme, tokens)
        .preferredColorScheme(controller.selection == .default ? nil : .dark)
        .tint(tokens.colors.accent)
        .foregroundStyle(tokens.colors.text)
    }
}

struct ThemedScreenBackground: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let intensity: ThemeScreenIntensity

    var body: some View {
        ZStack {
            theme.colors.background
            if theme.effects.supportsAurora { aurora }
            if theme.effects.supportsSignal { signal }
            if theme.effects.supportsStars { cosmos }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var strength: Double { theme.motion.ambientStrength * intensity.multiplier }

    private var aurora: some View {
        GeometryReader { proxy in
            ZStack {
                MovingLight(color: ThemePrimitive.violet, size: proxy.size.width * 1.05, offset: CGSize(width: -proxy.size.width * 0.28, height: -proxy.size.height * 0.26), travel: CGSize(width: proxy.size.width * 0.24, height: proxy.size.height * 0.13), duration: theme.motion.ambientDuration, opacity: 0.22 * strength, paused: reduceMotion)
                MovingLight(color: ThemePrimitive.cyan, size: proxy.size.width * 0.9, offset: CGSize(width: proxy.size.width * 0.31, height: proxy.size.height * 0.08), travel: CGSize(width: -proxy.size.width * 0.22, height: proxy.size.height * 0.18), duration: theme.motion.ambientDuration * 1.31, opacity: 0.19 * strength, paused: reduceMotion)
                MovingLight(color: ThemePrimitive.magenta, size: proxy.size.width * 0.72, offset: CGSize(width: -proxy.size.width * 0.12, height: proxy.size.height * 0.38), travel: CGSize(width: proxy.size.width * 0.20, height: -proxy.size.height * 0.10), duration: theme.motion.ambientDuration * 1.57, opacity: 0.13 * strength, paused: reduceMotion)
            }
            .blur(radius: 48)
        }
    }

    private var signal: some View {
        GeometryReader { proxy in
            ZStack {
                Path { path in
                    for index in 0..<7 {
                        let y = CGFloat(index) * 64 + 24
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    for index in 0..<6 {
                        let x = CGFloat(index) * 70 + 15
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                }
                .stroke(theme.colors.accent.opacity(0.035 * strength), lineWidth: 0.5)
                SignalSweep(color: theme.colors.accent, duration: theme.motion.ambientDuration, opacity: 0.24 * strength, paused: reduceMotion)
            }
        }
    }

    private var cosmos: some View {
        GeometryReader { proxy in
            ZStack {
                MovingLight(color: Color.blue, size: proxy.size.width * 1.25, offset: CGSize(width: -proxy.size.width * 0.4, height: -proxy.size.height * 0.16), travel: CGSize(width: proxy.size.width * 0.12, height: proxy.size.height * 0.06), duration: theme.motion.ambientDuration, opacity: 0.15 * strength, paused: reduceMotion)
                    .blur(radius: 55)
                ForEach(StarSeed.values.prefix(theme.effects.particleCount)) { star in
                    Circle()
                        .fill(star.tint)
                        .frame(width: star.size, height: star.size)
                        .shadow(color: star.tint.opacity(star.isBright ? 0.7 : 0), radius: star.isBright ? 4 : 0)
                        .position(x: proxy.size.width * star.x, y: proxy.size.height * star.y)
                        .opacity(star.opacity * strength)
                }
            }
        }
    }
}

private struct MovingLight: View {
    let color: Color
    let size: CGFloat
    let offset: CGSize
    let travel: CGSize
    let duration: Double
    let opacity: Double
    let paused: Bool
    @State private var moved = false

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size * 0.72)
            .offset(x: offset.width + (moved ? travel.width : 0), y: offset.height + (moved ? travel.height : 0))
            .opacity(opacity)
            .onAppear {
                guard !paused, duration > 0 else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) { moved = true }
            }
    }
}

private struct SignalSweep: View {
    let color: Color
    let duration: Double
    let opacity: Double
    let paused: Bool
    @State private var travels = false

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(LinearGradient(colors: [.clear, color, .white, color, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: 110, height: 1)
                .offset(x: travels ? proxy.size.width : -120, y: proxy.size.height * 0.36)
                .opacity(opacity)
                .shadow(color: color, radius: 5)
                .onAppear {
                    guard !paused else { return }
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) { travels = true }
                }
        }
    }
}

private struct StarSeed: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let tint: Color
    let isBright: Bool

    static let values: [StarSeed] = (0..<28).map { index in
        let x = CGFloat((index * 47 + 13) % 101) / 100
        let y = CGFloat((index * 71 + 9) % 103) / 102
        let bright = index == 5 || index == 17 || index == 23
        return StarSeed(id: index, x: x, y: y, size: bright ? 2.6 : CGFloat(1 + index % 2), opacity: bright ? 0.88 : 0.48, tint: index % 5 == 0 ? ThemePrimitive.cyan : Color(red: 0.84, green: 0.91, blue: 1), isBright: bright)
    }
}

struct ThemeSurfaceModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    let elevated: Bool
    let isAI: Bool

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                ZStack {
                    if let material = theme.surface.material {
                        RoundedRectangle(cornerRadius: theme.surface.radius, style: .continuous)
                            .fill(material)
                    }
                    RoundedRectangle(cornerRadius: theme.surface.radius, style: .continuous)
                        .fill(elevated ? theme.colors.surfaceElevated : theme.colors.surface)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.surface.radius, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [(isAI ? theme.colors.aiAccent : theme.colors.edge).opacity(theme.surface.borderOpacity * (isAI ? 1.8 : 1)), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
            .shadow(color: isAI ? theme.colors.aiAccent.opacity(theme.effects.aiGlowOpacity) : theme.surface.shadowColor, radius: isAI ? theme.surface.shadowRadius * 0.7 : theme.surface.shadowRadius, y: theme.surface.shadowY)
    }
}

extension View {
    func themeSurface(elevated: Bool = false, isAI: Bool = false) -> some View {
        modifier(ThemeSurfaceModifier(elevated: elevated, isAI: isAI))
    }

    func themedScreen(_ intensity: ThemeScreenIntensity = .calm) -> some View {
        background(ThemedScreenBackground(intensity: intensity).ignoresSafeArea())
    }

    func themedScrollableBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.clear)
    }
}

struct ThemePreviewCard: View {
    let theme: AppTheme
    let selected: Bool

    var body: some View {
        let tokens = theme.tokens
        ZStack {
            tokens.colors.background
            LinearGradient(
                colors: [tokens.colors.accent.opacity(0.45), tokens.colors.accentSecondary.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(tokens.colors.accent).frame(width: 9, height: 9)
                    Text(theme.name).font(.caption.weight(.semibold))
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill") }
                }
                RoundedRectangle(cornerRadius: tokens.surface.radius * 0.55)
                    .fill(tokens.colors.surfaceElevated)
                    .frame(height: 35)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(tokens.colors.text).frame(width: 70, height: 4)
                            Capsule().fill(tokens.colors.textSecondary).frame(width: 104, height: 3)
                        }.padding(9)
                    }
                    .overlay(alignment: .trailing) {
                        Text("AI")
                            .font(.system(size: 8, weight: .bold, design: tokens.typography.usesTechnicalMetadata ? .monospaced : .default))
                            .foregroundStyle(tokens.colors.aiAccent)
                            .padding(.trailing, 9)
                            .shadow(color: tokens.colors.aiAccent.opacity(tokens.effects.aiGlowOpacity), radius: 4)
                    }
            }
            .foregroundStyle(tokens.colors.text)
            .padding(12)
        }
        .frame(height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(tokens.colors.accent.opacity(selected ? 0.9 : 0.22), lineWidth: selected ? 2 : 1) }
    }
}

struct AppearanceThemeView: View {
    @ObservedObject var controller: ThemeController

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(.easeOut(duration: ThemePrimitive.motionUI)) { controller.selection = theme }
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            ThemePreviewCard(theme: theme, selected: controller.selection == theme)
                            Text(theme.summary).font(.caption).foregroundStyle(controller.selection.tokens.colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.name)、\(theme.summary)")
                    .accessibilityValue(controller.selection == theme ? "選択中" : "")
                    .accessibilityIdentifier("themeOption_\(theme.rawValue)")
                }
            }
            .padding()
        }
        .navigationTitle("外観とテーマ")
        .navigationBarTitleDisplayMode(.inline)
        .themedScreen(.expressive)
    }
}
