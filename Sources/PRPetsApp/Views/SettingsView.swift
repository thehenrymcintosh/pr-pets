import PRPetsCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateController

    var body: some View {
        TabView {
            Form { GitHubSettings(model: model) }
                .tabItem { Label("GitHub", systemImage: "arrow.triangle.pull") }
            Form { PetSettings(model: model) }
                .tabItem { Label("Pets", systemImage: "pawprint") }
            Form { PlacementSettings(model: model, updates: updates) }
                .tabItem { Label("Placement", systemImage: "rectangle.bottomhalf.inset.filled") }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
    }
}

/// A two-way binding to one setting that saves on every change.
@MainActor
private func setting<Value>(_ model: AppModel, _ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
    Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.updatePreferences { $0[keyPath: keyPath] = value } })
}

/// Edits a list setting as comma-separated text.
@MainActor
private func listSetting(_ model: AppModel, _ keyPath: WritableKeyPath<Preferences, [String]>) -> Binding<String> {
    Binding(
        get: { model.preferences[keyPath: keyPath].joined(separator: ", ") },
        set: { text in
            let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            model.updatePreferences { $0[keyPath: keyPath] = items }
        }
    )
}

private struct GitHubSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Section("Source") {
            Picker("Pull requests from", selection: setting(model, \.dataSource)) {
                Text("GitHub (via gh)").tag(DataSourceKind.github)
                Text("Demo data").tag(DataSourceKind.demo)
            }
            LabeledContent("Check every") {
                HStack {
                    Slider(value: setting(model, \.pollIntervalMinutes), in: Preferences.pollIntervalRange, step: 1)
                    Text("\(Int(model.preferences.pollIntervalMinutes)) min").monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
            TextField("gh path", text: setting(model, \.ghExecutablePath), prompt: Text("Found automatically"))
            TextField("GitHub host", text: setting(model, \.githubHost), prompt: Text("github.com"))
        }
        Section("What counts") {
            Toggle("Include review requests sent to my teams", isOn: setting(model, \.includeTeamReviewRequests))
            Toggle("Fetch whole stacks for context", isOn: setting(model, \.showStackContext))
            TextField("Only these orgs/users", text: listSetting(model, \.onlyOwners), prompt: Text("Everywhere"))
            TextField("Ignore repositories", text: listSetting(model, \.excludedRepositories), prompt: Text("owner/repo, …"))
        }
    }
}

private struct PetSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Section("Who gets a pet") {
            ForEach(Lane.allCases, id: \.self) { lane in
                Toggle(lane.petToggleTitle, isOn: Binding(
                    get: { model.preferences.petLanes.contains(lane) },
                    set: { enabled in
                        model.updatePreferences { preferences in
                            if enabled { preferences.petLanes.insert(lane) } else { preferences.petLanes.remove(lane) }
                        }
                    }
                ))
            }
            Text("Pets for your own PRs wear what they're waiting on as their name tag, like \"ready to merge\".")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Behaviour") {
            Toggle("Send pets inside", isOn: setting(model, \.petsAreInside))
            Toggle("Send a pet home once someone else approves", isOn: setting(model, \.hideWhenApprovedByOthers))
            Toggle("Show a summary when hovering a pet", isOn: setting(model, \.showHoverCards))
            Stepper("At most \(model.preferences.maximumPets) pets", value: setting(model, \.maximumPets), in: 1...30)
        }
        Section("Look") {
            Picker("Name tag", selection: setting(model, \.labelStyle)) {
                Text("Author's username").tag(PetLabelStyle.authorLogin)
                Text("Author's name").tag(PetLabelStyle.authorName)
                Text("Repository").tag(PetLabelStyle.repository)
                Text("None").tag(PetLabelStyle.hidden)
            }
            ForEach(Species.allCases, id: \.self) { species in
                Toggle(species.rawValue.capitalized, isOn: Binding(
                    get: { model.preferences.allowedSpecies.contains(species) },
                    set: { allowed in
                        model.updatePreferences { preferences in
                            let updated = allowed
                                ? preferences.allowedSpecies + [species]
                                : preferences.allowedSpecies.filter { $0 != species }
                            // Keep at least one species so there's always someone to send out.
                            preferences.allowedSpecies = updated.isEmpty ? preferences.allowedSpecies : Species.allCases.filter(updated.contains)
                        }
                    }
                ))
            }
        }
    }
}

private struct PlacementSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateController

    var body: some View {
        Section("Size") {
            LabeledContent("Scale") {
                HStack {
                    Slider(value: setting(model, \.scale), in: Preferences.scaleRange, step: 0.5)
                    Text(String(format: "%.1f×", model.preferences.scale)).monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
        }
        Section("Where pets roam") {
            Picker("Roam", selection: setting(model, \.roamingArea)) {
                Text("Near the doghouse").tag(RoamingArea.nearDoghouse)
                Text("Across the whole screen").tag(RoamingArea.screenWidth)
            }
            if model.preferences.roamingArea == .nearDoghouse {
                LabeledContent("Yard width") {
                    HStack {
                        Slider(value: setting(model, \.roamingWidth), in: 200...1600, step: 20)
                        Text("\(Int(model.preferences.roamingWidth)) pt").monospacedDigit().frame(width: 60, alignment: .trailing)
                    }
                }
            }
            Toggle("Hide while an app is full screen or presenting", isOn: setting(model, \.hideDuringFullScreen))
            Text("Drag the doghouse to move everything. Pets walk along the ground line at its base.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Reset position") { model.updatePreferences { $0.placement = .default } }
        }
        Section("App") {
            Toggle("Show in menu bar", isOn: setting(model, \.showMenuBarIcon))
            Toggle("Launch at login", isOn: setting(model, \.launchAtLogin))
        }
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: setting(model, \.checkForUpdatesAutomatically))
            LabeledContent("Version \(updates.installedVersion?.description ?? "unknown")") {
                UpdateButton(updates: updates)
            }
            UpdateStatusText(status: updates.status)
        }
    }
}

/// Checks for, or installs, an update depending on what's known.
struct UpdateButton: View {
    @ObservedObject var updates: UpdateController

    var body: some View {
        switch updates.status {
        case .available(let release):
            Button("Update to v\(release.version)") { Task { await updates.install() } }
                .buttonStyle(.borderedProminent)
        case .installing:
            ProgressView().controlSize(.small)
        default:
            Button("Check for Updates") { Task { await updates.check() } }
                .disabled(!updates.canCheck)
        }
    }
}

private struct UpdateStatusText: View {
    let status: UpdateStatus

    var body: some View {
        Group {
            switch status {
            case .unavailable(let reason): Text(reason)
            case .idle: Text("Updates come from GitHub releases.")
            case .checking: Text("Checking GitHub…")
            case .upToDate(let checkedAt): Text("Up to date. Checked \(checkedAt.formatted(.relative(presentation: .named))).")
            case .available(let release): Text("v\(release.version) is available. PR Pets will restart to finish updating.")
            case .installing(let release): Text("Installing v\(release.version)…")
            case .failed(let message): Text(message).foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
}
