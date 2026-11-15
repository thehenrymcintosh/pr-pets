import PRPetsCore
import SwiftUI

/// The popover shown when a pet is clicked.
struct PetCardView: View {
    let pullRequest: PullRequest
    let stackPosition: StackPosition?
    let onOpen: () -> Void
    let onDismiss: () -> Void
    let onMute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pullRequest.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(pullRequest.shortReference)
                    Text("·")
                    Text("by \(pullRequest.author.displayName ?? pullRequest.author.login.rawValue)")
                    if let stackPosition {
                        StackBadge(position: stackPosition)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            LineDeltaView(lineDelta: pullRequest.lineDelta, showsFiles: true)
            Divider()
            HStack {
                Button("Open on GitHub", action: onOpen)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .help("Send this pet home until the author pushes new commits")
                Button("Mute", action: onMute)
                    .help("Send this pet home for good")
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}

/// The popover for a pet that stands for several PRs in one stack: a row for each, bottom of the stack first.
struct StackCardView: View {
    let members: [(pullRequest: PullRequest, stackPosition: StackPosition?)]
    let onOpen: (PullRequest) -> Void
    let onDismiss: (PullRequest) -> Void
    let onMute: (PullRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let author = members.first?.pullRequest.author {
                Text("\(members.count) PRs from \(author.displayName ?? author.login.rawValue)'s stack")
                    .font(.headline)
            }
            ForEach(members, id: \.pullRequest.id) { member in
                Divider()
                row(member.pullRequest, stackPosition: member.stackPosition)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private func row(_ pullRequest: PullRequest, stackPosition: StackPosition?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pullRequest.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(pullRequest.shortReference).font(.subheadline).foregroundStyle(.secondary)
                    if let stackPosition { StackBadge(position: stackPosition) }
                    LineDeltaView(lineDelta: pullRequest.lineDelta)
                }
            }
            Spacer(minLength: 0)
            Button("Open") { onOpen(pullRequest) }
            Menu {
                Button("Dismiss Until New Commits") { onDismiss(pullRequest) }
                Button("Mute") { onMute(pullRequest) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Send this PR's part of the pet home")
        }
    }
}

struct LineDeltaView: View {
    let lineDelta: LineDelta
    var showsFiles = false

    var body: some View {
        HStack(spacing: 8) {
            Text("+\(lineDelta.additions)").foregroundStyle(.green)
            Text("−\(lineDelta.deletions)").foregroundStyle(.red)
            if showsFiles {
                Text("\(lineDelta.changedFiles) file\(lineDelta.changedFiles == 1 ? "" : "s")").foregroundStyle(.secondary)
            }
        }
        .font(.system(.callout, design: .monospaced).weight(.semibold))
    }
}

struct StackBadge: View {
    let position: StackPosition

    var body: some View {
        Text(position.description)
            .font(.caption.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.blue.opacity(0.15)))
            .foregroundStyle(.blue)
            .help("Position \(position.index) of \(position.count) in its stack")
    }
}
