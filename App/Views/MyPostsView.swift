import SwiftUI
import FediHomeKit

/// The owner's content manager: every post on the instance (published, scheduled,
/// drafts) with type filters, paging, open-in-browser, and delete/cancel.
struct MyPostsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @StateObject private var model = MyPostsViewModel()
    @State private var pendingDelete: OwnPost?

    var body: some View {
        VStack(spacing: 0) {
            filters
            content
        }
        .navigationTitle("My Posts")
        .toolbar {
            Menu {
                Picker("Type", selection: $model.typeFilter) {
                    ForEach(MyPostsViewModel.TypeFilter.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .help("Filter by type")
            Button {
                Task { await model.load(session: session) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            .help("Refresh")
        }
        .task { if model.posts.isEmpty { await model.load(session: session) } }
        .onChange(of: navigator.refreshTick) { Task { await model.load(session: session) } }
        .onChange(of: model.statusFilter) { Task { await model.load(session: session) } }
        .onChange(of: model.typeFilter) { Task { await model.load(session: session) } }
        .confirmationDialog(deleteTitle, isPresented: deleteBinding, titleVisibility: .visible) {
            Button(pendingDelete?.status == .scheduled ? "Cancel & delete" : "Delete", role: .destructive) {
                if let post = pendingDelete {
                    Task { await model.delete(post, session: session) }
                }
                pendingDelete = nil
            }
            Button("Keep", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete?.status == .scheduled
                 ? "This removes the scheduled post — it won't publish."
                 : "This deletes the post from your instance and federates the removal.")
        }
    }

    private var filters: some View {
        Picker("", selection: $model.statusFilter) {
            ForEach(MyPostsViewModel.StatusFilter.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(12)
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.posts.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage, model.posts.isEmpty {
            ContentUnavailableView("Couldn't load your posts", systemImage: "tray",
                                   description: Text(error))
        } else if model.posts.isEmpty {
            ContentUnavailableView("Nothing here", systemImage: "tray",
                                   description: Text(model.statusFilter.emptyMessage))
        } else {
            VStack(spacing: 0) {
                if let error = model.errorMessage {
                    // Failures with content on screen (delete / load-more) must not be silent.
                    HStack(spacing: 8) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red).lineLimit(2)
                        Spacer()
                        Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).font(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.red.opacity(0.08))
                }
                List(model.posts) { post in
                    MyPostRow(post: post, baseURL: session.resolvedBaseURL) {
                        pendingDelete = post
                    }
                    .task { await model.loadMoreIfNeeded(current: post, session: session) }
                }
                .listStyle(.inset)
                .refreshable { await model.load(session: session) }
            }
        }
    }

    private var deleteTitle: String {
        "Delete “\(pendingDelete?.displayTitle ?? "post")”?"
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
}

private struct MyPostRow: View {
    let post: OwnPost
    let baseURL: URL
    let onDelete: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: typeSymbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(post.displayTitle).font(.callout).bold().lineLimit(1)
                    statusBadge
                }
                if let excerpt = post.excerpt, !excerpt.isEmpty, post.title != nil {
                    Text(excerpt).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 10) {
                    if post.status == .scheduled, let when = post.scheduledFor {
                        Label(when.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    } else {
                        Text(post.publishedAt, format: .relative(presentation: .named))
                    }
                    if post.counts.likes > 0 { Label("\(post.counts.likes)", systemImage: "heart") }
                    if post.counts.boosts > 0 { Label("\(post.counts.boosts)", systemImage: "arrow.2.squarepath") }
                    mediaSummary
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Menu {
                if post.status == .published, let url = post.webURL(relativeTo: baseURL) {
                    Button("Open in browser") { openURL(url) }
                }
                Button(post.status == .scheduled ? "Cancel & delete…" : "Delete…",
                       role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusBadge: some View {
        switch post.status {
        case .published:
            EmptyView()
        case .scheduled:
            badge("Scheduled", color: .orange)
        case .draft:
            badge("Draft", color: .secondary)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    @ViewBuilder private var mediaSummary: some View {
        if post.media.photos > 0 { Label("\(post.media.photos)", systemImage: "photo") }
        if post.media.videos > 0 { Label("\(post.media.videos)", systemImage: "play.rectangle") }
        if post.media.audio > 0 { Label("\(post.media.audio)", systemImage: "waveform") }
    }

    private var typeSymbol: String {
        switch post.type {
        case "article": return "doc.richtext"
        case "photo": return "photo"
        case "video": return "play.rectangle"
        case "audio": return "waveform"
        case "journal": return "text.quote"
        default: return "note.text"
        }
    }
}
