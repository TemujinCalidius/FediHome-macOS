import SwiftUI
import FediHomeKit

struct FeedView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = FeedViewModel()

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
                PostRowView(post: post)
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
}
