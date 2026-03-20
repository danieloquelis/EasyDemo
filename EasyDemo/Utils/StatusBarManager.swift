import AppKit

@MainActor
class StatusBarManager: NSObject {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private var durationTimer: Timer?

    private override init() {
        super.init()
    }

    func show() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: "Stop Recording")
            button.image = image
            button.target = self
            button.action = #selector(stopRecording)
        }

        self.statusItem = item

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
    }

    func hide() {
        durationTimer?.invalidate()
        durationTimer = nil

        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    private func updateDuration() {
        let duration = RecordingEngine.shared.recordingDuration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        statusItem?.button?.title = String(format: " %02d:%02d", minutes, seconds)
    }

    @objc private func stopRecording() {
        Task {
            await RecordingEngine.shared.stopRecording()
        }
    }
}
