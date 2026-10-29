import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private var store: SessionStore!
    private var model: NotchModel!
    private var notch: NotchPanelController!
    private var statusItem: NSStatusItem!
    private var hookStatus = "Setting up Claude Code hooks…"

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = SessionStore()
        model = NotchModel(store: store, settings: settings)
        notch = NotchPanelController(model: model)
        settings.applyFirstRunDefaults()
        installHooks()
        setUpStatusItem()
        model.welcome()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.notch.reposition() }
        }
    }

    private func installHooks() {
        do {
            let changed = try HookInstaller.install()
            hookStatus = changed
                ? "Hooks installed. Restart open Claude sessions."
                : "Connected to Claude Code"
        } catch {
            hookStatus = error.localizedDescription
            NSLog("Peekaboo: hook install failed: \(error)")
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eyes", accessibilityDescription: "Peekaboo")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: hookStatus, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let buddyItem = NSMenuItem(title: "Buddy", action: nil, keyEquivalent: "")
        let buddyMenu = NSMenu()
        for buddy in Buddy.allCases {
            let item = NSMenuItem(title: buddy.name, action: #selector(pickBuddy(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = buddy.rawValue
            item.state = settings.buddy == buddy ? .on : .off
            buddyMenu.addItem(item)
        }
        buddyItem.submenu = buddyMenu
        menu.addItem(buddyItem)

        menu.addItem(toggle("Play sounds", on: settings.soundsOn, action: #selector(toggleSounds)))
        menu.addItem(toggle("Open at login", on: settings.launchAtLogin, action: #selector(toggleLogin)))
        menu.addItem(.separator())
        menu.addItem(item("Play demo", action: #selector(playDemo)))
        menu.addItem(item("Reinstall Claude Code hooks", action: #selector(reinstallHooks)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Peekaboo", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func toggle(_ title: String, on: Bool, action: Selector) -> NSMenuItem {
        let i = item(title, action: action)
        i.state = on ? .on : .off
        return i
    }

    @objc private func pickBuddy(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let buddy = Buddy(rawValue: raw) else { return }
        settings.buddy = buddy
        model.welcome()
    }

    @objc private func toggleSounds() { settings.soundsOn.toggle() }
    @objc private func toggleLogin() { settings.launchAtLogin.toggle() }
    @objc private func playDemo() { model.playDemo() }
    @objc private func reinstallHooks() { installHooks() }
    @objc private func quit() { NSApp.terminate(nil) }
}
