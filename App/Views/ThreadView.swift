import SwiftUI
import FediHomeKit

/// A sheet showing the full conversation for a post (`GET /api/conversation`), with
/// the same interactions as the feed plus an inline reply bar. Tapping reply on any
/// comment targets that comment; a default affordance replies to the thread root.
struct ThreadView: View {
    let rootPost: FediPost
    let baseURL: URL

    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = ThreadViewModel()
    @StateObject private var imageViewer = ImageViewerModel()
    @Environment(\.dismiss) private var dismiss
    @State private var replyTarget: FediPost?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Thread")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { replyBar }
        }
        .frame(minWidth: 540, minHeight: 520)
        .environmentObject(imageViewer)
        .overlay { ImageViewerOverlay().environmentObject(imageViewer) }
        .task { await model.load(rootPost: rootPost, session: session) }
        .alert("Action failed", isPresented: actionErrorBinding) {
            Button("OK") { model.actionError = nil }
        } message: {
            Text(model.actionError ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.posts.isEmpty {
            ProgressView("Loading thread…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage, model.posts.isEmpty {
            ContentUnavailableView("Couldn't load thread",
                                   systemImage: "bubble.left.and.exclamationmark.bubble.right",
                                   description: Text(error))
        } else {
            List(model.posts) { post in
                PostRowView(post: post, baseURL: baseURL, actions: actions(for: post))
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder private var replyBar: some View {
        if !model.posts.isEmpty {
            if let target = replyTarget {
                InlineReplyBar(
                    post: target,
                    participants: participants(excluding: target),
                    onCancel: { replyTarget = nil },
                    onSend: { text, crosspost in
                        let ok = await model.sendReply(to: target, text: text,
                                                       crosspostBluesky: crosspost, session: session)
                        if ok {
                            replyTarget = nil
                            await model.load(rootPost: rootPost, session: session) // show the new reply
                        }
                        return ok
                    }
                )
                .id(target.id) // reset the editor when the target changes
            } else {
                Button { replyTarget = rootPost } label: {
                    Label("Reply to this thread", systemImage: "arrowshape.turn.up.left")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
        }
    }

    /// Unique handles of other people in the thread (excludes our own posts and the
    /// person already being addressed), for the reply bar's mention menu.
    private func participants(excluding target: FediPost) -> [String] {
        var seen: Set<String> = [target.fediHandle]
        var result: [String] = []
        for post in model.posts where !post.isOutgoing {
            if seen.insert(post.fediHandle).inserted { result.append(post.fediHandle) }
        }
        return result
    }

    private func actions(for post: FediPost) -> PostRowActions {
        PostRowActions(
            onToggleLike: { Task { await model.toggleLike(post, session: session) } },
            onToggleBoost: { Task { await model.toggleBoost(post, session: session) } },
            onReply: { replyTarget = post },
            onLoadCounts: { Task { await model.loadCounts(post, session: session) } },
            onViewThread: nil
        )
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } })
    }
}
