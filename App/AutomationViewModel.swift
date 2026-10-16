import AppKit
import ApplicationServices
import Foundation
import Observation

struct HotKeyBinding: Codable, Equatable, Sendable {
  var keyCode: UInt16
  var keyLabel: String
  var modifierRawValue: UInt

  var modifierFlags: NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(rawValue: modifierRawValue)
  }

  var displayName: String {
    var pieces: [String] = []
    let flags = modifierFlags

    if flags.contains(.control) { pieces.append("Control") }
    if flags.contains(.option) { pieces.append("Option") }
    if flags.contains(.shift) { pieces.append("Shift") }
    if flags.contains(.command) { pieces.append("Command") }
    if flags.contains(.capsLock) { pieces.append("Caps Lock") }

    pieces.append(keyLabel.isEmpty ? "Key \(keyCode)" : keyLabel)
    return pieces.joined(separator: " + ")
  }

  static let defaultStartStop = HotKeyBinding(
    keyCode: 49,
    keyLabel: "Space",
    modifierRawValue: NSEvent.ModifierFlags.control.rawValue
      | NSEvent.ModifierFlags.option.rawValue
  )

  static let defaultEmergencyStop = HotKeyBinding(
    keyCode: 53,
    keyLabel: "Escape",
    modifierRawValue: NSEvent.ModifierFlags.control.rawValue
      | NSEvent.ModifierFlags.option.rawValue
  )

  init(keyCode: UInt16, keyLabel: String, modifierRawValue: UInt) {
    self.keyCode = keyCode
    self.keyLabel = keyLabel
    self.modifierRawValue = modifierRawValue
  }

  init?(event: NSEvent) {
    self.init(
      keyCode: event.keyCode,
      keyLabel: Self.keyLabel(for: event),
      modifierRawValue: event.modifierFlags
        .intersection(.deviceIndependentFlagsMask)
        .rawValue
    )
  }

  func matches(_ event: NSEvent) -> Bool {
    event.keyCode == keyCode
      && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifierFlags
  }

  private static func keyLabel(for event: NSEvent) -> String {
    switch event.keyCode {
    case 36:
      return "Enter"
    case 48:
      return "Tab"
    case 49:
      return "Space"
    case 51:
      return "Delete"
    case 53:
      return "Escape"
    case 122:
      return "F1"
    case 120:
      return "F2"
    case 99:
      return "F3"
    case 118:
      return "F4"
    case 96:
      return "F5"
    case 97:
      return "F6"
    case 98:
      return "F7"
    case 100:
      return "F8"
    case 101:
      return "F9"
    case 109:
      return "F10"
    case 103:
      return "F11"
    case 111:
      return "F12"
    default:
      let characters = event.charactersIgnoringModifiers?.uppercased() ?? ""
      return characters.isEmpty ? "Key \(event.keyCode)" : characters
    }
  }
}

struct HotKeyPreferences: Codable, Equatable, Sendable {
  var startStop: HotKeyBinding
  var emergencyStop: HotKeyBinding
}

enum HotKeyTarget: String, Equatable, Identifiable, Sendable {
  case startStop
  case emergencyStop

  var id: String { rawValue }
}

@MainActor
@Observable
final class AutomationViewModel {
  var isClicking = false
  var clickCount = 0
  var selectedPresetID: UUID?
  var presets: [ClickerPreset] = []
  var availableWindows: [TargetWindow] = []
  var startStopHotKey = HotKeyBinding.defaultStartStop
  var emergencyStopHotKey = HotKeyBinding.defaultEmergencyStop
  var recordingTarget: HotKeyTarget?

  var presetName = "Balanced Tap"
  var targetType: TargetType = .mouse
  var mouseButton: MouseButton = .left
  var keyboardInputMode: KeyboardInputMode = .command
  var keyboardCommand: KeyboardCommand = .space
  var keyboardModifiers: Set<KeyboardModifier> = []
  var customKey = "F"
  var targetWindowID: String? {
    didSet {
      guard let targetWindowID else {
        selectedTargetWindow = nil
        return
      }

      selectedTargetWindow = availableWindows.first(where: { $0.id == targetWindowID })
        ?? (selectedTargetWindow?.id == targetWindowID ? selectedTargetWindow : nil)
    }
  }
  var cps = 12.0
  var jitterStrength = 0.18
  var pressDuration = ClickerPreset.defaultPressDuration
  var maximumClicks = 0
  var maximumDurationSeconds = 0.0
  var stopAtScreenEdge = true
  var gamingMacroEnabled = false
  var jitterSamples: [Double] = []
  var lastSavedAt: Date?
  var statusMessage = "Ready when you are"

  var accessibilityGranted: Bool {
    AXIsProcessTrusted()
  }

  var hotKeyDescription: String {
    startStopHotKey.displayName
  }

  var emergencyHotKeyDescription: String {
    emergencyStopHotKey.displayName
  }

  var keyboardModifierDescription: String {
    let selectedModifiers = KeyboardModifier.allCases
      .filter(keyboardModifiers.contains)
      .map(\.title)
    return selectedModifiers.isEmpty ? "None" : selectedModifiers.joined(separator: " + ")
  }

  var selectedTargetWindow: TargetWindow?

  @ObservationIgnored private let engine: ClickerEngine
  @ObservationIgnored private var globalHotKeyMonitor: Any?
  @ObservationIgnored private var localHotKeyMonitor: Any?
  @ObservationIgnored private var shortcutCaptureMonitor: Any?
  @ObservationIgnored private var windowPollingTimer: Timer?
  @ObservationIgnored private var engineRunToken = UUID()
  @ObservationIgnored private var draftID = UUID()

  private let defaults = UserDefaults.standard
  private let presetsKey = "com.app.macClicker.presets"
  private let selectedPresetKey = "com.app.macClicker.selectedPreset"
  private let hotKeysKey = "com.app.macClicker.hotKeys"

  init() {
    engine = ClickerEngine()
    loadHotKeys()
    loadPresets()
    refreshAvailableWindows()

    if let storedPresetID = selectedPresetID,
       let preset = presets.first(where: { $0.id == storedPresetID }) {
      apply(preset)
    } else if let firstPreset = presets.first {
      selectedPresetID = firstPreset.id
      draftID = firstPreset.id
      apply(firstPreset)
    }

    startWindowTracking()
  }

  var currentPreset: ClickerPreset {
    ClickerPreset(
      id: selectedPresetID ?? draftID,
      name: normalizedPresetName,
      targetType: targetType,
      targetKey: targetKey,
      targetWindow: selectedTargetWindow,
      cps: min(max(cps, 1), 500),
      jitterStrength: min(max(jitterStrength, 0), 1),
      limits: ClickerLimits(
        maximumClicks: maximumClicks > 0 ? maximumClicks : nil,
        maximumDuration: maximumDurationSeconds > 0 ? maximumDurationSeconds : nil,
        stopAtScreenEdge: stopAtScreenEdge
      ),
      jitterSamples: jitterSamples,
      gamingMacroEnabled: gamingMacroEnabled,
      pressDuration: min(
        max(pressDuration, ClickerPreset.minimumPressDuration),
        ClickerPreset.maximumPressDuration
      )
    )
  }

  func startGlobalHotKey() {
    guard globalHotKeyMonitor == nil, localHotKeyMonitor == nil else { return }

    let startStopHotKey = startStopHotKey
    let emergencyStopHotKey = emergencyStopHotKey

    localHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if startStopHotKey.matches(event) {
        Task { @MainActor [weak self] in
          self?.toggleClicking()
        }
        return nil
      }

      if emergencyStopHotKey.matches(event) {
        Task { @MainActor [weak self] in
          self?.stopClicking()
        }
        return nil
      }

      return event
    }

    globalHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if startStopHotKey.matches(event) {
        Task { @MainActor [weak self] in
          self?.toggleClicking()
        }
      } else if emergencyStopHotKey.matches(event) {
        Task { @MainActor [weak self] in
          self?.stopClicking()
        }
      }
    }
  }

  func beginRecording(_ target: HotKeyTarget) {
    stopGlobalHotKey()
    removeShortcutCaptureMonitor()
    recordingTarget = target

    shortcutCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let binding = HotKeyBinding(event: event) else { return event }

      Task { @MainActor [weak self] in
        self?.finishRecording(binding)
      }
      return nil
    }
  }

  func cancelRecording() {
    removeShortcutCaptureMonitor()
    recordingTarget = nil
    startGlobalHotKey()
  }

  func restoreDefaultHotKeys() {
    cancelRecording()
    startStopHotKey = .defaultStartStop
    emergencyStopHotKey = .defaultEmergencyStop
    persistHotKeys()
    stopGlobalHotKey()
    startGlobalHotKey()
    statusMessage = "Restored default shortcuts"
  }

  func toggleClicking() {
    if isClicking {
      stopClicking()
    } else {
      startClicking()
    }
  }

  func setKeyboardModifier(_ modifier: KeyboardModifier, isEnabled: Bool) {
    if isEnabled {
      keyboardModifiers.insert(modifier)
    } else {
      keyboardModifiers.remove(modifier)
    }
  }

  func startClicking() {
    guard !isClicking else { return }
    guard defaults.bool(forKey: "hasCompletedOnboarding") else {
      statusMessage = "Finish onboarding first"
      return
    }
    guard AXIsProcessTrusted() else {
      statusMessage = "Accessibility access is required"
      return
    }

    let preset = currentPreset
    let runToken = UUID()
    engineRunToken = runToken
    clickCount = 0
    statusMessage = "Running \(preset.name)"
    isClicking = true

    engine.start(
      preset: preset,
      onClick: { [weak self] count in
        Task { @MainActor [weak self] in
          guard let self, self.engineRunToken == runToken else { return }
          self.clickCount = count
        }
      },
      onStop: { [weak self] in
        Task { @MainActor [weak self] in
          guard let self, self.engineRunToken == runToken else { return }
          self.isClicking = false
          self.statusMessage = self.clickCount > 0 ? "Stopped safely" : "Ready when you are"
        }
      }
    )
  }

  func stopClicking() {
    engineRunToken = UUID()
    engine.stop()
    isClicking = false
    statusMessage = clickCount > 0 ? "Stopped safely" : "Ready when you are"
  }

  func selectPreset(_ id: UUID) {
    guard let preset = presets.first(where: { $0.id == id }) else { return }
    if isClicking { stopClicking() }

    selectedPresetID = id
    draftID = id
    apply(preset)
    defaults.set(id.uuidString, forKey: selectedPresetKey)
    statusMessage = "Loaded \(preset.name)"
  }

  func createPreset() {
    if isClicking { stopClicking() }

    selectedPresetID = nil
    draftID = UUID()
    presetName = "Untitled Preset"
    targetType = .mouse
    mouseButton = .left
    keyboardInputMode = .command
    keyboardCommand = .space
    keyboardModifiers = []
    customKey = "F"
    targetWindowID = nil
    selectedTargetWindow = nil
    cps = 12
    jitterStrength = 0.18
    pressDuration = ClickerPreset.defaultPressDuration
    maximumClicks = 0
    maximumDurationSeconds = 0
    stopAtScreenEdge = true
    gamingMacroEnabled = false
    jitterSamples = []
    statusMessage = "New preset ready"
  }

  func savePreset() {
    var preset = currentPreset
    if preset.jitterSamples.isEmpty {
      preset.jitterSamples = makeJitterProfile()
      jitterSamples = preset.jitterSamples
    }

    if let index = presets.firstIndex(where: { $0.id == preset.id }) {
      presets[index] = preset
    } else {
      presets.append(preset)
    }

    selectedPresetID = preset.id
    draftID = preset.id
    persistPresets()
    defaults.set(preset.id.uuidString, forKey: selectedPresetKey)
    lastSavedAt = Date()
    statusMessage = "Saved \(preset.name) locally"
  }

  func deleteSelectedPreset() {
    guard let selectedID = selectedPresetID,
          presets.count > 1,
          let index = presets.firstIndex(where: { $0.id == selectedID })
    else {
      return
    }

    if isClicking { stopClicking() }
    presets.remove(at: index)
    persistPresets()

    let replacement = presets[min(index, presets.count - 1)]
    selectedPresetID = replacement.id
    draftID = replacement.id
    apply(replacement)
    defaults.set(replacement.id.uuidString, forKey: selectedPresetKey)
    statusMessage = "Removed preset"
  }

  func refreshAvailableWindows() {
    let runningApps = NSWorkspace.shared.runningApplications
      .filter { !$0.isTerminated && $0.activationPolicy == .regular }

    availableWindows = runningApps.compactMap { application in
      guard let bundleIdentifier = application.bundleIdentifier,
            let executablePath = application.executableURL?.path
      else {
        return nil
      }

      return TargetWindow(
        appName: application.localizedName ?? bundleIdentifier,
        bundleIdentifier: bundleIdentifier,
        executablePath: executablePath
      )
    }
    .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

    if let targetWindowID,
       let runningTarget = availableWindows.first(where: { $0.id == targetWindowID }) {
      selectedTargetWindow = runningTarget
    }
  }

  func showMainWindow() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    let window = NSApplication.shared.windows.first(where: { $0.canBecomeKey })
    window?.makeKeyAndOrderFront(nil)
  }

  func completeOnboarding() {
    defaults.set(true, forKey: "hasCompletedOnboarding")
  }

  private var normalizedPresetName: String {
    let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled Preset" : String(trimmed.prefix(60))
  }

  private var targetKey: TargetKey {
    switch targetType {
    case .mouse:
      return .mouse(mouseButton)
    case .keyboard:
      switch keyboardInputMode {
      case .character:
        let value = String(customKey.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
        let key = AutomationKey.character(value.isEmpty ? "F" : value)
        return keyboardModifiers.isEmpty
          ? .character(value.isEmpty ? "F" : value)
          : .combination(KeyboardChord(key: key, modifiers: Array(keyboardModifiers)))
      case .command:
        return keyboardModifiers.isEmpty
          ? .command(keyboardCommand)
          : .combination(
            KeyboardChord(key: .system(keyboardCommand), modifiers: Array(keyboardModifiers))
          )
      }
    }
  }

  private func loadPresets() {
    if let data = defaults.data(forKey: presetsKey),
       let decoded = try? JSONDecoder().decode([ClickerPreset].self, from: data),
       !decoded.isEmpty {
      presets = decoded
    } else {
      presets = [.balancedDefault]
    }

    if let storedID = defaults.string(forKey: selectedPresetKey),
       let id = UUID(uuidString: storedID),
       presets.contains(where: { $0.id == id }) {
      selectedPresetID = id
    }
  }

  private func loadHotKeys() {
    guard let data = defaults.data(forKey: hotKeysKey),
          let preferences = try? JSONDecoder().decode(HotKeyPreferences.self, from: data)
    else {
      return
    }

    startStopHotKey = preferences.startStop
    emergencyStopHotKey = preferences.emergencyStop
  }

  private func persistHotKeys() {
    let preferences = HotKeyPreferences(
      startStop: startStopHotKey,
      emergencyStop: emergencyStopHotKey
    )
    guard let data = try? JSONEncoder().encode(preferences) else { return }
    defaults.set(data, forKey: hotKeysKey)
  }

  private func finishRecording(_ binding: HotKeyBinding) {
    guard let target = recordingTarget else { return }
    removeShortcutCaptureMonitor()
    recordingTarget = nil

    if target == .startStop {
      guard binding != emergencyStopHotKey else {
        statusMessage = "Choose a different shortcut for Start / Stop"
        startGlobalHotKey()
        return
      }
      startStopHotKey = binding
      statusMessage = "Updated Start / Stop shortcut"
    } else {
      guard binding != startStopHotKey else {
        statusMessage = "Choose a different shortcut for Emergency Stop"
        startGlobalHotKey()
        return
      }
      emergencyStopHotKey = binding
      statusMessage = "Updated Emergency Stop shortcut"
    }

    persistHotKeys()
    startGlobalHotKey()
  }

  private func stopGlobalHotKey() {
    if let globalHotKeyMonitor {
      NSEvent.removeMonitor(globalHotKeyMonitor)
      self.globalHotKeyMonitor = nil
    }
    if let localHotKeyMonitor {
      NSEvent.removeMonitor(localHotKeyMonitor)
      self.localHotKeyMonitor = nil
    }
  }

  private func removeShortcutCaptureMonitor() {
    if let shortcutCaptureMonitor {
      NSEvent.removeMonitor(shortcutCaptureMonitor)
      self.shortcutCaptureMonitor = nil
    }
  }

  private func persistPresets() {
    guard let data = try? JSONEncoder().encode(presets) else { return }
    defaults.set(data, forKey: presetsKey)
  }

  private func apply(_ preset: ClickerPreset) {
    presetName = preset.name
    targetType = preset.targetType
    targetWindowID = preset.targetWindow?.id
    selectedTargetWindow = preset.targetWindow
    cps = preset.cps
    jitterStrength = preset.jitterStrength
    pressDuration = preset.pressDuration
    maximumClicks = preset.limits.maximumClicks ?? 0
    maximumDurationSeconds = preset.limits.maximumDuration ?? 0
    stopAtScreenEdge = preset.limits.stopAtScreenEdge
    gamingMacroEnabled = preset.gamingMacroEnabled
    jitterSamples = preset.jitterSamples

    switch preset.targetKey {
    case .mouse(let button):
      mouseButton = button
      keyboardInputMode = .command
      keyboardModifiers = []
    case .character(let value):
      keyboardInputMode = .character
      customKey = value
      keyboardModifiers = []
    case .command(let command):
      keyboardInputMode = .command
      keyboardCommand = command
      keyboardModifiers = []
    case .combination(let chord):
      keyboardModifiers = Set(chord.modifiers)
      switch chord.key {
      case .character(let value):
        keyboardInputMode = .character
        customKey = value
      case .system(let command):
        keyboardInputMode = .command
        keyboardCommand = command
      }
    }
  }

  private func makeJitterProfile() -> [Double] {
    (0..<64).map { _ in
      let first = max(Double.leastNonzeroMagnitude, Double.random(in: 0..<1))
      let second = Double.random(in: 0..<1)
      let gaussian = sqrt(-2 * log(first)) * cos(2 * .pi * second)
      return min(max(gaussian, -2.5), 2.5)
    }
  }

  private func startWindowTracking() {
    windowPollingTimer?.invalidate()
    windowPollingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.refreshAvailableWindows()
      }
    }
  }

}
