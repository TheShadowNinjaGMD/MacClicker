import AppKit
import SwiftUI

@MainActor
final class AccessibilityOnboardingPanelController {
  private var panel: AccessibilityHelperPanel?
  private var isDismissing = false

  func present(applicationURL: URL, icon: NSImage) {
    if let panel {
      panel.alphaValue = 1
      panel.orderFrontRegardless()
      return
    }

    let panelSize = NSSize(width: 410, height: 124)
    let helperPanel = AccessibilityHelperPanel(
      contentRect: NSRect(origin: .zero, size: panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    helperPanel.title = "Accessibility Setup"
    helperPanel.level = .floating
    helperPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    helperPanel.hidesOnDeactivate = false
    helperPanel.isReleasedWhenClosed = false
    helperPanel.isMovableByWindowBackground = true
    helperPanel.isOpaque = false
    helperPanel.backgroundColor = .clear
    helperPanel.hasShadow = true
    helperPanel.becomesKeyOnlyIfNeeded = false
    helperPanel.contentView = NSHostingView(
      rootView: AccessibilityHelperPanelContent(applicationURL: applicationURL, icon: icon)
    )

    if let screen = NSScreen.main {
      let visibleFrame = screen.visibleFrame
      helperPanel.setFrameOrigin(
        NSPoint(
          x: visibleFrame.maxX - panelSize.width - 24,
          y: visibleFrame.maxY - panelSize.height - 24
        )
      )
    }

    panel = helperPanel
    helperPanel.alphaValue = 0
    helperPanel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      helperPanel.animator().alphaValue = 1
    }
  }

  func dismiss(completion: @escaping @MainActor () -> Void = {}) {
    guard let panel else {
      completion()
      return
    }
    guard !isDismissing else { return }

    isDismissing = true
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.24
      panel.animator().alphaValue = 0
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { [weak self, weak panel] in
      panel?.orderOut(nil)
      panel?.close()
      self?.panel = nil
      self?.isDismissing = false
      completion()
    }
  }
}

private final class AccessibilityHelperPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private struct AccessibilityHelperPanelContent: View {
  let applicationURL: URL
  let icon: NSImage

  var body: some View {
    HStack(spacing: 14) {
      ApplicationFileDragSource(applicationURL: applicationURL, icon: icon)
        .frame(width: 58, height: 58)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
        .accessibilityLabel("MacClicker app icon")
        .accessibilityHint("Drag this app file into the Accessibility list in System Settings.")

      VStack(alignment: .leading, spacing: 5) {
        Text("Add MacClicker to Accessibility")
          .font(.headline)
        Text("Drag the icon into the Accessibility list. If the drop isn’t accepted, use + in System Settings to choose MacClicker.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(16)
    .frame(width: 410, height: 124)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
    }
  }
}

private struct ApplicationFileDragSource: NSViewRepresentable {
  let applicationURL: URL
  let icon: NSImage

  func makeNSView(context: Context) -> ApplicationFileDragView {
    let view = ApplicationFileDragView()
    view.applicationURL = applicationURL
    view.icon = icon
    return view
  }

  func updateNSView(_ nsView: ApplicationFileDragView, context: Context) {
    nsView.applicationURL = applicationURL
    nsView.icon = icon
    nsView.needsDisplay = true
  }
}

private final class ApplicationFileDragView: NSView, NSDraggingSource {
  var applicationURL: URL?
  var icon: NSImage?

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard let icon, icon.size.width > 0, icon.size.height > 0 else { return }

    let drawingBounds = bounds.insetBy(dx: 3, dy: 3)
    let scale = min(drawingBounds.width / icon.size.width, drawingBounds.height / icon.size.height)
    let imageSize = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
    let imageRect = NSRect(
      x: drawingBounds.midX - imageSize.width / 2,
      y: drawingBounds.midY - imageSize.height / 2,
      width: imageSize.width,
      height: imageSize.height
    )
    icon.draw(in: imageRect)
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func resetCursorRects() {
    super.resetCursorRects()
    addCursorRect(bounds, cursor: .openHand)
  }

  override func mouseDown(with event: NSEvent) {
    guard let applicationURL else { return }

    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(applicationURL.absoluteString, forType: .fileURL)
    let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
    draggingItem.setDraggingFrame(bounds, contents: icon)
    beginDraggingSession(with: [draggingItem], event: event, source: self)
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }
}
