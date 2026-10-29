import PRPetsCore
import SwiftUI

/// The window opened from the doghouse: three lanes of PRs, with stacks grouped in order.
struct DashboardView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateController
    let showSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DashboardHeader(model: model, updates: updates, showSettings: showSettings)
            Divider()
            if let board = model.board {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Lane.allCases, id: \.self) { lane in
                        LaneColumn(lane: lane, board: board, model: model)
                        if lane != Lane.allCases.last { Divider() }
                    }
                }
            } else {
                EmptyDashboard(status: model.syncStatus)
            }
        }
        .frame(minWidth: 900, minHeight: 420)
    }
}

private struct DashboardHeader: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateController
    let showSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SyncStatusView(status: model.syncStatus, isDemo: model.effectivePreferences.dataSource == .demo)
            Spacer()
            if updates.status.availableRelease != nil { UpdateButton(updates: updates) }
            Toggle("Pets inside", isOn: Binding(
                get: { model.effectivePreferences.petsAreInside },
                set: { inside in model.updatePreferences { $0.petsAreInside = inside } }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            Button {
                Task { await model.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(model.syncStatus.isRefreshing)
            Button(action: showSettings) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct SyncStatusView: View {
    let status: SyncStatus
    let isDemo: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let problem = status.problem {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(problem).textSelection(.enabled).lineLimit(3)
            } else if status.isRefreshing {
                ProgressView().controlSize(.small)
                Text("Checking GitHub…")
            } else if let lastSuccess = status.lastSuccess {
                Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                Text("Updated \(lastSuccess.formatted(.relative(presentation: .named)))")
            }
            if isDemo { Text("Demo data").font(.caption.bold()).foregroundStyle(.purple) }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

private struct EmptyDashboard: View {
    let status: SyncStatus

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint").font(.largeTitle).foregroundStyle(.secondary)
            Text(status.problem == nil ? "Fetching your pull requests…" : "Couldn't fetch pull requests yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LaneColumn: View {
    let lane: Lane
    let board: ReviewBoard
    @ObservedObject var model: AppModel

    private var groups: [QueueGroup] { board.queue.groups(in: lane) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lane.title).font(.headline)
                if board.presence.laneHasPets(lane) {
                    Image(systemName: "pawprint.fill").foregroundStyle(.secondary).help("PRs in this column get a pet")
                }
                Spacer()
                Text("\(board.queue.pullRequests(in: lane).count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            Text(lane.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(groups) { group in
                        QueueGroupView(group: group, board: board, model: model)
                    }
                    if groups.isEmpty {
                        Text(lane.emptyMessage).foregroundStyle(.tertiary).padding(12)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A stack (or single PR). Members not in this lane are greyed; collapsing hides them.
private struct QueueGroupView: View {
    let group: QueueGroup
    let board: ReviewBoard
    @ObservedObject var model: AppModel

    private var isCollapsed: Bool { group.canCollapse && model.collapsedGroupIDs.contains(group.id) }

    private var visibleMembers: [PullRequest] {
        isCollapsed ? group.highlightedMembers : group.stack.members
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if group.stack.isStacked {
                StackHeader(group: group, isCollapsed: isCollapsed) {
                    withAnimation(.snappy) { model.toggleCollapsed(group) }
                }
            }
            ForEach(visibleMembers) { member in
                PullRequestRow(
                    pullRequest: member,
                    isHighlighted: group.isHighlighted(member),
                    stackPosition: group.stack.isStacked ? group.stack.position(of: member) : nil,
                    lane: group.lane,
                    board: board,
                    model: model
                )
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }
}

/// "Stack of 4 in web". A collapse chevron only when collapsing would hide something.
private struct StackHeader: View {
    let group: QueueGroup
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        let title = Text("Stack of \(group.stack.members.count) in \(group.stack.members[0].repository.name)")
        Group {
            if group.canCollapse {
                Button(action: toggle) {
                    HStack(spacing: 4) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        title
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "Show the whole stack" : "Show only the PRs in this column")
            } else {
                title.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }
}

private struct PullRequestRow: View {
    let pullRequest: PullRequest
    let isHighlighted: Bool
    let stackPosition: StackPosition?
    let lane: Lane
    let board: ReviewBoard
    @ObservedObject var model: AppModel

    private var hasPet: Bool { isHighlighted && board.presence.laneHasPets(lane) }

    /// Why this PR's pet isn't out, when its column normally has pets.
    private var absence: PetAbsence? {
        hasPet ? board.presence.absence(of: pullRequest) : nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let stackPosition { StackBadge(position: stackPosition) }
            VStack(alignment: .leading, spacing: 3) {
                Text(pullRequest.title)
                    .font(.callout.weight(isHighlighted ? .semibold : .regular))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(pullRequest.shortReference)
                    Text(pullRequest.author.login.rawValue)
                    if pullRequest.isDraft { Tag(text: "Draft", colour: .gray) }
                    if let reason = board.queue.placement(of: pullRequest)?.reason, isHighlighted {
                        Tag(text: reason, colour: .orange)
                    }
                    if let absenceText = absence?.dashboardText { Tag(text: absenceText, colour: .purple) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                LineDeltaView(lineDelta: pullRequest.lineDelta).font(.caption)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .opacity(isHighlighted ? 1 : 0.45)
        .contentShape(Rectangle())
        .onTapGesture { model.open(pullRequest) }
        .contextMenu {
            Button("Open on GitHub") { model.open(pullRequest) }
            if hasPet {
                if absence.isSuppression {
                    Button("Let Pet Back Out") { model.restore(pullRequest) }
                } else {
                    Button("Dismiss Until New Commits") { model.dismiss(pullRequest) }
                    Button("Mute") { model.mute(pullRequest) }
                }
            }
        }
        .help(isHighlighted ? "Click to open on GitHub" : "In the same stack, but not in this column")
    }
}

private struct Tag: View {
    let text: String
    let colour: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(colour.opacity(0.15)))
            .foregroundStyle(colour)
    }
}

extension Lane {
    var title: String {
        switch self {
        case .needsMyReview: "Needs my review"
        case .needsMyAction: "Needs my action"
        case .waitingOnOthers: "Waiting on others"
        }
    }

    var explanation: String {
        switch self {
        case .needsMyReview: "Someone asked you to review these."
        case .needsMyAction: "Your PRs that are approved, have changes requested, or have no reviewers yet."
        case .waitingOnOthers: "Your PRs with reviewers requested."
        }
    }

    var petToggleTitle: String {
        switch self {
        case .needsMyReview: "PRs waiting for my review"
        case .needsMyAction: "My PRs that need something from me"
        case .waitingOnOthers: "My PRs waiting on reviewers"
        }
    }

    var emptyMessage: String {
        switch self {
        case .needsMyReview: "Nothing to review. The pets are napping."
        case .needsMyAction: "Nothing needs you."
        case .waitingOnOthers: "Nothing waiting."
        }
    }
}

extension QueuePlacement {
    var reason: String? {
        switch self {
        case .needsMyReview(.team): "Team"
        case .needsMyReview(.direct): nil
        case .needsMyAction(.addressChangesRequested): "Changes requested"
        case .needsMyAction(.merge): "Approved"
        case .needsMyAction(.finishDraft): "Finish draft"
        case .needsMyAction(.requestReviewers): "Request reviewers"
        case .waitingOnOthers: nil
        }
    }
}

extension PetAbsence {
    /// nil for absences that need no explanation.
    var dashboardText: String? {
        switch self {
        case .laneWithoutPets: nil
        case .suppressed(.muted): "Muted"
        case .suppressed(.dismissed): "Dismissed"
        case .approvedByOthers(let approvers): "Approved by \(approvers.map(\.rawValue).joined(separator: ", "))"
        }
    }
}

extension Optional where Wrapped == PetAbsence {
    var isSuppression: Bool {
        if case .suppressed = self { return true }
        return false
    }
}
