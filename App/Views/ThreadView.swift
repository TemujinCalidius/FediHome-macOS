import SwiftUI
import FediHomeKit

/// A sheet showing the full conversation for a post (`GET /api/conversation`), with
/// the same interactions as the feed (no nested "View thread").
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
        }
        .frame(minWidth: 540, minHeight: 520)
        .environmentObject(imageViewer)
        .overlay { ImageViewerOverlay().environmentObject(imageViewer) }
        .task { await model.load(rootPost: rootPost, session: session) }
        .sheet(item: $replyTarget) { target in
            ReplyComposerView(post: target) { text, crosspost in
                await model.sendReply(to: target, text: text, crosspostBluesky: crosspost, session: session)
            }
        }
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
