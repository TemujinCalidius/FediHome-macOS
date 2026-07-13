import SwiftUI
import FediHomeKit

/// Callbacks a `PostRowView` invokes. `onViewThread` is nil inside a thread (no
/// recursion) and hidden when there are no replies.
struct PostRowActions {
    var onToggleLike: () -> Void = {}
    var onToggleBoost: () -> Void = {}
    var onReply: () -> Void = {}
    var onLoadCounts: () -> Void = {}
    var onViewThread: (() -> Void)?
    /// Present only on the owner's own posts/replies (thread view).
    var onEdit: (() -> Void)?
}

/// The reply / boost / like / share row under a post, plus lazy count loading and a
/// "View thread" affordance.
struct InteractionBar: View {
    let post: FediPost
    let actions: PostRowActions

    var body: some View {
        HStack(spacing: 20) {
            actionButton("bubble.right", count: post.replyCount, active: false, action: actions.onReply)
            actionButton("arrow.2.squarepath", count: post.boostCount, active: post.boostedByMe, action: actions.onToggleBoost)
            actionButton("heart", count: post.likeCount, active: post.likedByMe, action: actions.onToggleLike)

            if let shareURL = post.shareURL {
                ShareLink(item: shareURL) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.plain)
            }

            if let onEdit = actions.onEdit {
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .buttonStyle(.plain)
                    .help("Edit")
            }

            Spacer(minLength: 8)

            if post.countsFetchedAt == nil {
                Button("Load counts", action: actions.onLoadCounts)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            }
            if let onViewThread = actions.onViewThread {
                // Reply counts are lazy (nil until "Load counts"), so always offer the
                // thread — opening a post with no replies just shows the post itself.
                Button("View thread", action: onViewThread)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    private func actionButton(_ symbol: String, count: Int?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: active ? "\(symbol).fill" : symbol)
                if let count { Text(String(count)) }
            }
            .foregroundStyle(active ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
