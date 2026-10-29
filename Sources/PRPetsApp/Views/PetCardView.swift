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
