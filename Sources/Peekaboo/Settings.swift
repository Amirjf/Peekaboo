import AppKit
import ServiceManagement

@MainActor
final class Settings: ObservableObject {
    static let shared = Settings()

    @Published var buddy: Buddy {
        didSet { UserDefaults.standard.set(buddy.rawValue, forKey: "buddy") }
    }

    @Published var soundsOn: Bool {
        didSet { UserDefaults.standard.set(soundsOn, forKey: "soundsOn") }
    }

    private init() {
        let d = UserDefaults.standard
        buddy = Buddy(rawValue: d.string(forKey: "buddy") ?? "") ?? .boo
        soundsOn = d.object(forKey: "soundsOn") as? Bool ?? true
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Peekaboo: launch at login change failed: \(error)")
            }
            objectWillChange.send()
        }
    }

    /// Turns on launch at login the first time the app runs, so setup is hands-free.
    func applyFirstRunDefaults() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "didFirstRun") else { return }
        d.set(true, forKey: "didFirstRun")
        launchAtLogin = true
    }
}
