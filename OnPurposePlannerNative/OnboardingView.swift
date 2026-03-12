import SwiftUI
import EventKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var store: PlannerStore
    @ObservedObject var settings: AppSettings

    @State private var step = 0

    var body: some View {
        ZStack {
            PlannerTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i == step ? PlannerTheme.accent : PlannerTheme.hairline)
                            .frame(width: i == step ? 24 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: step)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Step content
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
                    removal:   .move(edge: .leading).combined(with: .opacity)))
                .animation(.easeInOut(duration: 0.3), value: step)

                Spacer()

                // Navigation buttons
                HStack(spacing: 20) {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .foregroundStyle(PlannerTheme.line)
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
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }
        .statusBar(hidden: true)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(PlannerTheme.accent)

            VStack(spacing: 8) {
                Text("OnPurpose Planner")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(PlannerTheme.ink)
                Text("Your thoughtful daily companion.\nPlan with intention, live on purpose.")
                    .font(.system(size: 17))
                    .foregroundStyle(PlannerTheme.line)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Calendar

    private var calendarStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar")
                .font(.system(size: 70, weight: .thin))
                .foregroundStyle(PlannerTheme.accent)

            VStack(spacing: 8) {
                Text("Calendar Events")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(PlannerTheme.ink)
                Text("See your iOS calendar events directly on your planner pages. Your data stays on-device — we never upload it.")
                    .font(.system(size: 15))
                    .foregroundStyle(PlannerTheme.line)
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
                .foregroundStyle(.green)
                .font(.system(size: 15, weight: .medium))
        case .denied, .restricted:
            VStack(spacing: 8) {
                Text("Access was denied. You can enable it in Settings > Privacy > Calendars.")
                    .font(.system(size: 13))
                    .foregroundStyle(PlannerTheme.line)
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
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70, weight: .thin))
                .foregroundStyle(PlannerTheme.accent)

            VStack(spacing: 8) {
                Text("Photo Attachments")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(PlannerTheme.ink)
                Text("Attach photos from your library to any planner page. Tap the photo icon in the toolbar to get started.")
                    .font(.system(size: 15))
                    .foregroundStyle(PlannerTheme.line)
                    .multilineTextAlignment(.center)
            }

            Text("Photos access is requested when you first attach an image — no action needed now.")
                .font(.system(size: 13))
                .foregroundStyle(PlannerTheme.line)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Planner style

    private var styleStep: some View {
        VStack(spacing: 28) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 70, weight: .thin))
                .foregroundStyle(PlannerTheme.accent)

            VStack(spacing: 8) {
                Text("Choose Your Style")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(PlannerTheme.ink)
                Text("More planner styles are coming soon. For now, Classic gives you everything you need.")
                    .font(.system(size: 15))
                    .foregroundStyle(PlannerTheme.line)
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
                                .fill(PlannerTheme.hairline.opacity(0.5))
                                .frame(height: 60)
                                .overlay(
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(PlannerTheme.line)
                                )
                            Text(name)
                                .font(.system(size: 11))
                                .foregroundStyle(PlannerTheme.line)
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
                    .foregroundStyle(selected ? PlannerTheme.paper : PlannerTheme.accent)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selected ? PlannerTheme.cover : PlannerTheme.tab)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PlannerTheme.ink)
                    Text(style.description)
                        .font(.system(size: 13))
                        .foregroundStyle(PlannerTheme.line)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PlannerTheme.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(PlannerTheme.tab)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? PlannerTheme.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
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
                Capsule().fill(PlannerTheme.cover)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(PlannerTheme.cover)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(PlannerTheme.cover, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
