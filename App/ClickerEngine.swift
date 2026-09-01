import AppKit
import CoreGraphics
import Foundation

final class ClickerEngine: @unchecked Sendable {
  private let queue = DispatchQueue(
    label: "com.app.clickerEngine",
    qos: .userInteractive
  )

  private var timer: DispatchSourceTimer?
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
      stopLocked(notify: true)
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
    let nanoseconds = max(1, Int(interval * 1_000_000_000))

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

  private func stopLocked(notify: Bool) {
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
    if preset.gamingMacroEnabled {
      macroPhase.toggle()

      switch preset.targetKey {
      case .mouse(let button):
        let firstPosted = postMouse(button)
        let secondButton = macroPhase ? alternateButton(from: button) : button
        return postMouse(secondButton) && firstPosted
      case .character(let value):
        let firstPosted = postKeyboard(character: value)
        let secondPosted = macroPhase ? postKeyboard(command: .enter) : true
        return firstPosted && secondPosted
      case .command(let command):
        let firstPosted = postKeyboard(command: command)
        let secondPosted = macroPhase ? postKeyboard(command: .enter) : true
        return firstPosted && secondPosted
      }
    }

    switch preset.targetKey {
    case .mouse(let button):
      return postMouse(button)
    case .character(let value):
      return postKeyboard(character: value)
    case .command(let command):
      return postKeyboard(command: command)
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
    up.post(tap: .cghidEventTap)
    return true
  }

  private func postKeyboard(command: KeyboardCommand) -> Bool {
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
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    return true
  }

  private func postKeyboard(character: String) -> Bool {
    let characters = Array(character.utf16)
    guard !characters.isEmpty,
          let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
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

    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    return true
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
