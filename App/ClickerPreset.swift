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
  case forwardDelete
  case capsLock
  case help
  case home
  case end
  case pageUp
  case pageDown
  case leftArrow
  case rightArrow
  case upArrow
  case downArrow
  case keypadEnter
  case keypadClear
  case keypadDecimal
  case keypadMultiply
  case keypadPlus
  case keypadDivide
  case keypadMinus
  case keypadEquals
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
  case f13
  case f14
  case f15
  case f16
  case f17
  case f18
  case f19
  case f20

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
    case .forwardDelete:
      return "Forward Delete"
    case .capsLock:
      return "Caps Lock"
    case .help:
      return "Help"
    case .home:
      return "Home"
    case .end:
      return "End"
    case .pageUp:
      return "Page Up"
    case .pageDown:
      return "Page Down"
    case .leftArrow:
      return "Left Arrow"
    case .rightArrow:
      return "Right Arrow"
    case .upArrow:
      return "Up Arrow"
    case .downArrow:
      return "Down Arrow"
    case .keypadEnter:
      return "Keypad Enter"
    case .keypadClear:
      return "Keypad Clear"
    case .keypadDecimal:
      return "Keypad Decimal"
    case .keypadMultiply:
      return "Keypad Multiply"
    case .keypadPlus:
      return "Keypad Plus"
    case .keypadDivide:
      return "Keypad Divide"
    case .keypadMinus:
      return "Keypad Minus"
    case .keypadEquals:
      return "Keypad Equals"
    case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12,
      .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20:
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
    case .forwardDelete:
      return 117
    case .capsLock:
      return 57
    case .help:
      return 114
    case .home:
      return 115
    case .end:
      return 119
    case .pageUp:
      return 116
    case .pageDown:
      return 121
    case .leftArrow:
      return 123
    case .rightArrow:
      return 124
    case .downArrow:
      return 125
    case .upArrow:
      return 126
    case .keypadEnter:
      return 76
    case .keypadClear:
      return 71
    case .keypadDecimal:
      return 65
    case .keypadMultiply:
      return 67
    case .keypadPlus:
      return 69
    case .keypadDivide:
      return 75
    case .keypadMinus:
      return 78
    case .keypadEquals:
      return 81
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
    case .f13:
      return 105
    case .f14:
      return 107
    case .f15:
      return 113
    case .f16:
      return 106
    case .f17:
      return 64
    case .f18:
      return 79
    case .f19:
      return 80
    case .f20:
      return 90
    }
  }
}

enum KeyboardModifier: String, Codable, CaseIterable, Identifiable, Sendable {
  case control
  case option
  case shift
  case command
  case function
  case capsLock

  var id: String { rawValue }

  var title: String {
    switch self {
    case .control:
      return "Control"
    case .option:
      return "Option"
    case .shift:
      return "Shift"
    case .command:
      return "Command"
    case .function:
      return "Fn"
    case .capsLock:
      return "Caps Lock"
    }
  }
}

enum AutomationKey: Codable, Equatable, Hashable, Sendable {
  case character(String)
  case system(KeyboardCommand)

  var displayName: String {
    switch self {
    case .character(let value):
      return value.isEmpty ? "Custom key" : value
    case .system(let command):
      return command.title
    }
  }

  private enum CodingKeys: String, CodingKey {
    case kind
    case value
  }

  private enum Kind: String, Codable {
    case character
    case system
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)

    switch kind {
    case .character:
      self = .character(try container.decode(String.self, forKey: .value))
    case .system:
      self = .system(try container.decode(KeyboardCommand.self, forKey: .value))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .character(let value):
      try container.encode(Kind.character, forKey: .kind)
      try container.encode(value, forKey: .value)
    case .system(let command):
      try container.encode(Kind.system, forKey: .kind)
      try container.encode(command, forKey: .value)
    }
  }
}

struct KeyboardChord: Codable, Equatable, Hashable, Sendable {
  var key: AutomationKey
  var modifiers: [KeyboardModifier]

  var displayName: String {
    let modifierNames = KeyboardModifier.allCases
      .filter(modifiers.contains)
      .map(\.title)
    return (modifierNames + [key.displayName]).joined(separator: " + ")
  }

  init(key: AutomationKey, modifiers: [KeyboardModifier]) {
    self.key = key
    self.modifiers = KeyboardModifier.allCases.filter(modifiers.contains)
  }
}

enum TargetKey: Codable, Equatable, Hashable, Sendable {
  case character(String)
  case command(KeyboardCommand)
  case combination(KeyboardChord)
  case mouse(MouseButton)

  var displayName: String {
    switch self {
    case .character(let value):
      return value.isEmpty ? "Custom key" : value
    case .command(let command):
      return command.title
    case .combination(let chord):
      return chord.displayName
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
    case combination
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
    case .combination:
      self = .combination(try container.decode(KeyboardChord.self, forKey: .value))
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
    case .combination(let chord):
      try container.encode(Kind.combination, forKey: .kind)
      try container.encode(chord, forKey: .value)
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
  static let defaultPressDuration = 0.05
  static let minimumPressDuration = 0.001
  static let maximumPressDuration = 1.0

  let id: UUID
  var name: String
  var targetType: TargetType
  var targetKey: TargetKey
  var targetWindow: TargetWindow?
  var cps: Double
  var jitterStrength: Double
  var pressDuration: TimeInterval
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
    gamingMacroEnabled: Bool = false,
    pressDuration: TimeInterval = 0.05
  ) {
    self.id = id
    self.name = name
    self.targetType = targetType
    self.targetKey = targetKey
    self.targetWindow = targetWindow
    self.cps = cps
    self.jitterStrength = jitterStrength
    self.pressDuration = min(
      max(pressDuration, Self.minimumPressDuration),
      Self.maximumPressDuration
    )
    self.limits = limits
    self.jitterSamples = jitterSamples
    self.gamingMacroEnabled = gamingMacroEnabled
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case targetType
    case targetKey
    case targetWindow
    case cps
    case jitterStrength
    case pressDuration
    case limits
    case jitterSamples
    case gamingMacroEnabled
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    targetType = try container.decode(TargetType.self, forKey: .targetType)
    targetKey = try container.decode(TargetKey.self, forKey: .targetKey)
    targetWindow = try container.decodeIfPresent(TargetWindow.self, forKey: .targetWindow)
    cps = try container.decode(Double.self, forKey: .cps)
    jitterStrength = try container.decode(Double.self, forKey: .jitterStrength)
    let decodedPressDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .pressDuration)
      ?? Self.defaultPressDuration
    pressDuration = min(
      max(decodedPressDuration, Self.minimumPressDuration),
      Self.maximumPressDuration
    )
    limits = try container.decode(ClickerLimits.self, forKey: .limits)
    jitterSamples = try container.decodeIfPresent([Double].self, forKey: .jitterSamples) ?? []
    gamingMacroEnabled = try container.decodeIfPresent(Bool.self, forKey: .gamingMacroEnabled) ?? false
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
