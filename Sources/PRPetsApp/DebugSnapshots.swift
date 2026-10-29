import AppKit
import SwiftUI

/// Development aid: with `PR_PETS_DEBUG_SNAPSHOTS=<directory>`, the running app renders each of its windows
/// to PNGs after the pets have had time to come out, then quits. Lets the real UI be reviewed headlessly
/// (no Screen Recording permission needed).
@MainActor
enum DebugSnapshots {
    static func scheduleIfRequested(model: AppModel, updates: UpdateController, overlay: NSView, openWindows: @escaping () -> [NSWindow]) {
        guard let path = ProcessInfo.processInfo.environment["PR_PETS_DEBUG_SNAPSHOTS"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try write(overlay, to: directory.appending(path: "overlay.png"))
                for window in openWindows() {
                    guard let content = window.contentView else { continue }
                    let name = window.title.lowercased().replacingOccurrences(of: " ", with: "-")
                    try write(content, to: directory.appending(path: "\(name.isEmpty ? "window" : name).png"))
                }
                if let board = model.board, let pullRequest = board.queue.pullRequests(in: .needsMyReview).first {
                    let card = NSHostingView(rootView: PetCardView(
                        pullRequest: pullRequest, stackPosition: board.presence.stackPosition(of: pullRequest),
                        onOpen: {}, onDismiss: {}, onMute: {}
                    ).background(Color(nsColor: .windowBackgroundColor)))
                    card.frame = CGRect(origin: .zero, size: card.fittingSize)
                    try write(card, to: directory.appending(path: "pet-card.png"))
                }
                // The dashboard at its minimum width, where rows are most cramped.
                let narrowDashboard = NSHostingView(rootView: DashboardView(model: model, updates: updates, showSettings: {}))
                narrowDashboard.frame = CGRect(x: 0, y: 0, width: 900, height: 520)
                try write(narrowDashboard, to: directory.appending(path: "dashboard-narrow.png"))
                let tabs: [(String, AnyView)] = [
                    ("github", AnyView(GitHubSettings(model: model))),
                    ("pets", AnyView(PetSettings(model: model))),
                    ("placement", AnyView(PlacementSettings(model: model))),
                    ("system", AnyView(SystemSettings(model: model, updates: updates))),
                ]
                for (name, tab) in tabs {
                    let view = NSHostingView(rootView: Form { tab }.formStyle(.grouped).frame(width: 520, height: 460))
                    view.frame = CGRect(x: 0, y: 0, width: 520, height: 460)
                    try write(view, to: directory.appending(path: "settings-\(name).png"))
                }
                print("Wrote debug snapshots to \(directory.path)")
            } catch {
                print("Debug snapshots failed: \(error)")
            }
            NSApp.terminate(nil)
        }
    }

    private static func write(_ view: NSView, to url: URL) throws {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}
