import AppKit
import SwiftUI

final class OverlayWindowController {
    private var panels: [NSPanel] = []

    func show(event: MeetingEvent, countdownSeconds: Int,
              monitor: MeetingMonitor,
              onDismiss: @escaping () -> Void,
              onSnooze: @escaping () -> Void,
              onJoin: @escaping () -> Void) {
        close()

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.isMovable = false
            panel.hidesOnDeactivate = false

            let overlayView = OverlayView(
                event: event,
                monitor: monitor,
                onDismiss: { [weak self] in
                    self?.close()
                    onDismiss()
                },
                onSnooze: { [weak self] in
                    self?.close()
                    onSnooze()
                },
                onJoin: { [weak self] in
                    self?.close()
                    onJoin()
                }
            )

            panel.contentView = NSHostingView(rootView: overlayView)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panel.makeKey()

            panels.append(panel)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }
}
