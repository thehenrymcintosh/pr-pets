import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let updates = UpdateController()
    private var overlay: OverlayController?
    private var subscriptions: Set<AnyCancellable> = []
    private var statusItem: StatusItemController?
    private var dashboardWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let actions = AppActions(
            showDashboard: { [weak self] in self?.showDashboard() },
            showSettings: { [weak self] in self?.showSettings() }
        )
        let overlay = OverlayController(model: model, updates: updates, actions: actions)
        overlay.show()
        self.overlay = overlay
        statusItem = StatusItemController(model: model, updates: updates, actions: actions)
        model.startPolling()
        model.$preferences
            .map(\.checkForUpdatesAutomatically)
            .removeDuplicates()
            .sink { [weak self] enabled in self?.updates.setAutomaticChecks(enabled: enabled) }
            .store(in: &subscriptions)
        if ProcessInfo.processInfo.environment["PR_PETS_DEBUG_SNAPSHOTS"] != nil {
            showDashboard()
            showSettings()
        }
        DebugSnapshots.scheduleIfRequested(model: model, updates: updates, overlay: overlay.view) { [weak self] in
            [self?.dashboardWindow, self?.settingsWindow].compactMap { $0 }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.startPolling() }
        }
    }

    /// Reopening the app from Finder or Spotlight while it's running shows the dashboard.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return false
    }

    func showDashboard() {
        dashboardWindow = present(dashboardWindow, title: "PR Pets", autosaveName: "Dashboard") {
            DashboardView(model: self.model, updates: self.updates, showSettings: { [weak self] in self?.showSettings() })
        }
    }

    func showSettings() {
        settingsWindow = present(settingsWindow, title: "PR Pets Settings", autosaveName: "Settings", resizable: false) {
            SettingsView(model: self.model, updates: self.updates)
        }
    }

    private func present<Content: View>(
        _ existing: NSWindow?,
        title: String,
        autosaveName: String,
        resizable: Bool = true,
        content: () -> Content
    ) -> NSWindow {
        let window = existing ?? {
            let styleMask: NSWindow.StyleMask = resizable ? [.titled, .closable, .miniaturizable, .resizable] : [.titled, .closable]
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 960, height: 520), styleMask: styleMask, backing: .buffered, defer: false)
            window.title = title
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: content())
            window.center()
            window.setFrameAutosaveName(autosaveName)
            return window
        }()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

/// The optional menu bar item: a paw with the number of PRs waiting.
@MainActor
final class StatusItemController {
    private let model: AppModel
    private let updates: UpdateController
    private let actions: AppActions
    private var item: NSStatusItem?
    private var subscriptions: Set<AnyCancellable> = []

    init(model: AppModel, updates: UpdateController, actions: AppActions) {
        self.model = model
        self.updates = updates
        self.actions = actions
        model.objectWillChange.merge(with: updates.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &subscriptions)
        update()
    }

    private func update() {
        guard model.effectivePreferences.showMenuBarIcon else {
            item.map { NSStatusBar.system.removeStatusItem($0) }
            item = nil
            return
        }
        let item = item ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item = item
        let count = model.board?.waitingPetCount ?? 0
        let symbol = model.syncStatus.problem == nil ? "pawprint.fill" : "exclamationmark.triangle"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "PR Pets")
        item.button?.title = count > 0 ? " \(count)" : ""
        item.button?.imagePosition = .imageLeading
        item.menu = NSMenu.appMenu(model: model, updates: updates, actions: actions)
    }
}

/// Windows the app can open from anywhere.
struct AppActions {
    let showDashboard: @MainActor () -> Void
    let showSettings: @MainActor () -> Void
}

extension NSMenu {
    /// The same menu from the menu bar paw and the doghouse's right-click.
    @MainActor
    static func appMenu(model: AppModel, updates: UpdateController, actions: AppActions) -> NSMenu {
        let insideTitle = model.effectivePreferences.petsAreInside ? "Let Pets Out" : "Send Pets Inside"
        let updateEntry: MenuEntry? = switch updates.status {
        case .available(let release): .item("Update to v\(release.version)…") { Task { await updates.install() } }
        case .unavailable, .installing: nil
        default: .item("Check for Updates…") { actions.showSettings(); Task { await updates.check() } }
        }
        return build([
            .item("Open Dashboard") { actions.showDashboard() },
            .item(insideTitle) { model.togglePetsInside() },
            .item("Refresh Now") { Task { await model.refresh() } },
            .separator,
            .item("Settings…") { actions.showSettings() },
        ] + [updateEntry].compactMap { $0 } + [
            .separator,
            .item("Quit PR Pets") { NSApp.terminate(nil) },
        ])
    }
}
