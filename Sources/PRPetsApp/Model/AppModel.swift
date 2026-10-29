import AppKit
import Foundation
import PRPetsCore
import PRPetsDemo
import PRPetsGitHub
import ServiceManagement

enum SyncStatus: Equatable {
    case neverSynced
    case refreshing(lastSuccess: Date?)
    case synced(at: Date)
    case failed(message: String, at: Date, lastSuccess: Date?)

    var lastSuccess: Date? {
        switch self {
        case .neverSynced: nil
        case .refreshing(let lastSuccess): lastSuccess
        case .synced(let at): at
        case .failed(_, _, let lastSuccess): lastSuccess
        }
    }

    var problem: String? {
        if case .failed(let message, _, _) = self { return message }
        return nil
    }

    var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }
}

/// The app's state and every user command. Views observe it; nothing else mutates it.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var preferences: Preferences
    @Published private(set) var snapshot: PullRequestSnapshot?
    @Published private(set) var syncStatus: SyncStatus = .neverSynced
    @Published private(set) var ledger: TriageLedger
    @Published private(set) var identities: PetIdentityRegistry
    /// Dashboard stack groups the user has collapsed to just their highlighted members.
    @Published private(set) var collapsedGroupIDs: Set<String> = []

    private let preferencesStore = JSONFileStore<Preferences>.inApplicationSupport("settings.json", default: .default)
    private let ledgerStore = JSONFileStore<TriageLedger>.inApplicationSupport("triage.json", default: TriageLedger())
    private let identityStore = JSONFileStore<PetIdentityRegistry>.inApplicationSupport("pets.json", default: PetIdentityRegistry())
    /// Set by `PR_PETS_DATA_SOURCE=demo` (used by `make demo`); never written to the preferences file.
    private let dataSourceOverride: DataSourceKind?
    private var pollingTask: Task<Void, Never>?
    private var source: (any PullRequestSource)?
    private var sourceConfiguration: SourceConfiguration?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        preferences = preferencesStore.load()
        ledger = ledgerStore.load()
        identities = identityStore.load()
        dataSourceOverride = environment["PR_PETS_DATA_SOURCE"].flatMap(DataSourceKind.init(rawValue:))
    }

    /// Preferences with launch overrides applied. Everything that acts on preferences reads these.
    var effectivePreferences: Preferences {
        var effective = preferences
        if let dataSourceOverride { effective.dataSource = dataSourceOverride }
        return effective
    }

    var board: ReviewBoard? {
        snapshot.map { ReviewBoard(snapshot: $0, ledger: ledger, identities: identities, preferences: effectivePreferences) }
    }

    // MARK: - Commands

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard let interval = self?.pollInterval else { return }
                try? await Task.sleep(for: interval)
            }
        }
    }

    func refresh() async {
        guard !syncStatus.isRefreshing else { return }
        let preferences = effectivePreferences
        syncStatus = .refreshing(lastSuccess: syncStatus.lastSuccess)
        do {
            let fetched = try await currentSource(for: preferences).fetchSnapshot(preferences.pullRequestQuery)
            apply(fetched)
            syncStatus = .synced(at: fetched.fetchedAt)
            Log.sync.info("Fetched \(fetched.pullRequests.count) PRs, \(fetched.reviewRequestedOfViewer.count) awaiting review")
        } catch {
            let message = String(describing: error)
            syncStatus = .failed(message: message, at: Date(), lastSuccess: syncStatus.lastSuccess)
            Log.sync.error("Refresh failed: \(message, privacy: .public)")
        }
    }

    func updatePreferences(_ change: (inout Preferences) -> Void) {
        let previous = effectivePreferences
        var updated = preferences
        change(&updated)
        updated.scale = Preferences.scaleRange.clamp(updated.scale)
        guard updated != preferences else { return }
        preferences = updated
        preferencesStore.save(updated)
        reactToSettingsChange(from: previous)
    }

    func togglePetsInside() {
        updatePreferences { $0.petsAreInside.toggle() }
    }

    func mute(_ pullRequest: PullRequest) {
        updateLedger(ledger.muting(pullRequest, at: Date()))
    }

    func dismiss(_ pullRequest: PullRequest) {
        updateLedger(ledger.dismissing(pullRequest, at: Date()))
    }

    func restore(_ pullRequest: PullRequest) {
        updateLedger(ledger.restoring(pullRequest))
    }

    func toggleCollapsed(_ group: QueueGroup) {
        if collapsedGroupIDs.contains(group.id) { collapsedGroupIDs.remove(group.id) } else { collapsedGroupIDs.insert(group.id) }
    }

    func open(_ pullRequest: PullRequest) {
        NSWorkspace.shared.open(pullRequest.url)
    }

    // MARK: - Internals

    private var pollInterval: Duration {
        effectivePreferences.dataSource == .demo ? .seconds(4) : effectivePreferences.pollInterval
    }

    private func apply(_ fetched: PullRequestSnapshot) {
        snapshot = fetched
        identities = ReviewBoard.identities(identities, updatedFor: fetched)
        identityStore.save(identities)
        updateLedger(ledger.pruned(keeping: fetched.pullRequests))
    }

    private func updateLedger(_ updated: TriageLedger) {
        guard updated != ledger else { return }
        ledger = updated
        ledgerStore.save(updated)
    }

    private func reactToSettingsChange(from previous: Preferences) {
        let current = effectivePreferences
        if current.launchAtLogin != previous.launchAtLogin { applyLaunchAtLogin(current.launchAtLogin) }
        let fetchChanged = SourceConfiguration(current) != SourceConfiguration(previous)
            || current.pullRequestQuery != previous.pullRequestQuery
            || current.pollIntervalMinutes != previous.pollIntervalMinutes
        if fetchChanged {
            if current.dataSource != previous.dataSource { snapshot = nil }
            startPolling()
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.storage.error("Couldn't change launch at login: \(String(describing: error), privacy: .public)")
        }
    }

    private struct SourceConfiguration: Equatable {
        let kind: DataSourceKind
        let ghPath: String
        let host: String

        init(_ preferences: Preferences) {
            kind = preferences.dataSource
            ghPath = preferences.ghExecutablePath
            host = preferences.githubHost
        }
    }

    private func currentSource(for preferences: Preferences) -> any PullRequestSource {
        let configuration = SourceConfiguration(preferences)
        if let source, configuration == sourceConfiguration { return source }
        let created: any PullRequestSource = switch preferences.dataSource {
        case .demo:
            DemoPullRequestSource()
        case .github:
            GhCliPullRequestSource(configuration: .init(
                executablePath: preferences.ghExecutablePath.nonEmpty,
                host: preferences.githubHost.nonEmpty
            ))
        }
        source = created
        sourceConfiguration = configuration
        return created
    }
}

extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
