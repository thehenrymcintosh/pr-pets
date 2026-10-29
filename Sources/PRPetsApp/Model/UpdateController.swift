import AppKit
import Foundation
import PRPetsUpdates

enum UpdateStatus: Equatable {
    /// Running from `swift build` rather than an installed .app, so there's nothing to replace.
    case unavailable(reason: String)
    case idle
    case checking
    case upToDate(checkedAt: Date)
    case available(Release)
    case installing(Release)
    case failed(message: String)

    var availableRelease: Release? {
        if case .available(let release) = self { return release }
        return nil
    }

    var isBusy: Bool {
        switch self {
        case .checking, .installing: true
        default: false
        }
    }
}

/// Checks GitHub Releases for a newer PR Pets and installs it on request.
@MainActor
final class UpdateController: ObservableObject {
    static let repository = "thehenrymcintosh/pr-pets"
    private static let automaticCheckInterval: Duration = .seconds(24 * 60 * 60)

    @Published private(set) var status: UpdateStatus
    let installedVersion: AppVersion?
    private let feed = GitHubReleaseFeed(repository: repository)
    private let installer: UpdateInstaller
    private var automaticChecks: Task<Void, Never>?

    init(bundle: Bundle = .main) {
        installer = UpdateInstaller(installedApp: bundle.bundleURL)
        let versionText = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        installedVersion = versionText.flatMap(AppVersion.init)
        status = bundle.bundleURL.pathExtension == "app" && installedVersion != nil
            ? .idle
            : .unavailable(reason: "Updates are off for development builds.")
    }

    var canCheck: Bool {
        if case .unavailable = status { return false }
        return !status.isBusy
    }

    func setAutomaticChecks(enabled: Bool) {
        automaticChecks?.cancel()
        guard enabled, canCheck else { return }
        automaticChecks = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: Self.automaticCheckInterval)
            }
        }
    }

    func check() async {
        guard canCheck, let installedVersion else { return }
        status = .checking
        do {
            let update = try await feed.update(after: installedVersion)
            status = update.map(UpdateStatus.available) ?? .upToDate(checkedAt: Date())
            Log.updates.info("Update check: \(update.map { "v\($0.version) available" } ?? "up to date", privacy: .public)")
        } catch {
            status = .failed(message: String(describing: error))
            Log.updates.error("Update check failed: \(String(describing: error), privacy: .public)")
        }
    }

    func install() async {
        guard let release = status.availableRelease else { return }
        status = .installing(release)
        do {
            try await installer.install(release)
            Log.updates.info("Installed v\(release.version.description, privacy: .public); relaunching")
            installer.relaunch()
            NSApp.terminate(nil)
        } catch {
            status = .failed(message: String(describing: error))
            Log.updates.error("Update install failed: \(String(describing: error), privacy: .public)")
        }
    }
}
