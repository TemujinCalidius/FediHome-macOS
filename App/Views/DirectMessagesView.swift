import SwiftUI
import FediHomeKit

struct DirectMessagesView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @EnvironmentObject private var badge: BadgeModel
    @StateObject private var model = DirectMessagesViewModel()
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Messages")
                .toolbar {
                    Button { showingNew = true } label: { Image(systemName: "square.and.pencil") }
                        .help("New message")
                    Button { Task { await model.load(session: session) } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(model.isLoading)
                        .help("Refresh")
                }
        }
        .task {
            // Poll while the Messages section is open so incoming DMs appear without a manual refresh.
            while !Task.isCancelled {
                await model.load(session: session)
                badge.setUnreadMessages(model.conversations.filter(\.unread).count)
                try? await Task.sleep(for: .seconds(20))
            }
        }
        .onChange(of: navigator.refreshTick) { Task { await model.load(session: session) } }
        .sheet(isPresented: $showingNew) {
            NewDMView { handle, text in
                await model.startConversation(handle: handle, text: text, session: session)
            }
        }
        .alert("Message failed", isPresented: Binding(
            get: { model.actionError != nil },
            set: { if !$0 { model.actionError = nil } })) {
            Button("OK") { model.actionError = nil }
        } message: { Text(model.actionError ?? "") }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.conversations.isEmpty {
            TopAlignedState { ProgressView() }
        } else if let error = model.errorMessage, model.conversations.isEmpty {
            TopAlignedState {
                ContentUnavailableView("Couldn't load messages", systemImage: "exclamationmark.bubble", description: Text(error))
            }
        } else if model.conversations.isEmpty {
            TopAlignedState {
                ContentUnavailableView("No messages", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("Start a conversation with the compose button."))
            }
        } else {
            List(model.conversations) { conversation in
                NavigationLink {
                    DMThreadView(conversationKey: conversation.key, model: model, baseURL: session.resolvedBaseURL)
                } label: {
                    DMConversationRow(conversation: conversation, baseURL: session.resolvedBaseURL)
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct DMConversationRow: View {
    let conversation: DMConversation
    let baseURL: URL

    /// Plain-text preview (DM content carries HTML; strip it for the list snippet).
    private var snippet: String {
        guard let latest = conversation.latest else { return "" }
        let source = (latest.contentHtml?.isEmpty == false) ? latest.contentHtml! : latest.content
        return FediHTML.plainText(from: source)
    }

    var body: some View {
        HStack(spacing: 10) {
            AsyncAvatar(url: MediaURL.resolve(conversation.partnerAvatar ?? "", relativeTo: baseURL), size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(conversation.partnerName).font(.callout).bold().lineLimit(1)
                Text(snippet).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let date = conversation.latest?.createdAt {
                    Text(date, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.tertiary)
                }
                if conversation.unread {
                    Circle().fill(.tint).frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DMThreadView: View {
    let conversationKey: String
    @ObservedObject var model: DirectMessagesViewModel
    @EnvironmentObject private var session: SessionStore
    let baseURL: URL

    @State private var draft = ""
    @State private var isSending = false

    private var conversation: DMConversation? { model.conversation(key: conversationKey) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversation?.messages ?? []) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onAppear { scrollToBottom(proxy) }
                .onChange(of: conversation?.messages.count) { scrollToBottom(proxy) }
            }
            Divider()
            composer
        }
        .navigationTitle(conversation?.partnerName ?? "Message")
        .task(id: conversationKey) {
            if let conversation { await model.markRead(conversation, session: session) }
        }
    }

    @ViewBuilder private var composer: some View {
        if conversation?.isFedi == false {
            Text("Replying to Bluesky messages isn't supported yet.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(10).background(.regularMaterial)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit(send)
                Button(action: send) {
                    if isSending { ProgressView().controlSize(.small) } else { Image(systemName: "paperplane.fill") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(10)
            .background(.regularMaterial)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = conversation?.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    private func send() {
        guard let conversation, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft
        Task {
            isSending = true
            let ok = await model.reply(to: conversation, text: text, session: session)
            isSending = false
            if ok { draft = "" }
        }
    }
}

private struct MessageBubble: View {
    let message: DirectMessage

    /// DMs arrive with HTML in `content`; render it cleanly like posts.
    private var rendered: AttributedString {
        let source = (message.contentHtml?.isEmpty == false) ? message.contentHtml! : message.content
        let attributed = FediHTML.attributedString(from: source)
        return attributed.characters.isEmpty ? AttributedString(message.content) : attributed
    }

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 40) }
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 2) {
                Text(rendered)
                    .tint(message.isOutgoing ? .white : .accentColor)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(message.isOutgoing ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(message.isOutgoing ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            if !message.isOutgoing { Spacer(minLength: 40) }
        }
    }
}

private struct NewDMView: View {
    let onSend: (_ handle: String, _ text: String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""
    @State private var text = ""
    @State private var isSending = false

    private var canSend: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Message").font(.headline)
            TextField("@name@server.social", text: $handle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $text)
                .font(.body).frame(minHeight: 100)
                .padding(4).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button {
                    Task {
                        isSending = true
                        let ok = await onSend(handle, text)
                        isSending = false
                        if ok { dismiss() }
                    }
                } label: {
                    if isSending { ProgressView().controlSize(.small) } else { Text("Send") }
                }
                .buttonStyle(.borderedProminent).disabled(!canSend).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 440)
    }
}
