import Foundation

enum TargetType: String, Codable, CaseIterable, Identifiable, Sendable {
  case mouse
  case keyboard

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mouse:
      return "Mouse"
    case .keyboard:
      return "Keyboard"
    }
  }

  var systemImage: String {
    switch self {
    case .mouse:
      return "computermouse.fill"
    case .keyboard:
      return "keyboard.fill"
    }
  }
}

enum MouseButton: String, Codable, CaseIterable, Identifiable, Sendable {
  case left
  case right
  case middle

  var id: String { rawValue }

  var title: String {
    switch self {
    case .left:
      return "Left"
    case .right:
      return "Right"
    case .middle:
      return "Middle"
    }
  }

  var systemImage: String {
    switch self {
    case .left:
      return "cursorarrow.click.2"
    case .right:
      return "cursorarrow.click.2"
    case .middle:
      return "circle.grid.2x2.fill"
    }
  }
}

enum KeyboardInputMode: String, Codable, CaseIterable, Identifiable, Sendable {
  case character
  case command

  var id: String { rawValue }

  var title: String {
    switch self {
    case .character:
      return "Custom key"
    case .command:
      return "System key"
    }
  }
}

enum KeyboardCommand: String, Codable, CaseIterable, Identifiable, Sendable {
  case space
  case enter
  case escape
  case tab
  case delete
  case f1
  case f2
  case f3
  case f4
  case f5
  case f6
  case f7
  case f8
  case f9
  case f10
  case f11
  case f12

  var id: String { rawValue }

  var title: String {
    switch self {
    case .space:
      return "Spacebar"
    case .enter:
      return "Enter"
    case .escape:
      return "Escape"
    case .tab:
      return "Tab"
    case .delete:
      return "Delete"
    case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12:
      return rawValue.uppercased()
    }
  }

  var keyCode: UInt16 {
    switch self {
    case .space:
      return 49
    case .enter:
      return 36
    case .escape:
      return 53
    case .tab:
      return 48
    case .delete:
      return 51
    case .f1:
      return 122
    case .f2:
      return 120
    case .f3:
      return 99
    case .f4:
      return 118
    case .f5:
      return 96
    case .f6:
      return 97
    case .f7:
      return 98
    case .f8:
      return 100
    case .f9:
      return 101
    case .f10:
      return 109
    case .f11:
      return 103
    case .f12:
      return 111
    }
  }
}

enum TargetKey: Codable, Equatable, Hashable, Sendable {
  case character(String)
  case command(KeyboardCommand)
  case mouse(MouseButton)

  var displayName: String {
    switch self {
    case .character(let value):
      return value.isEmpty ? "Custom key" : value
    case .command(let command):
      return command.title
    case .mouse(let button):
      return "\(button.title) click"
    }
  }

  private enum CodingKeys: String, CodingKey {
    case kind
    case value
  }

  private enum Kind: String, Codable {
    case character
    case command
    case mouse
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)

    switch kind {
    case .character:
      self = .character(try container.decode(String.self, forKey: .value))
    case .command:
      self = .command(try container.decode(KeyboardCommand.self, forKey: .value))
    case .mouse:
      self = .mouse(try container.decode(MouseButton.self, forKey: .value))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .character(let value):
      try container.encode(Kind.character, forKey: .kind)
      try container.encode(value, forKey: .value)
    case .command(let command):
      try container.encode(Kind.command, forKey: .kind)
      try container.encode(command, forKey: .value)
    case .mouse:
      try container.encode(Kind.mouse, forKey: .kind)
      if case .mouse(let button) = self {
        try container.encode(button, forKey: .value)
      }
    }
  }
}

struct TargetWindow: Codable, Equatable, Hashable, Identifiable, Sendable {
  var appName: String
  var bundleIdentifier: String
  var executablePath: String

  var id: String { bundleIdentifier }

  var displayName: String { appName }
}

struct ClickerLimits: Codable, Equatable, Sendable {
  var maximumClicks: Int?
  var maximumDuration: TimeInterval?
  var stopAtScreenEdge: Bool

  init(
    maximumClicks: Int? = nil,
    maximumDuration: TimeInterval? = nil,
    stopAtScreenEdge: Bool = true
  ) {
    self.maximumClicks = maximumClicks
    self.maximumDuration = maximumDuration
    self.stopAtScreenEdge = stopAtScreenEdge
  }
}

struct ClickerPreset: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  var name: String
  var targetType: TargetType
  var targetKey: TargetKey
  var targetWindow: TargetWindow?
  var cps: Double
  var jitterStrength: Double
  var limits: ClickerLimits
  var jitterSamples: [Double]
  var gamingMacroEnabled: Bool

  init(
    id: UUID = UUID(),
    name: String,
    targetType: TargetType,
    targetKey: TargetKey,
    targetWindow: TargetWindow?,
    cps: Double,
    jitterStrength: Double,
    limits: ClickerLimits,
    jitterSamples: [Double] = [],
    gamingMacroEnabled: Bool = false
  ) {
    self.id = id
    self.name = name
    self.targetType = targetType
    self.targetKey = targetKey
    self.targetWindow = targetWindow
    self.cps = cps
    self.jitterStrength = jitterStrength
    self.limits = limits
    self.jitterSamples = jitterSamples
    self.gamingMacroEnabled = gamingMacroEnabled
  }

  static var balancedDefault: ClickerPreset {
    ClickerPreset(
      name: "Balanced Tap",
      targetType: .mouse,
      targetKey: .mouse(.left),
      targetWindow: nil,
      cps: 12,
      jitterStrength: 0.18,
      limits: ClickerLimits()
    )
  }
}
