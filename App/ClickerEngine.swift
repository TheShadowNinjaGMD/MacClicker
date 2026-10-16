import AppKit
import CoreGraphics
import Foundation

final class ClickerEngine: @unchecked Sendable {
  private let queue = DispatchQueue(
    label: "com.app.clickerEngine",
    qos: .userInteractive
  )
  private static let characterVirtualKeyCodes: [String: UInt16] = [
    "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7,
    "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16,
    "T": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
    "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30,
    "O": 31, "U": 32, "[": 33, "I": 34, "P": 35, "L": 37, "J": 38,
    "'": 39, "K": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "N": 45,
    "M": 46, ".": 47, "`": 50
  ]

  private var timer: DispatchSourceTimer?
  private var releaseTimer: DispatchSourceTimer?
  private var pendingReleaseEvents: [CGEvent] = []
  private var pendingSecondaryTarget: TargetKey?
  private var pendingPressDuration = ClickerPreset.defaultPressDuration
  private var preset: ClickerPreset?
  private var clickCount = 0
  private var startedAt: Date?
  private var isRunning = false
  private var jitterIndex = 0
  private var macroPhase = false
  private var clickHandler: (@Sendable (Int) -> Void)?
  private var stopHandler: (@Sendable () -> Void)?

  func start(
    preset: ClickerPreset,
    onClick: @escaping @Sendable (Int) -> Void,
    onStop: @escaping @Sendable () -> Void
  ) {
    queue.async { [weak self] in
      guard let self else { return }

      self.stopLocked(notify: false)
      self.preset = preset
      self.clickHandler = onClick
      self.stopHandler = onStop
      self.clickCount = 0
      self.startedAt = Date()
      self.jitterIndex = 0
      self.macroPhase = false
      self.isRunning = true

      let source = DispatchSource.makeTimerSource(queue: self.queue)
      source.setEventHandler { [weak self] in
        self?.fireLocked()
      }
      self.timer = source
      source.schedule(
        deadline: .now(),
        repeating: .never,
        leeway: .microseconds(200)
      )
      source.resume()
    }
  }

  func stop() {
    queue.async { [weak self] in
      self?.stopLocked(notify: true)
    }
  }

  func stopAndWait() {
    queue.sync {
      stopLocked(notify: false)
    }
  }

  private func fireLocked() {
    guard isRunning, let preset else { return }

    if reachedLimit(for: preset) || !isTargetApplicationFrontmost(for: preset) {
      stopLocked(notify: true)
      return
    }

    if preset.limits.stopAtScreenEdge && isPointerAtScreenEdge() {
      stopLocked(notify: true)
      return
    }

    if postInput(for: preset) {
      clickCount += 1
      clickHandler?(clickCount)
    }

    if reachedLimit(for: preset) {
      stopLocked(notify: true, releaseInputImmediately: false)
    } else {
      scheduleNextLocked(for: preset)
    }
  }

  private func scheduleNextLocked(for preset: ClickerPreset) {
    guard let timer, isRunning else { return }

    let cappedCPS = min(max(preset.cps, 1), 500)
    let baseInterval = 1.0 / cappedCPS
    let gaussianSample = nextJitterSample(for: preset)
    let jitter = gaussianSample * preset.jitterStrength * 0.35
    let interval = max(0.002, baseInterval * (1 + jitter))
    let pressDuration = min(
      max(preset.pressDuration, ClickerPreset.minimumPressDuration),
      ClickerPreset.maximumPressDuration
    )
    let pressMultiplier = pendingSecondaryTarget == nil ? 1.0 : 2.0
    let nextInterval = max(interval, pressDuration * pressMultiplier + 0.001)
    let nanoseconds = max(1, Int(nextInterval * 1_000_000_000))

    timer.schedule(
      deadline: .now() + .nanoseconds(nanoseconds),
      repeating: .never,
      leeway: .microseconds(200)
    )
  }

  private func nextJitterSample(for preset: ClickerPreset) -> Double {
    if !preset.jitterSamples.isEmpty {
      let sample = preset.jitterSamples[jitterIndex % preset.jitterSamples.count]
      jitterIndex += 1
      return sample
    }

    let first = max(Double.leastNonzeroMagnitude, Double.random(in: 0..<1))
    let second = Double.random(in: 0..<1)
    return sqrt(-2 * log(first)) * cos(2 * .pi * second)
  }

  private func reachedLimit(for preset: ClickerPreset) -> Bool {
    if let maximumClicks = preset.limits.maximumClicks, clickCount >= maximumClicks {
      return true
    }

    if let maximumDuration = preset.limits.maximumDuration,
       let startedAt,
       Date().timeIntervalSince(startedAt) >= maximumDuration {
      return true
    }

    return false
  }

  private func stopLocked(notify: Bool, releaseInputImmediately: Bool = true) {
    if releaseInputImmediately {
      releasePendingInputLocked()
    }

    let wasRunning = isRunning
    isRunning = false
    timer?.setEventHandler {}
    timer?.cancel()
    timer = nil
    preset = nil
    startedAt = nil

    if notify && wasRunning {
      stopHandler?()
    }
  }

  private func postInput(for preset: ClickerPreset) -> Bool {
    releasePendingInputLocked()
    pendingSecondaryTarget = nil
    pendingPressDuration = min(
      max(preset.pressDuration, ClickerPreset.minimumPressDuration),
      ClickerPreset.maximumPressDuration
    )
    let firstPosted = postTargetKey(preset.targetKey)

    guard preset.gamingMacroEnabled else {
      scheduleInputReleaseLocked(after: pendingPressDuration)
      return firstPosted
    }

    macroPhase.toggle()

    switch preset.targetKey {
    case .mouse(let button):
      let secondButton = macroPhase ? alternateButton(from: button) : button
      pendingSecondaryTarget = .mouse(secondButton)
    case .character, .command, .combination:
      if macroPhase {
        pendingSecondaryTarget = .command(.enter)
      }
    }

    scheduleInputReleaseLocked(after: pendingPressDuration)
    return firstPosted
  }

  private func postTargetKey(_ targetKey: TargetKey) -> Bool {
    switch targetKey {
    case .mouse(let button):
      return postMouse(button)
    case .character(let value):
      return postKeyboard(character: value)
    case .command(let command):
      return postKeyboard(command: command)
    case .combination(let chord):
      switch chord.key {
      case .character(let value):
        return postKeyboard(character: value, modifiers: chord.modifiers)
      case .system(let command):
        return postKeyboard(command: command, modifiers: chord.modifiers)
      }
    }
  }

  private func postMouse(_ button: MouseButton) -> Bool {
    let location = CGEvent(source: nil)?.location ?? .zero
    let down = CGEvent(
      mouseEventSource: nil,
      mouseType: button.downEvent,
      mouseCursorPosition: location,
      mouseButton: button.cgButton
    )
    let up = CGEvent(
      mouseEventSource: nil,
      mouseType: button.upEvent,
      mouseCursorPosition: location,
      mouseButton: button.cgButton
    )

    guard let down, let up else { return false }
    down.post(tap: .cghidEventTap)
    pendingReleaseEvents.append(up)
    return true
  }

  private func postKeyboard(
    command: KeyboardCommand,
    modifiers: [KeyboardModifier] = []
  ) -> Bool {
    let down = CGEvent(
      keyboardEventSource: nil,
      virtualKey: CGKeyCode(command.keyCode),
      keyDown: true
    )
    let up = CGEvent(
      keyboardEventSource: nil,
      virtualKey: CGKeyCode(command.keyCode),
      keyDown: false
    )

    guard let down, let up else { return false }
    let flags = eventFlags(for: modifiers)
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    pendingReleaseEvents.append(up)
    return true
  }

  private func postKeyboard(
    character: String,
    modifiers: [KeyboardModifier] = []
  ) -> Bool {
    let characters = Array(character.utf16)
    let virtualKeyCode = modifiers.isEmpty
      ? 0
      : Self.characterVirtualKeyCodes[character.uppercased()] ?? 0
    guard !characters.isEmpty,
          let down = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(virtualKeyCode),
            keyDown: true
          ),
          let up = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(virtualKeyCode),
            keyDown: false
          )
    else {
      return false
    }

    characters.withUnsafeBufferPointer { buffer in
      down.keyboardSetUnicodeString(
        stringLength: buffer.count,
        unicodeString: buffer.baseAddress
      )
      up.keyboardSetUnicodeString(
        stringLength: buffer.count,
        unicodeString: buffer.baseAddress
      )
    }

    let flags = eventFlags(for: modifiers)
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    pendingReleaseEvents.append(up)
    return true
  }

  private func eventFlags(for modifiers: [KeyboardModifier]) -> CGEventFlags {
    modifiers.reduce(into: CGEventFlags(rawValue: 0)) { flags, modifier in
      switch modifier {
      case .control:
        flags.insert(.maskControl)
      case .option:
        flags.insert(.maskAlternate)
      case .shift:
        flags.insert(.maskShift)
      case .command:
        flags.insert(.maskCommand)
      case .function:
        flags.insert(.maskSecondaryFn)
      case .capsLock:
        flags.insert(.maskAlphaShift)
      }
    }
  }

  private func scheduleInputReleaseLocked(after duration: TimeInterval) {
    guard !pendingReleaseEvents.isEmpty else { return }

    let boundedDuration = min(
      max(duration, ClickerPreset.minimumPressDuration),
      ClickerPreset.maximumPressDuration
    )
    let nanoseconds = max(1, Int(boundedDuration * 1_000_000_000))
    let releaseTimer: DispatchSourceTimer

    if let existingTimer = self.releaseTimer {
      releaseTimer = existingTimer
    } else {
      releaseTimer = DispatchSource.makeTimerSource(queue: queue)
      releaseTimer.setEventHandler { [weak self] in
        self?.releasePendingInputLocked(continueWithSecondary: true)
      }
      self.releaseTimer = releaseTimer
      releaseTimer.resume()
    }

    releaseTimer.schedule(
      deadline: .now() + .nanoseconds(nanoseconds),
      repeating: .never,
      leeway: .microseconds(100)
    )
  }

  private func releasePendingInputLocked(continueWithSecondary: Bool = false) {
    let secondaryTarget = continueWithSecondary ? pendingSecondaryTarget : nil
    pendingSecondaryTarget = nil

    if let releaseTimer {
      releaseTimer.setEventHandler {}
      releaseTimer.cancel()
      self.releaseTimer = nil
    }

    let releaseEvents = pendingReleaseEvents
    pendingReleaseEvents.removeAll(keepingCapacity: true)
    for event in releaseEvents {
      event.post(tap: .cghidEventTap)
    }

    if let secondaryTarget, postTargetKey(secondaryTarget) {
      scheduleInputReleaseLocked(after: pendingPressDuration)
    }
  }

  private func isPointerAtScreenEdge() -> Bool {
    guard let location = CGEvent(source: nil)?.location else { return false }
    let bounds = CGDisplayBounds(CGMainDisplayID())
    let margin: CGFloat = 4

    return location.x <= bounds.minX + margin
      || location.x >= bounds.maxX - margin
      || location.y <= bounds.minY + margin
      || location.y >= bounds.maxY - margin
  }

  private func isTargetApplicationFrontmost(for preset: ClickerPreset) -> Bool {
    guard let targetWindow = preset.targetWindow else { return true }
    guard let windowInfo = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]],
    let topWindow = windowInfo.first,
    let ownerName = topWindow[kCGWindowOwnerName as String] as? String
    else {
      return true
    }

    return ownerName == targetWindow.appName
  }

  private func alternateButton(from button: MouseButton) -> MouseButton {
    switch button {
    case .left:
      return .right
    case .right, .middle:
      return .left
    }
  }
}

private extension MouseButton {
  var cgButton: CGMouseButton {
    switch self {
    case .left:
      return .left
    case .right:
      return .right
    case .middle:
      return .center
    }
  }

  var downEvent: CGEventType {
    switch self {
    case .left:
      return .leftMouseDown
    case .right:
      return .rightMouseDown
    case .middle:
      return .otherMouseDown
    }
  }

  var upEvent: CGEventType {
    switch self {
    case .left:
      return .leftMouseUp
    case .right:
      return .rightMouseUp
    case .middle:
      return .otherMouseUp
    }
  }
}
