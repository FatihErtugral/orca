import OrcaCore
import AppKit
import Combine
import SwiftUI

@main
struct OrcaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notifier = UserNotificationScheduler()
    private let preferencesStore = PreferencesStore()
    private lazy var store = AgentStore(
        notifications: notifier,
        preferences: { [preferencesStore] in preferencesStore.preferences }
    )
    private let focuser = TerminalFocuser()
    private let stateStore = AgentStateStore()
    private let titleRefresher = SessionTitleRefresher()
    private let updateMonitor = UpdateMonitor()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var socketServer: SocketServer?
    private var ollamaPoller: OllamaPoller?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notifier.requestAuthorization()
        store.startPruning()
        titleRefresher.start(store: store)
        updateMonitor.start()

        setupStatusItem()
        setupPopover()
        loadPersistedSessions()
        startBackends()

        cancellable = store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateStatusLabel() }
        updateStatusLabel()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func updateStatusLabel() {
        guard let button = statusItem.button else { return }
        let needsAttention = store.agents.contains { $0.status == .waiting || $0.status == .error }
        button.image = StatusBarIcon.make(
            running: store.runningCount,
            open: store.openSessionCount,
            attention: needsAttention
        )
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.contentViewController = NSHostingController(
            rootView: MenuView(
                onSelectAgent: { [focuser] in focuser.focus($0) },
                onDismissAgent: { [weak self] agent in
                    self?.store.remove(id: agent.id)
                    self?.stateStore.remove(id: agent.id)
                }
            )
            .environmentObject(store)
            .environmentObject(preferencesStore)
            .environmentObject(updateMonitor)
        )
    }

    /// Rehydrate sessions that were already open before the app launched.
    private func loadPersistedSessions() {
        for event in stateStore.loadAll() {
            store.apply(event)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func startBackends() {
        let server = SocketServer { [weak self] event in
            DispatchQueue.main.async { self?.store.apply(event) }
        }
        server.start()
        socketServer = server

        let poller = OllamaPoller { [weak self] models in
            DispatchQueue.main.async { self?.store.syncOllama(models: models) }
        }
        poller.start()
        ollamaPoller = poller
    }
}
