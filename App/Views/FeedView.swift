import SwiftUI
import FediHomeKit

struct FeedView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @StateObject private var model = FeedViewModel()
    @State private var sheet: FeedSheet?

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
            .onChange(of: navigator.refreshTick) { Task { await model.loadFirst(session: session) } }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .reply(let target):
                    ReplyComposerView(post: target) { text, crosspost in
                        let ok = await model.sendReply(to: target, text: text, crosspostBluesky: crosspost, session: session)
                        if ok { await model.loadCounts(target, session: session) } // reflect the new reply count
                        return ok
                    }
                case .thread(let target):
                    ThreadView(rootPost: target, baseURL: session.resolvedBaseURL)
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
            onReply: { sheet = .reply(post) },
            onLoadCounts: { Task { await model.loadCounts(post, session: session) } },
            onViewThread: { sheet = .thread(post) }
        )
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } })
    }
}

/// A single sheet destination for the feed (reply composer or thread view) — one
/// `.sheet` modifier, since SwiftUI doesn't reliably present two on the same view.
private enum FeedSheet: Identifiable {
    case reply(FediPost)
    case thread(FediPost)

    var id: String {
        switch self {
        case .reply(let post): return "reply-\(post.id)"
        case .thread(let post): return "thread-\(post.id)"
        }
    }
}
