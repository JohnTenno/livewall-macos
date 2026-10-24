import AppKit
import IOKit.ps

/// Tracks system conditions under which wallpapers should stop animating to save power.
@MainActor
final class PlaybackPolicy {
    var onChange: (() -> Void)?

    private(set) var isScreenAsleep = false
    private(set) var isScreenLocked = false
    private(set) var isSessionActive = true
    private(set) var isOnBattery = false
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var powerSource: CFRunLoopSource?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.isScreenAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.isScreenAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.isSessionActive = false }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.isSessionActive = true }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.isScreenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.isScreenLocked = false }

        observe(NotificationCenter.default, Notification.Name.NSProcessInfoPowerStateDidChange) {
            $0.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }

        refreshPowerSource()
        watchPowerSource()
    }

    deinit {
        observers.forEach { $0.0.removeObserver($0.1) }
        if let powerSource { CFRunLoopSourceInvalidate(powerSource) }
    }

    func allowsPlayback(settings: AppSettings) -> Bool {
        !settings.isPaused
            && !isScreenAsleep
            && !isScreenLocked
            && isSessionActive
            && !isLowPowerMode
            && !(settings.pauseOnBattery && isOnBattery)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, update: @escaping (PlaybackPolicy) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                update(self)
                self.onChange?()
            }
        }
        observers.append((center, token))
    }

    private func watchPowerSource() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let policy = Unmanaged<PlaybackPolicy>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                policy.refreshPowerSource()
                policy.onChange?()
            }
        }, context)
        if let source = source?.takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private func refreshPowerSource() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return }
        isOnBattery = (type as String) == kIOPSBatteryPowerValue
    }
}
