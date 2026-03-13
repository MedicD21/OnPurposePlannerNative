import SwiftUI
import EventKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var store: PlannerStore
    @ObservedObject var settings: AppSettings

    @State private var step = 0

    var body: some View {
        ZStack {
            onboardingBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                onboardingHeader
                    .padding(.top, 34)
                    .padding(.horizontal, 32)

                Spacer(minLength: 24)

                VStack(spacing: 0) {
                    Group {
                        switch step {
                        case 0: welcomeStep
                        case 1: calendarStep
                        case 2: photosStep
                        case 3: styleStep
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: step)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 38)
                .padding(.vertical, 34)
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.74))
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(BrandPalette.indigo.opacity(0.14), lineWidth: 1.2)
                        )
                )
                .shadow(color: BrandPalette.indigo.opacity(0.10), radius: 24, x: 0, y: 16)

                Spacer()

                // Navigation buttons
                HStack(spacing: 20) {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .foregroundStyle(BrandPalette.indigo.opacity(0.75))
                    }
                    Spacer()
                    if step < 3 {
                        Button(step == 0 ? "Get Started" : "Next") { step += 1 }
                            .buttonStyle(OnboardingPrimaryButtonStyle())
                    } else {
                        Button("Start Planning") {
                            hasCompletedOnboarding = true
                        }
                        .buttonStyle(OnboardingPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, 38)
                .padding(.bottom, 40)
                .frame(maxWidth: 760)
            }
        }
        .statusBar(hidden: true)
    }

    private var onboardingHeader: some View {
        HStack(spacing: 20) {
            HStack(spacing: 14) {
                Image("OnboardingIcon")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: BrandPalette.indigo.opacity(0.10), radius: 10, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text("OnPurpose Planner")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandPalette.indigo)
                    Text("Paper-feel planning for Apple Pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BrandPalette.indigo.opacity(0.65))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i == step ? BrandPalette.indigo : BrandPalette.indigo.opacity(0.14))
                        .frame(width: i == step ? 28 : 10, height: 10)
                        .animation(.spring(duration: 0.3), value: step)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.62))
            )
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            BrandPalette.base

            LinearGradient(
                colors: [
                    BrandPalette.base,
                    BrandPalette.base.opacity(0.96),
                    BrandPalette.paperGlow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            BrandRibbonShape()
                .fill(BrandPalette.teal.opacity(0.50))
                .frame(width: 520, height: 120)
                .offset(x: -130, y: -250)

            BrandRibbonShape()
                .fill(BrandPalette.sage.opacity(0.52))
                .frame(width: 520, height: 120)
                .offset(x: -130, y: -80)

            BrandRibbonShape()
                .fill(BrandPalette.blush.opacity(0.52))
                .frame(width: 520, height: 120)
                .offset(x: -130, y: 90)

            BrandRibbonShape()
                .fill(BrandPalette.sand.opacity(0.55))
                .frame(width: 520, height: 120)
                .offset(x: -130, y: 260)

            Circle()
                .fill(BrandPalette.indigo.opacity(0.05))
                .frame(width: 520, height: 520)
                .blur(radius: 16)
                .offset(x: 310, y: -260)
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.34))
                    .frame(width: 260, height: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(BrandPalette.indigo.opacity(0.10), lineWidth: 1)
                    )

                Image("OnboardingIcon")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 46, style: .continuous))
                    .shadow(color: BrandPalette.indigo.opacity(0.12), radius: 18, x: 0, y: 10)
            }

            VStack(spacing: 8) {
                Text("OnPurpose Planner")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandPalette.indigo)
                Text("Plan with intention, write naturally, and keep your week grounded in one place.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BrandPalette.indigo.opacity(0.66))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                welcomePill("Apple Pencil", color: BrandPalette.teal)
                welcomePill("Calendar", color: BrandPalette.blush)
                welcomePill("Paper Feel", color: BrandPalette.sand)
            }
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Calendar

    private var calendarStep: some View {
        VStack(spacing: 24) {
            featureTile(
                systemImage: "calendar.badge.clock",
                tint: BrandPalette.indigo,
                background: BrandPalette.teal
            )

            VStack(spacing: 8) {
                Text("Calendar Events")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandPalette.indigo)
                Text("See your iOS calendar events directly on your planner pages. Your data stays on-device — we never upload it.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandPalette.indigo.opacity(0.66))
                    .multilineTextAlignment(.center)
            }

            calendarPermissionButton
        }
        .padding(.horizontal, 60)
    }

    @ViewBuilder
    private var calendarPermissionButton: some View {
        let status = store.calendarManager.authStatus
        switch status {
        case .fullAccess:
            Label("Access Granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(BrandPalette.indigo)
                .font(.system(size: 15, weight: .medium))
        case .denied, .restricted:
            VStack(spacing: 8) {
                Text("Access was denied. You can enable it in Settings > Privacy > Calendars.")
                    .font(.system(size: 13))
                    .foregroundStyle(BrandPalette.indigo.opacity(0.62))
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            }
        default:
            Button("Allow Calendar Access") {
                Task { await store.calendarManager.requestAccess() }
            }
            .buttonStyle(OnboardingSecondaryButtonStyle())
        }
    }

    // MARK: - Photos

    private var photosStep: some View {
        VStack(spacing: 24) {
            featureTile(
                systemImage: "photo.stack",
                tint: BrandPalette.indigo,
                background: BrandPalette.blush
            )

            VStack(spacing: 8) {
                Text("Photo Attachments")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandPalette.indigo)
                Text("Attach photos from your library to any planner page. Tap the photo icon in the toolbar to get started.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandPalette.indigo.opacity(0.66))
                    .multilineTextAlignment(.center)
            }

            Text("Photos access is requested when you first attach an image — no action needed now.")
                .font(.system(size: 13))
                .foregroundStyle(BrandPalette.indigo.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Planner style

    private var styleStep: some View {
        VStack(spacing: 28) {
            featureTile(
                systemImage: "paintpalette.fill",
                tint: BrandPalette.indigo,
                background: BrandPalette.sand
            )

            VStack(spacing: 8) {
                Text("Choose Your Style")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandPalette.indigo)
                Text("More planner styles are coming soon. For now, Classic gives you everything you need.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BrandPalette.indigo.opacity(0.66))
                    .multilineTextAlignment(.center)
            }

            // Style cards
            VStack(spacing: 12) {
                ForEach(PlannerStyle.allCases, id: \.self) { style in
                    styleCard(style)
                }

                // Placeholder for upcoming styles
                HStack(spacing: 12) {
                    ForEach(["Minimal", "Bold", "Vintage"], id: \.self) { name in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(BrandPalette.indigo.opacity(0.08))
                                .frame(height: 60)
                                .overlay(
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(BrandPalette.indigo.opacity(0.40))
                                )
                            Text(name)
                                .font(.system(size: 11))
                                .foregroundStyle(BrandPalette.indigo.opacity(0.50))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 40)
    }

    private func styleCard(_ style: PlannerStyle) -> some View {
        let selected = settings.plannerStyle == style
        return Button {
            settings.plannerStyle = style
        } label: {
            HStack(spacing: 16) {
                Image(systemName: style.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(selected ? Color.white : BrandPalette.indigo)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selected ? BrandPalette.indigo : BrandPalette.teal.opacity(0.48))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BrandPalette.indigo)
                    Text(style.description)
                        .font(.system(size: 13))
                        .foregroundStyle(BrandPalette.indigo.opacity(0.58))
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandPalette.indigo)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(selected ? 0.90 : 0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? BrandPalette.indigo : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func featureTile(systemImage: String, tint: Color, background: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(background.opacity(0.78))
                .frame(width: 128, height: 128)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(tint.opacity(0.12), lineWidth: 1)
                )

            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func welcomePill(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(BrandPalette.indigo.opacity(0.86))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(color.opacity(0.82))
            )
    }
}

// MARK: - Button styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(BrandPalette.indigo)
                    .shadow(color: BrandPalette.indigo.opacity(0.18), radius: 10, x: 0, y: 6)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(BrandPalette.indigo)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.62))
                    .overlay(
                        Capsule()
                            .stroke(BrandPalette.indigo.opacity(0.35), lineWidth: 1.5)
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

enum BrandPalette {
    static let base = Color(hex: "#d9efb8")
    static let paperGlow = Color(hex: "#f7fbef")
    static let teal = Color(hex: "#91cfcd")
    static let sage = Color(hex: "#b6d5ae")
    static let blush = Color(hex: "#f4cad4")
    static let sand = Color(hex: "#f0d898")
    static let indigo = Color(hex: "#6868c8")
}

struct BrandRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = min(rect.width * 0.12, 56)
        let radius = min(rect.height * 0.16, 16)

        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.closeSubpath()
        }
    }
}
