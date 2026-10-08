import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var model: ProofModel!
    private var statusItem: NSStatusItem!
    private var settings: NSWindow!
    private var testWindow: NSWindow?
    private var testDisplayID: UInt32?
    private var languageSubscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let identifier = Bundle.main.bundleIdentifier ?? "io.github.soom-kang.touchme"
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            if let url = other.bundleURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                config.createsNewApplicationInstance = false
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
            } else {
                other.activate(options: [])
                NSApp.terminate(nil)
            }
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let applicationMenu = NSMenu()
        add(applicationMenu, Texts.get("Touch Me 정보", "About Touch Me"), action: #selector(showAbout))
        applicationMenu.addItem(.separator())
        add(applicationMenu, Texts.get("Touch Me 종료", "Quit Touch Me"), action: #selector(quit), key: "q")
        let applicationItem = NSMenuItem()
        applicationItem.submenu = applicationMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
        model = ProofModel()
        model.onRunChange = { [weak self] running in
            self?.statusItem?.button?.title = running ? "TM ▶" : "TM"
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let statusIcon = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "Touch Me")
        statusIcon?.isTemplate = true
        statusItem.button?.image = statusIcon
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = model.running ? "TM ▶" : "TM"
        statusItem.button?.toolTip = "Touch Me"
        let menu = NSMenu()
        add(menu, Texts.get("매핑 시작", "Start mapping"), action: #selector(startMapping))
        add(menu, Texts.get("설정 / 시험", "Settings / Proof"), action: #selector(showSettings))
        add(menu, Texts.get("매핑 중지", "Stop mapping"), action: #selector(stopMapping))
        menu.addItem(.separator())
        add(menu, Texts.get("Touch Me 정보", "About Touch Me"), action: #selector(showAbout))
        add(menu, Texts.get("라이선스", "License"), action: #selector(showLicense))
        add(menu, Texts.get("Touch Me 종료", "Quit Touch Me"), action: #selector(quit), key: "q")
        statusItem.menu = menu
        settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 730),
                            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        settings.title = "Touch Me"
        settings.isReleasedWhenClosed = false
        settings.contentView = NSHostingView(rootView: ProofSettingsView(model: model, showTest: { [weak self] in self?.showTest() }))
        settings.center()
        languageSubscription = LanguagePreferences.shared.$selected
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateLocalizedInterface() }
        showSettings()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            self?.model.displayConfigurationChanged()
        })
        let workspaceEvents: [(Notification.Name, (ProofModel) -> Void)] = [
            (NSWorkspace.willSleepNotification, { $0.setSleeping(true) }),
            (NSWorkspace.didWakeNotification, { $0.setSleeping(false) }),
            (NSWorkspace.screensDidSleepNotification, { $0.setScreensSleeping(true) }),
            (NSWorkspace.screensDidWakeNotification, { $0.setScreensSleeping(false) }),
            (NSWorkspace.sessionDidResignActiveNotification, { $0.setSessionActive(false) }),
            (NSWorkspace.sessionDidBecomeActiveNotification, { $0.setSessionActive(true) }),
        ]
        for (name, handle) in workspaceEvents {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let model = self?.model else { return }
                handle(model)
            })
        }
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in self?.quit() }
            source.resume()
            signalSources.append(source)
        }
        model.resumeSavedMappingIfPossible()
    }

    func applicationProtectedDataWillBecomeUnavailable(_ notification: Notification) {
        model?.synchronizeAvailability()
    }

    func applicationProtectedDataDidBecomeAvailable(_ notification: Notification) {
        model?.synchronizeAvailability()
    }

    private func add(_ menu: NSMenu, _ title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func updateLocalizedInterface() {
        var menus = NSApp.mainMenu?.items.compactMap(\.submenu) ?? []
        if let menu = statusItem?.menu { menus.append(menu) }
        for menu in menus {
            for item in menu.items {
                switch item.action {
                case #selector(startMapping): item.title = Texts.get("매핑 시작", "Start mapping")
                case #selector(showSettings): item.title = Texts.get("설정 / 시험", "Settings / Proof")
                case #selector(stopMapping): item.title = Texts.get("매핑 중지", "Stop mapping")
                case #selector(showAbout): item.title = Texts.get("Touch Me 정보", "About Touch Me")
                case #selector(showLicense): item.title = Texts.get("라이선스", "License")
                case #selector(quit): item.title = Texts.get("Touch Me 종료", "Quit Touch Me")
                default: break
                }
            }
        }
        if let id = testDisplayID {
            testWindow?.title = Texts.get("Touch Me · 화면 \(id)", "Touch Me · Display \(id)")
        }
    }

    @objc func showSettings() {
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc func startMapping() { model?.start() }
    @objc func stopMapping() { model?.stop() }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(startMapping) { return model?.canStart == true }
        if item.action == #selector(stopMapping) {
            return model?.running == true || model?.modeRestorePending == true || model?.resumePending == true
        }
        return true
    }
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Touch Me",
            .applicationVersion: AppVersion.release,
            .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
        ])
        NSApp.activate()
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showLicense() {
        if let url = Bundle.main.url(forResource: "Licenses", withExtension: "txt") {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { model?.stopForTermination() }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let model, !model.stopForTermination() {
            showSettings()
            return .terminateCancel
        }
        return .terminateNow
    }

    private func showTest() {
        guard let target = model.displays.first(where: { $0.id == model.selectedDisplay }), target.canMap,
              let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == target.id }) else { return }
        model.confirmTarget(false)
        testWindow?.close()
        let rect = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: rect.size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false, screen: screen)
        window.setFrame(window.frameRect(forContentRect: rect), display: false)
        window.title = Texts.get("Touch Me · 화면 \(target.id)", "Touch Me · Display \(target.id)")
        window.isReleasedWhenClosed = false
        let scrollView = NSScrollView(frame: NSRect(origin: .zero, size: rect.size))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        let content = TouchTestView(frame: NSRect(x: 0, y: 0, width: max(rect.width * 2, 2440), height: max(rect.height * 3, 2300)))
        scrollView.documentView = content
        window.contentView = scrollView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(content)
        NSApp.activate()
        testWindow = window
        testDisplayID = target.id
    }
}
