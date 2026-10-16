import SwiftUI

struct MainWindowView: View {
  @Bindable var model: AutomationViewModel
  @State private var isShowingSettings = false

  var body: some View {
    HStack(spacing: 0) {
      WorkspaceSidebar(model: model)
        .frame(width: 252)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          WorkspaceHeader(
            presetName: model.presetName,
            statusMessage: model.statusMessage,
            hotKeyDescription: model.hotKeyDescription,
            onSettings: { isShowingSettings = true }
          )

          ActivationCard(
            isRunning: model.isClicking,
            clickCount: model.clickCount,
            cps: model.cps,
            onToggle: model.toggleClicking
          )

          MetricsStrip(
            clickCount: model.clickCount,
            cps: model.cps,
            targetName: model.currentPreset.targetKey.displayName
          )

          TargetControlSection(model: model)

          HStack(alignment: .top, spacing: 18) {
            RateControlSection(model: model)
            SafetyControlSection(model: model)
          }

          WindowLockSection(model: model)

          WorkspaceActionBar(
            isRunning: model.isClicking,
            lastSavedAt: model.lastSavedAt,
            onSave: model.savePreset
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $isShowingSettings) {
      SettingsView(model: model)
    }
  }
}

struct WorkspaceSidebar: View {
  let model: AutomationViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SidebarBrand()

      HStack {
        Text("PRESETS")
          .font(.caption.weight(.bold).monospaced())
          .foregroundStyle(.secondary)
        Spacer()
        Button("New preset", systemImage: "plus") {
          model.createPreset()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Create a new preset")
      }
      .padding(.horizontal, 18)
      .padding(.top, 24)
      .padding(.bottom, 9)

      ScrollView {
        LazyVStack(spacing: 7) {
          ForEach(model.presets) { preset in
            PresetListRow(
              preset: preset,
              isSelected: preset.id == model.selectedPresetID,
              onSelect: { model.selectPreset(preset.id) }
            )
          }
        }
        .padding(.horizontal, 12)
      }

      Spacer(minLength: 16)

      SidebarFooter(
        accessibilityGranted: model.accessibilityGranted,
        onDelete: model.deleteSelectedPreset
      )
    }
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background {
      VisualEffectBlur(
        material: .sidebar,
        blendingMode: .behindWindow,
        state: .active,
        isEmphasized: false
      )
    }
  }
}

struct SidebarBrand: View {
  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: "cursorarrow.click.2")
        .font(.title3.weight(.semibold))
        .foregroundStyle(Color.mint, Color.teal)
        .symbolRenderingMode(.palette)
        .frame(width: 30, height: 30)
        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))

      VStack(alignment: .leading, spacing: 2) {
        Text("MacClicker")
          .font(.headline.weight(.bold))
        Text("Precision workspace")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 24)
  }
}

struct PresetListRow: View {
  let preset: ClickerPreset
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 11) {
        Image(systemName: preset.targetType.systemImage)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
          .frame(width: 28, height: 28)
          .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
          )

        VStack(alignment: .leading, spacing: 3) {
          Text(preset.name)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
          Text("\(preset.cps, specifier: "%.0f") CPS · \(preset.targetKey.displayName)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 9)
      .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      .background(
        isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
      )
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
      }
    }
    .buttonStyle(.plain)
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
  }
}

struct SidebarFooter: View {
  let accessibilityGranted: Bool
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: accessibilityGranted ? "checkmark.shield.fill" : "lock.fill")
          .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
        Text(accessibilityGranted ? "Accessibility ready" : "Accessibility required")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      Button("Delete selected preset", systemImage: "trash", role: .destructive) {
        onDelete()
      }
      .buttonStyle(.borderless)
      .font(.caption)
    }
    .padding(18)
  }
}

struct WorkspaceHeader: View {
  let presetName: String
  let statusMessage: String
  let hotKeyDescription: String
  let onSettings: () -> Void

  var body: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 7) {
        Text("Automation studio")
          .font(.caption.weight(.bold).monospaced())
          .foregroundStyle(.tint)
        Text(presetName)
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .lineLimit(1)
        Text(statusMessage)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 9) {
        Label(hotKeyDescription, systemImage: "keyboard")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 11)
          .padding(.vertical, 8)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay {
            Capsule()
              .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
          }

        Button("Settings", systemImage: "gearshape") {
          onSettings()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.title3)
        .help("Open settings")
      }
    }
  }
}

struct ActivationCard: View {
  let isRunning: Bool
  let clickCount: Int
  let cps: Double
  let onToggle: () -> Void

  @State private var pulse = false

  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 18) {
        ZStack {
          Circle()
            .fill(isRunning ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.14))
            .frame(width: 62, height: 62)
          Image(systemName: isRunning ? "stop.fill" : "play.fill")
            .font(.title2.weight(.bold))
            .foregroundStyle(isRunning ? Color.white : Color.accentColor)
            .offset(x: isRunning ? 0 : 2)
        }

        VStack(alignment: .leading, spacing: 6) {
          Text(isRunning ? "Automation is live" : "Start automation")
            .font(.title3.weight(.bold))
            .foregroundStyle(isRunning ? .white : .primary)
          Text(
            isRunning
              ? "Posting at \(cps.formatted(.number.precision(.fractionLength(0))) ) CPS · \(clickCount.formatted()) events"
              : "Press to run the selected preset"
          )
          .font(.subheadline)
          .foregroundStyle(isRunning ? .white.opacity(0.82) : .secondary)
        }

        Spacer()

        Image(systemName: "arrow.up.right")
          .font(.headline.weight(.semibold))
          .foregroundStyle(isRunning ? .white.opacity(0.86) : .secondary)
      }
      .padding(22)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isRunning
          ? AnyShapeStyle(
            LinearGradient(
              colors: [Color.mint.opacity(0.94), Color.green.opacity(0.82)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          : AnyShapeStyle(.ultraThinMaterial),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(
            isRunning ? Color.white.opacity(0.28) : Color.primary.opacity(0.1),
            lineWidth: 1
          )
      }
    }
    .buttonStyle(.plain)
    .scaleEffect(isRunning ? (pulse ? 1.02 : 1.0) : 1.0)
    .shadow(
      color: isRunning ? Color.green.opacity(0.25) : .clear,
      radius: isRunning ? 22 : 0,
      y: isRunning ? 10 : 0
    )
    .onChange(of: isRunning, initial: true) { _, running in
      if running {
        pulse.toggle()
      } else {
        pulse = false
      }
    }
    .animation(
      isRunning
        ? .easeInOut(duration: 1.25).repeatForever(autoreverses: true)
        : .spring(response: 0.35, dampingFraction: 0.75),
      value: pulse
    )
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isRunning)
  }
}

struct MetricsStrip: View {
  let clickCount: Int
  let cps: Double
  let targetName: String

  var body: some View {
    HStack(spacing: 12) {
      MetricTile(title: "Events", value: clickCount.formatted(), systemImage: "bolt.fill", tint: .yellow)
      MetricTile(
        title: "Rate",
        value: "\(cps.formatted(.number.precision(.fractionLength(0)))) CPS",
        systemImage: "speedometer",
        tint: .blue
      )
      MetricTile(title: "Target", value: targetName, systemImage: "scope", tint: .purple)
    }
  }
}

struct MetricTile: View {
  let title: String
  let value: String
  let systemImage: String
  let tint: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 28, height: 28)
        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(title.uppercased())
          .font(.caption2.weight(.bold).monospaced())
          .foregroundStyle(.secondary)
        Text(value)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 13, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
    }
  }
}

struct TargetControlSection: View {
  @Bindable var model: AutomationViewModel

  var body: some View {
    GlassPanel {
      PanelHeader(
        title: "Target binding",
        subtitle: "Choose exactly what the engine should post.",
        systemImage: "scope",
        colors: [.blue, .cyan]
      )

      Picker("Input type", selection: $model.targetType) {
        ForEach(TargetType.allCases) { type in
          Label(type.title, systemImage: type.systemImage)
            .tag(type)
        }
      }
      .pickerStyle(.segmented)
      .padding(.top, 18)

      if model.targetType == .mouse {
        HStack(spacing: 12) {
          OptionBanner(title: "Mouse button", systemImage: "computermouse.fill", colors: [.orange, .yellow])
          Picker("Mouse button", selection: $model.mouseButton) {
            ForEach(MouseButton.allCases) { button in
              Label(button.title, systemImage: button.systemImage)
                .tag(button)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 170, alignment: .trailing)
        }
        .padding(.top, 16)
      } else {
        Picker("Key source", selection: $model.keyboardInputMode) {
          ForEach(KeyboardInputMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .padding(.top, 16)

        HStack(spacing: 12) {
          OptionBanner(
            title: model.keyboardInputMode == .character ? "Which key to press" : "System key",
            systemImage: "keyboard.fill",
            colors: [.indigo, .purple]
          )

          if model.keyboardInputMode == .character {
            TextField("A", text: $model.customKey)
              .textFieldStyle(.roundedBorder)
              .frame(width: 150)
              .onSubmit {
                model.customKey = String(model.customKey.prefix(1))
              }
          } else {
            Picker("Command key", selection: $model.keyboardCommand) {
              ForEach(KeyboardCommand.allCases) { command in
                Text(command.title).tag(command)
              }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150, alignment: .trailing)
          }
        }
        .padding(.top, 14)

        HStack(spacing: 12) {
          Text("Modifier keys")
            .font(.subheadline.weight(.medium))

          Spacer()

          Menu {
            ForEach(KeyboardModifier.allCases) { modifier in
              Toggle(
                modifier.title,
                isOn: Binding(
                  get: { model.keyboardModifiers.contains(modifier) },
                  set: { model.setKeyboardModifier(modifier, isEnabled: $0) }
                )
              )
            }
          } label: {
            Text(model.keyboardModifierDescription)
              .font(.subheadline.weight(.medium))
              .lineLimit(1)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
              )
              .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
          }
          .menuStyle(.borderlessButton)
          .help("Choose modifier keys to send with the selected key.")
        }
        .padding(.top, 13)
      }

      Toggle(isOn: $model.gamingMacroEnabled) {
        OptionBanner(
          title: "Tactical alternating macro",
          systemImage: "gamecontroller.fill",
          colors: [.green, .teal]
        )
      }
      .toggleStyle(.switch)
      .padding(.top, 18)
      .help("Alternates a secondary tactical pulse or Enter submit event with the bound input.")
    }
  }
}

struct RateControlSection: View {
  @Bindable var model: AutomationViewModel

  var body: some View {
    GlassPanel {
      PanelHeader(
        title: "Rhythm",
        subtitle: "Fast, bounded, and humanized.",
        systemImage: "waveform.path.ecg",
        colors: [.pink, .purple]
      )

      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("Clicks per second")
            .font(.subheadline.weight(.medium))
          Spacer()
          Text("\(model.cps, specifier: "%.0f") CPS")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.tint)
        }

        Slider(value: $model.cps, in: 1...500, step: 1) {
          Text("Clicks per second")
        } minimumValueLabel: {
          Image(systemName: "tortoise.fill")
        } maximumValueLabel: {
          Image(systemName: "hare.fill")
        }
        .tint(Color.accentColor)
      }
      .padding(.top, 18)

      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("Press duration")
            .font(.subheadline.weight(.medium))
          Spacer()
          Text(pressDurationLabel)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.tint)
        }

        Slider(
          value: $model.pressDuration,
          in: ClickerPreset.minimumPressDuration...ClickerPreset.maximumPressDuration
        ) {
          Text("Press duration")
        } minimumValueLabel: {
          Text("1 ms")
        } maximumValueLabel: {
          Text("1 s")
        }
        .help("Longer presses reduce the maximum achievable click rate.")
        .tint(.orange)

        Text("How long each click or key press stays down.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.top, 16)

      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text("Gaussian jitter")
            .font(.subheadline.weight(.medium))
          Spacer()
          Text("\(model.jitterStrength * 100, specifier: "%.0f")%")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.tint)
        }

        Slider(value: $model.jitterStrength, in: 0...1, step: 0.01) {
          Text("Gaussian jitter")
        } minimumValueLabel: {
          Image(systemName: "line.3.horizontal")
        } maximumValueLabel: {
          Image(systemName: "waveform.path.ecg")
        }
        .tint(.pink)
      }
      .padding(.top, 16)
    }
    .frame(maxWidth: .infinity)
  }

  private var pressDurationLabel: String {
    if model.pressDuration >= 1 {
      return "1 s"
    }

    return "\(Int((model.pressDuration * 1_000).rounded())) ms"
  }
}

struct SafetyControlSection: View {
  @Bindable var model: AutomationViewModel

  var body: some View {
    GlassPanel {
      PanelHeader(
        title: "Guardrails",
        subtitle: "Every run has a clean exit.",
        systemImage: "shield.checkered",
        colors: [.orange, .red]
      )

      Stepper(value: $model.maximumClicks, in: 0...1_000_000, step: 100) {
        HStack {
          OptionBanner(title: "Click limit", systemImage: "number", colors: [.orange, .yellow])
          Spacer()
          Text(model.maximumClicks == 0 ? "Unlimited" : model.maximumClicks.formatted())
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      .padding(.top, 15)

      Stepper(value: $model.maximumDurationSeconds, in: 0...86_400, step: 10) {
        HStack {
          OptionBanner(title: "Time limit", systemImage: "timer", colors: [.blue, .indigo])
          Spacer()
          Text(durationLabel)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      .padding(.top, 10)

      Toggle(isOn: $model.stopAtScreenEdge) {
        OptionBanner(title: "Edge panic stop", systemImage: "dot.scope", colors: [.red, .orange])
      }
      .toggleStyle(.switch)
      .padding(.top, 13)
    }
    .frame(maxWidth: .infinity)
  }

  private var durationLabel: String {
    guard model.maximumDurationSeconds > 0 else { return "Unlimited" }
    let seconds = Int(model.maximumDurationSeconds)
    let minutes = seconds / 60
    let remainder = seconds % 60
    if minutes == 0 { return "\(remainder)s" }
    return "\(minutes)m \(remainder)s"
  }
}

struct WindowLockSection: View {
  @Bindable var model: AutomationViewModel

  var body: some View {
    GlassPanel {
      PanelHeader(
        title: "Window lock",
        subtitle: "The engine stops when focus leaves the selected app.",
        systemImage: "macwindow.on.rectangle",
        colors: [.purple, .pink]
      )

      HStack(spacing: 14) {
        OptionBanner(title: "Target window", systemImage: "macwindow", colors: [.purple, .pink])

        Picker("Target window", selection: $model.targetWindowID) {
          Text("Any frontmost app")
            .tag(Optional<String>.none)
          ForEach(model.availableWindows) { window in
            Text(window.displayName)
              .tag(Optional(window.id))
          }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: 270, alignment: .trailing)

        Spacer(minLength: 0)

        Button("Refresh apps", systemImage: "arrow.clockwise") {
          model.refreshAvailableWindows()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Refresh running applications")
      }
      .padding(.top, 18)

      if let selectedTargetWindow = model.selectedTargetWindow {
        Label(selectedTargetWindow.executablePath, systemImage: "folder.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(.top, 10)
      } else {
        Label("No window lock. The preset follows the frontmost app.", systemImage: "lock.open.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 10)
      }
    }
  }
}

struct WorkspaceActionBar: View {
  let isRunning: Bool
  let lastSavedAt: Date?
  let onSave: () -> Void

  var body: some View {
    HStack {
      Label(
        lastSavedAt == nil ? "Profiles are stored locally as JSON" : "Saved locally",
        systemImage: lastSavedAt == nil ? "externaldrive.fill" : "checkmark.circle.fill"
      )
      .font(.caption)
      .foregroundStyle(lastSavedAt == nil ? Color.secondary : Color.green)

      Spacer()

      Button("Save preset", systemImage: "square.and.arrow.down") {
        onSave()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(isRunning)
      .help(isRunning ? "Stop the engine before saving changes" : "Save this preset")
    }
    .padding(.top, 3)
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: lastSavedAt)
  }
}

struct GlassPanel<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
    }
  }
}

struct PanelHeader: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let colors: [Color]

  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: systemImage)
        .font(.headline.weight(.semibold))
        .foregroundStyle(colors[0], colors[1])
        .symbolRenderingMode(.palette)
        .frame(width: 32, height: 32)
        .background(colors[0].opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline.weight(.bold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct OptionBanner: View {
  let title: String
  let systemImage: String
  let colors: [Color]

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.subheadline.weight(.medium))
      .foregroundStyle(.primary)
      .labelStyle(.titleAndIcon)
      .symbolRenderingMode(.palette)
      .foregroundStyle(colors[0], colors[1])
  }
}

struct SettingsView: View {
  @Bindable var model: AutomationViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "gearshape.2.fill")
          .font(.title2.weight(.semibold))
          .foregroundStyle(Color.indigo, Color.purple)
          .symbolRenderingMode(.palette)
          .frame(width: 38, height: 38)
          .background(Color.indigo.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text("Settings")
            .font(.title2.weight(.bold))
          Text("Tune how MacClicker responds to your keyboard.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          GlassPanel {
            VStack(alignment: .leading, spacing: 0) {
              PanelHeader(
                title: "Keyboard shortcuts",
                subtitle: "Record a combination to replace the active shortcut.",
                systemImage: "keyboard.badge.ellipsis",
                colors: [.blue, .cyan]
              )

              SettingsShortcutRow(
                title: "Start / Stop",
                detail: "Toggle the selected automation preset.",
                binding: model.startStopHotKey,
                isRecording: model.recordingTarget == .startStop,
                onRecord: { model.beginRecording(.startStop) },
                onCancel: model.cancelRecording
              )
              .padding(.top, 18)

              SettingsShortcutRow(
                title: "Emergency Stop",
                detail: "Immediately stop the current run.",
                binding: model.emergencyStopHotKey,
                isRecording: model.recordingTarget == .emergencyStop,
                onRecord: { model.beginRecording(.emergencyStop) },
                onCancel: model.cancelRecording
              )
              .padding(.top, 14)

              Label(
                "Use a modifier for a shortcut that will not interfere with normal typing.",
                systemImage: "info.circle"
              )
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.top, 16)
            }
          }

          GlassPanel {
            HStack(spacing: 12) {
              Image(systemName: "arrow.triangle.2.circlepath")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.orange, Color.yellow)
                .symbolRenderingMode(.palette)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

              VStack(alignment: .leading, spacing: 3) {
                Text("Reset shortcuts")
                  .font(.subheadline.weight(.semibold))
                Text("Restore Control + Option + Space and Control + Option + Escape.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Button("Restore defaults", systemImage: "arrow.counterclockwise") {
                model.restoreDefaultHotKeys()
              }
              .buttonStyle(.bordered)
            }
          }
        }
        .padding(.vertical, 24)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      HStack {
        Spacer()
        Button("Done") {
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(28)
    .frame(width: 650, height: 565)
    .background {
      VisualEffectBlur(
        material: .hudWindow,
        blendingMode: .behindWindow,
        state: .active,
        isEmphasized: true
      )
    }
    .onDisappear {
      if model.recordingTarget != nil {
        model.cancelRecording()
      }
    }
  }
}

struct SettingsShortcutRow: View {
  let title: String
  let detail: String
  let binding: HotKeyBinding
  let isRecording: Bool
  let onRecord: () -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Button {
        if isRecording {
          onCancel()
        } else {
          onRecord()
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: isRecording ? "keyboard" : "pencil")
          Text(isRecording ? "Press keys…" : binding.displayName)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
          isRecording ? Color.accentColor.opacity(0.17) : Color.primary.opacity(0.06),
          in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
              isRecording ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.1),
              lineWidth: 1
            )
        }
      }
      .buttonStyle(.plain)
      .help(isRecording ? "Press a key combination to record it" : "Record a new shortcut")
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isRecording)
  }
}
