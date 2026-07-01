import SwiftUI
import FediHomeKit

struct FeedView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = FeedViewModel()
    @State private var replyTarget: FediPost?
    @State private var threadTarget: FediPost?

    var body: some View {
        content
            .navigationTitle("Feed")
            .toolbar {
                Button {
                    Task { await model.loadFirst(session: session) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help("Refresh")
            }
            .task {
                if model.posts.isEmpty { await model.loadFirst(session: session) }
            }
            .sheet(item: $replyTarget) { target in
                ReplyComposerView(post: target) { text, crosspost in
                    let ok = await model.sendReply(to: target, text: text, crosspostBluesky: crosspost, session: session)
                    if ok { await model.loadCounts(target, session: session) } // reflect the new reply count
                    return ok
                }
            }
            .sheet(item: $threadTarget) { target in
                ThreadView(rootPost: target, baseURL: session.resolvedBaseURL)
            }
            .alert("Action failed", isPresented: actionErrorBinding) {
                Button("OK") { model.actionError = nil }
            } message: {
                Text(model.actionError ?? "")
            }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.posts.isEmpty {
            ProgressView("Loading your feed…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage, model.posts.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load the feed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await model.loadFirst(session: session) } }
            }
        } else if model.posts.isEmpty {
            ContentUnavailableView("No posts yet", systemImage: "tray",
                                   description: Text("Your timeline is empty."))
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(model.posts) { post in
                PostRowView(post: post, baseURL: session.resolvedBaseURL, actions: actions(for: post))
                    .task { await model.loadMoreIfNeeded(current: post, session: session) }
            }
            if model.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Spacer()
                }
            }
        }
        .listStyle(.inset)
        .refreshable { await model.loadFirst(session: session) }
    }

    private func actions(for post: FediPost) -> PostRowActions {
        PostRowActions(
            onToggleLike: { Task { await model.toggleLike(post, session: session) } },
            onToggleBoost: { Task { await model.toggleBoost(post, session: session) } },
            onReply: { replyTarget = post },
            onLoadCounts: { Task { await model.loadCounts(post, session: session) } },
            onViewThread: { threadTarget = post }
        )
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } })
    }
}
