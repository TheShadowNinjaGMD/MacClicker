import AppKit
import SwiftUI

@main
struct MacClickerApp: App {
  @State private var model: AutomationViewModel

  init() {
    let model = AutomationViewModel()
    _model = State(initialValue: model)
  }

  var body: some Scene {
    WindowGroup(id: "main") {
      AppShellView(model: model)
        .frame(
          minWidth: 980,
          idealWidth: 1_180,
          minHeight: 680,
          idealHeight: 780
        )
        .background {
          VisualEffectBlur(
            material: .hudWindow,
            blendingMode: .behindWindow,
            state: .active,
            isEmphasized: true
          )
          .ignoresSafeArea()
        }
        .onAppear {
          model.startGlobalHotKey()
        }
    }
    .defaultSize(width: 1_180, height: 780)
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unifiedCompact)
    .commands {
      CommandMenu("Presets") {
        Button("Rename Preset", systemImage: "pencil") {
          model.beginRenamingSelectedPreset()
        }
        .keyboardShortcut(.return, modifiers: [])
        .disabled(model.selectedPresetID == nil || model.presetBeingRenamedID != nil)

        Button("Delete Preset", systemImage: "trash", role: .destructive) {
          model.deleteSelectedPreset()
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(model.presets.count <= 1 || model.presetBeingRenamedID != nil)
      }
    }

    MenuBarExtra {
      MenuBarStatusMenu(model: model)
    } label: {
      Label {
        Text(model.isClicking ? "MacClicker is running" : "MacClicker")
      } icon: {
        Image(nsImage: model.appIconImage)
          .resizable()
          .scaledToFit()
          .frame(width: 16, height: 16)
      }
    }
    .menuBarExtraStyle(.menu)
  }
}

struct AppShellView: View {
  let model: AutomationViewModel
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

  var body: some View {
    ZStack {
      VisualEffectBlur(
        material: .hudWindow,
        blendingMode: .behindWindow,
        state: .active,
        isEmphasized: true
      )
      .ignoresSafeArea()

      if hasCompletedOnboarding {
        MainWindowView(model: model)
      } else {
        OnboardingView(model: model)
      }

      MainWindowLifecycleBridge()
        .frame(width: 1, height: 1)
        .opacity(0)
        .allowsHitTesting(false)
    }
    .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
  }
}

struct MainWindowLifecycleBridge: NSViewRepresentable {
  func makeCoordinator() -> MenuBarWindowDelegate {
    MenuBarWindowDelegate()
  }

  func makeNSView(context: Context) -> NSView {
    NSView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard let window = nsView.window, window.delegate !== context.coordinator else { return }
    window.delegate = context.coordinator
  }
}

final class MenuBarWindowDelegate: NSObject, NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    NSApplication.shared.setActivationPolicy(.accessory)
    return false
  }
}

struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode
  var state: NSVisualEffectView.State
  var isEmphasized: Bool

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = state
    view.isEmphasized = isEmphasized
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = state
    nsView.isEmphasized = isEmphasized
  }
}

struct MenuBarStatusMenu: View {
  let model: AutomationViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Circle()
          .fill(model.isClicking ? Color.green : Color.secondary)
          .frame(width: 8, height: 8)
        Text(model.isClicking ? "Automation active" : "Automation ready")
          .font(.headline)
      }

      Label("Shortcut: \(model.hotKeyDescription)", systemImage: "keyboard")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button(
        model.isClicking ? "Stop clicking" : "Start clicking",
        systemImage: model.isClicking ? "stop.fill" : "play.fill"
      ) {
        model.toggleClicking()
      }
      .disabled(!model.isClicking && !model.accessibilityGranted)

      Button("Open MacClicker", systemImage: "macwindow") {
        model.showMainWindow()
      }

      Divider()

      Button("Quit MacClicker", systemImage: "power") {
        NSApplication.shared.terminate(nil)
      }
    }
    .padding(12)
  }
}
