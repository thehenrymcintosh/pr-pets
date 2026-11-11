import AppKit
import PRPetsCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateController

    var body: some View {
        TabView {
            Form { GitHubSettings(model: model) }
                .tabItem { Label("GitHub", systemImage: "arrow.triangle.pull") }
            Form { FilterSettings(model: model) }
                .tabItem { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
            Form { PetSettings(model: model) }
                .tabItem { Label("Pets", systemImage: "pawprint") }
            Form { PlacementSettings(model: model) }
                .tabItem { Label("Placement", systemImage: "rectangle.bottomhalf.inset.filled") }
            Form { SystemSettings(model: model, updates: updates) }
                .tabItem { Label("System", systemImage: "gearshape") }
        }
        .formStyle(.grouped)
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// Wide enough that every tab still fits in the title bar, where macOS 26 puts them.
    static let size = CGSize(width: 600, height: 460)
}

/// A two-way binding to one setting that saves on every change.
@MainActor
private func setting<Value>(_ model: AppModel, _ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
    Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.updatePreferences { $0[keyPath: keyPath] = value } })
}

struct GitHubSettings: View {
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
        }
    }
}

/// Which repositories pull requests are fetched from. A tab of its own so the lists have room to grow.
struct FilterSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Section {
            FilterListEditor(kind: .owners, entries: setting(model, \.onlyOwners), openPullRequests: model.visibleSnapshot)
        } header: {
            Text("Only these orgs and users")
        } footer: {
            Text("Leave empty to see pull requests from everywhere.").font(.caption).foregroundStyle(.secondary)
        }
        Section {
            FilterListEditor(kind: .repositories, entries: setting(model, \.excludedRepositories), openPullRequests: model.visibleSnapshot)
        } header: {
            Text("Ignored repositories")
        } footer: {
            Text("Pull requests here get no pet and no dashboard row. Paste several at once, or links to anything on GitHub.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Edits a filter list one entry per row. The field takes one entry or a pasted list, and the setting is saved
/// only when entries are added or removed, so typing never kicks off a fetch with half a name in it.
private struct FilterListEditor: View {
    let kind: FilterListKind
    @Binding var entries: [String]
    /// The latest fetch, so entries can be picked rather than typed.
    let openPullRequests: PullRequestSnapshot?

    // @StateObject rather than @State: @State is a macro whose plugin ships only with Xcode, so it breaks
    // building from source with just the Command Line Tools.
    @StateObject private var field = FilterListField()

    var body: some View {
        // By position: the old comma-separated field could save the same entry twice.
        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
            FilterListRow(entry: entry, kind: kind) { remove(at: index) }
        }
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(kind.fieldTitle, text: $field.draft, prompt: Text(kind.prompt), axis: .vertical)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit(addDraft)
                    .onChange(of: field.draft) { _, text in if text.isEmpty { field.problem = nil } }
                if !suggestions.isEmpty {
                    Menu {
                        Section(kind.suggestionsTitle) {
                            ForEach(suggestions.prefix(15), id: \.entry) { suggestion in
                                Button("\(suggestion.entry)  ·  \(suggestion.pullRequestCount) open") { add(suggestion) }
                            }
                        }
                    } label: {
                        Text("Suggestions")
                    }
                    .fixedSize()
                    .help(kind.suggestionsTitle)
                }
                Button("Add", action: addDraft)
                    .disabled(field.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let problem = field.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var suggestions: [FilterSuggestion] {
        openPullRequests.map { kind.suggestions(from: $0, excluding: entries) } ?? []
    }

    private func addDraft() {
        let addition = kind.adding(field.draft, to: entries)
        if addition.entries != entries { entries = addition.entries }
        // Leave whatever couldn't be read in the field, so it can be fixed rather than retyped.
        field.draft = addition.unreadable.joined(separator: " ")
        field.problem = kind.problem(with: addition)
    }

    /// Leaves the field alone: whatever's half-typed there is still wanted.
    private func add(_ suggestion: FilterSuggestion) {
        entries = kind.adding(suggestion.entry, to: entries).entries
    }

    private func remove(at index: Int) {
        entries.remove(at: index)
        field.problem = nil
    }
}

/// What's typed into a filter list's field, and what went wrong adding it.
private final class FilterListField: ObservableObject {
    @Published var draft = ""
    @Published var problem: String?
}

private struct FilterListRow: View {
    let entry: String
    let kind: FilterListKind
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label(entry, systemImage: kind.symbol)
            if kind.normalised(entry) == nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(kind.unusableEntryHelp)
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove \(entry)")
            .accessibilityLabel("Remove \(entry)")
        }
    }
}

/// Wording for each filter list. What counts as a valid entry is decided in `FilterListKind` itself.
private extension FilterListKind {
    var fieldTitle: String {
        switch self {
        case .owners: "Add an org or user"
        case .repositories: "Add a repository to ignore"
        }
    }

    var prompt: String {
        switch self {
        case .owners: "acme, @someone, or a link"
        case .repositories: "owner/name, or a link to a repo or PR"
        }
    }

    var symbol: String {
        switch self {
        case .owners: "person.2"
        case .repositories: "book.closed"
        }
    }

    var suggestionsTitle: String {
        switch self {
        case .owners: "Orgs and users with open pull requests"
        case .repositories: "Repositories with open pull requests"
        }
    }

    var unusableEntryHelp: String {
        switch self {
        case .owners: "Not an org or user name, so it's left out of the search. Remove it and add one like acme."
        case .repositories: "Not in owner/name form, so it's left out of the search. Remove it and add one like acme/api."
        }
    }

    func problem(with addition: FilterListAddition) -> String? {
        var sentences: [String] = []
        if !addition.unreadable.isEmpty {
            let quoted = addition.unreadable.map { "“\($0)”" }.formatted(.list(type: .and))
            let sentence = switch self {
            case .owners: "Couldn't read \(quoted) as an org or user, like acme. To leave out a single repository, use Ignored repositories."
            case .repositories: "Couldn't read \(quoted) as owner/name, like acme/api."
            }
            sentences.append(sentence)
        }
        if !addition.alreadyListed.isEmpty {
            let names = addition.alreadyListed.formatted(.list(type: .and))
            let verb = addition.alreadyListed.count == 1 ? "is" : "are"
            let sentence = switch self {
            case .owners: "\(names) \(verb) already in the list."
            case .repositories: "\(names) \(verb) already ignored."
            }
            sentences.append(sentence)
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }
}

struct PetSettings: View {
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

struct PlacementSettings: View {
    @ObservedObject var model: AppModel

    /// A colour setting stored as `0xRRGGBB`, as something `ColorPicker` can edit.
    private func colourBinding(_ keyPath: WritableKeyPath<Preferences, UInt32>) -> Binding<Color> {
        Binding(
            get: { Color(hex: model.preferences[keyPath: keyPath]) },
            set: { colour in model.updatePreferences { $0[keyPath: keyPath] = colour.hex } }
        )
    }

    var body: some View {
        Section("Size") {
            LabeledContent("Scale") {
                HStack {
                    Slider(value: setting(model, \.scale), in: Preferences.scaleRange, step: 0.5)
                    Text(String(format: "%.1f×", model.preferences.scale)).monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
        }
        Section("Doghouse") {
            Picker("Colour", selection: setting(model, \.doghouseColour.style)) {
                Text("Solid").tag(DoghouseColour.Style.solid)
                Text("Ombré").tag(DoghouseColour.Style.ombre)
                Text("Rainbow").tag(DoghouseColour.Style.rainbow)
            }
            .pickerStyle(.segmented)
            switch model.preferences.doghouseColour.style {
            case .solid:
                ColorPicker("Paint", selection: colourBinding(\.doghouseColour.primary), supportsOpacity: false)
            case .ombre:
                ColorPicker("Roof", selection: colourBinding(\.doghouseColour.primary), supportsOpacity: false)
                ColorPicker("Ground", selection: colourBinding(\.doghouseColour.secondary), supportsOpacity: false)
            case .rainbow:
                Text("Every colour of the rainbow, from the roof down.")
                    .font(.caption).foregroundStyle(.secondary)
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
    }
}

struct SystemSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateController

    var body: some View {
        Section("App") {
            Toggle("Show in menu bar", isOn: setting(model, \.showMenuBarIcon))
            Toggle("Launch at login", isOn: setting(model, \.launchAtLogin))
        }
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: setting(model, \.checkForUpdatesAutomatically))
            LabeledContent(updates.installedVersion.map { "Version \($0)" } ?? "Development build") {
                UpdateButton(updates: updates)
            }
            UpdateStatusText(status: updates.status)
        }
        Section {
            HStack {
                Text("PR Pets keeps running in the background until you quit it.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit PR Pets", role: .destructive) { NSApp.terminate(nil) }
            }
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

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }

    /// `0xRRGGBB` in sRGB, which is what the doghouse is painted in.
    var hex: UInt32 {
        let colour = NSColor(self).usingColorSpace(.sRGB) ?? .black
        func byte(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return byte(colour.redComponent) << 16 | byte(colour.greenComponent) << 8 | byte(colour.blueComponent)
    }
}
