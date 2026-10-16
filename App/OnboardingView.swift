import AppKit
import ApplicationServices
import Combine
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
  case welcome
  case permissions
  case tutorial

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .welcome:
      return "Welcome"
    case .permissions:
      return "Permissions"
    case .tutorial:
      return "Quick tour"
    }
  }
}

struct OnboardingView: View {
  let model: AutomationViewModel

  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @State private var step: OnboardingStep = .welcome
  @State private var isFinishing = false

  var body: some View {
    VStack(spacing: 0) {
      OnboardingProgressTracker(currentStep: step, showsCompletion: isFinishing)
        .padding(.horizontal, 42)
        .padding(.top, 28)

      VStack {
        switch step {
        case .welcome:
          WelcomeStepView {
            withAnimation(.easeInOut(duration: 0.3)) {
              step = .permissions
            }
          }
        case .permissions:
          PermissionGuardStepView {
            withAnimation(.easeInOut(duration: 0.3)) {
              step = .tutorial
            }
          }
        case .tutorial:
          TutorialStepView {
            guard !isFinishing else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
              isFinishing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              model.completeOnboarding()
              hasCompletedOnboarding = true
            }
          }
        }
      }
      .frame(maxWidth: 780, maxHeight: .infinity)
      .padding(.horizontal, 42)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct OnboardingProgressTracker: View {
  let currentStep: OnboardingStep
  let showsCompletion: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Set up your workspace")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
        Spacer()
        Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        ForEach(OnboardingStep.allCases) { step in
          OnboardingProgressSegment(
            isCompleted: showsCompletion || step.rawValue < currentStep.rawValue,
            isActive: step == currentStep
          )
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 8)
      .animation(.easeInOut(duration: 0.3), value: currentStep)

      HStack {
        ForEach(OnboardingStep.allCases) { step in
          Text(step.title)
            .font(.caption)
            .foregroundStyle(step == currentStep ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

struct OnboardingProgressSegment: View {
  let isCompleted: Bool
  let isActive: Bool

  @State private var pulse = false

  var body: some View {
    RoundedRectangle(cornerRadius: 5, style: .continuous)
      .fill(
        isCompleted
          ? AnyShapeStyle(.tint)
          : isActive
            ? AnyShapeStyle(Color.accentColor.opacity(0.35))
            : AnyShapeStyle(.ultraThinMaterial)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
      }
      .opacity(isActive ? (pulse ? 1 : 0.7) : 1)
      .shadow(
        color: isActive ? Color.accentColor.opacity(0.45) : .clear,
        radius: isActive ? 7 : 0
      )
      .onChange(of: isActive, initial: true) { _, active in
        if active {
          pulse.toggle()
        } else {
          pulse = false
        }
      }
      .animation(
        isActive
          ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
          : .easeInOut(duration: 0.3),
        value: pulse
      )
      .animation(.easeInOut(duration: 0.3), value: isCompleted)
  }
}

struct WelcomeStepView: View {
  let onContinue: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      AppIconMark()
        .frame(width: 138, height: 138)
        .shadow(color: Color.accentColor.opacity(0.28), radius: 22, y: 10)

      VStack(spacing: 12) {
        Text("Meet MacClicker")
          .font(.system(size: 42, weight: .bold, design: .rounded))
          .foregroundStyle(.primary)
        Text("A precise, humanized input workspace for the Mac.")
          .font(.title3)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 28)

      Text("Build a repeatable rhythm, bind it to the right app, and keep a reliable panic switch close at hand.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)
        .padding(.top, 16)

      Spacer()

      Button("Get Started", systemImage: "arrow.right") {
        onContinue()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .keyboardShortcut(.defaultAction)
      .padding(.bottom, 34)
    }
  }
}

struct AppIconMark: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.mint, Color.teal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      if let appIcon = NSApplication.shared.applicationIconImage {
        Image(nsImage: appIcon)
          .resizable()
          .scaledToFit()
          .padding(18)
      } else {
        Image(systemName: "cursorarrow.click.2")
          .font(.system(size: 58, weight: .medium))
          .foregroundStyle(.white)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .strokeBorder(.white.opacity(0.28), lineWidth: 1)
    }
  }
}

struct PermissionGuardStepView: View {
  let onContinue: () -> Void

  @State private var isTrusted = AXIsProcessTrusted()
  @State private var hasAdvanced = false
  @State private var helperPanelController = AccessibilityOnboardingPanelController()
  private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Image(systemName: "hand.raised.square.fill")
        .font(.system(size: 54, weight: .medium))
        .foregroundStyle(Color.orange, Color.yellow)
        .symbolRenderingMode(.palette)

      Text("One permission, full control")
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .padding(.top, 22)

      Text("macOS protects simulated input behind Accessibility access. MacClicker uses it to deliver clicks and key presses only when you ask it to.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 570)
        .padding(.top, 14)

      PermissionStatusBadge(isTrusted: isTrusted)
        .padding(.top, 26)

      Button("Open Accessibility Settings", systemImage: "arrow.up.forward.app") {
        helperPanelController.present(
          applicationURL: Bundle.main.bundleURL,
          icon: NSApplication.shared.applicationIconImage
            ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path)
        )
        if let settingsURL = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
          NSWorkspace.shared.open(settingsURL)
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
      .padding(.top, 22)

      Text(
        isTrusted
          ? "Access is ready. MacClicker will continue automatically."
          : "Drag the MacClicker icon into the Accessibility list in System Settings. MacClicker continues as soon as access is granted."
      )
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 500)
        .padding(.top, 12)

      Spacer()
    }
    .onAppear(perform: refreshAccessibility)
    .onReceive(permissionTimer) { _ in
      refreshAccessibility()
    }
  }

  private func refreshAccessibility() {
    let trusted = AXIsProcessTrusted()
    if trusted != isTrusted {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
        isTrusted = trusted
      }
    }

    guard trusted, !hasAdvanced else { return }
    hasAdvanced = true
    helperPanelController.dismiss {
      onContinue()
    }
  }
}

struct PermissionStatusBadge: View {
  let isTrusted: Bool

  var body: some View {
    Label(
      isTrusted ? "Access Granted" : "Access Denied",
      systemImage: isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
    )
    .font(.headline)
    .foregroundStyle(isTrusted ? Color.green : Color.red)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay {
      Capsule()
        .strokeBorder((isTrusted ? Color.green : Color.red).opacity(0.28), lineWidth: 1)
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isTrusted)
  }
}

enum TutorialCard: String, CaseIterable, Hashable, Identifiable {
  case target
  case windows
  case panic

  var id: String { rawValue }

  var eyebrow: String {
    switch self {
    case .target:
      return "01 / INPUT"
    case .windows:
      return "02 / SAFETY"
    case .panic:
      return "03 / CONTROL"
    }
  }

  var title: String {
    switch self {
    case .target:
      return "Set Your Target"
    case .windows:
      return "Bind to Windows"
    case .panic:
      return "The Panic Switch"
    }
  }

  var detail: String {
    switch self {
    case .target:
      return "Choose a mouse button or bind a standard character, Spacebar, Enter, Escape, or a function command."
    case .windows:
      return "Lock a preset to a running app so automation stops when focus moves somewhere else."
    case .panic:
      return "Control + Option + Space toggles the engine. Moving the pointer to the screen edge is an immediate safety stop."
    }
  }

  var systemImage: String {
    switch self {
    case .target:
      return "scope"
    case .windows:
      return "macwindow.on.rectangle"
    case .panic:
      return "exclamationmark.octagon.fill"
    }
  }

  var colors: [Color] {
    switch self {
    case .target:
      return [.blue, .cyan]
    case .windows:
      return [.purple, .pink]
    case .panic:
      return [.orange, .red]
    }
  }
}

struct TutorialStepView: View {
  let onFinish: () -> Void

  @State private var selectedCard: TutorialCard = .target

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      Text("Fast-track your first run")
        .font(.system(size: 34, weight: .bold, design: .rounded))
      Text("Three habits make every session predictable.")
        .font(.body)
        .foregroundStyle(.secondary)
        .padding(.top, 10)

      HStack(spacing: 14) {
        Button {
          moveCard(by: -1)
        } label: {
          Image(systemName: "chevron.left")
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(selectedCard == TutorialCard.allCases.first)
        .help("Previous tutorial card")

        TutorialCardView(card: selectedCard)

        Button {
          moveCard(by: 1)
        } label: {
          Image(systemName: "chevron.right")
            .frame(width: 34, height: 34)
            .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(selectedCard == TutorialCard.allCases.last)
        .help("Next tutorial card")
      }
      .frame(height: 300)
      .padding(.top, 28)

      HStack(spacing: 6) {
        ForEach(TutorialCard.allCases) { card in
          Circle()
            .fill(card == selectedCard ? Color.accentColor : Color.secondary.opacity(0.25))
            .frame(width: 6, height: 6)
        }
      }
      .padding(.top, 14)

      HStack {
        Text("Ready for your workspace")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Finish", systemImage: "checkmark") {
          onFinish()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
      }
      .padding(.top, 20)
      .padding(.bottom, 34)
    }
  }

  private func moveCard(by offset: Int) {
    let cards = TutorialCard.allCases
    guard let currentIndex = cards.firstIndex(of: selectedCard) else { return }
    let nextIndex = min(max(currentIndex + offset, 0), cards.count - 1)
    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
      selectedCard = cards[nextIndex]
    }
  }
}

struct TutorialCardView: View {
  let card: TutorialCard

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Image(systemName: card.systemImage)
          .font(.title2.weight(.semibold))
          .foregroundStyle(card.colors[0], card.colors[1])
          .symbolRenderingMode(.palette)
        Spacer()
        Text(card.eyebrow)
          .font(.caption.weight(.bold).monospaced())
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(card.title)
        .font(.title2.weight(.bold))
      Text(card.detail)
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 10)
    }
    .padding(26)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [card.colors[0].opacity(0.55), card.colors[1].opacity(0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    }
  }
}
