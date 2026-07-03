import SwiftUI
import FediHomeKit

/// A compact reply composer pinned to the bottom of the thread (avoids a fragile
/// sheet-inside-a-sheet). Prefilled with the target's @handle, and offers a menu to
/// @-mention other thread participants. `onSend` returns success so the caller can
/// clear + refresh.
struct InlineReplyBar: View {
    enum Mode { case reply, edit }

    let post: FediPost
    var mode: Mode = .reply
    /// Other participants' handles (e.g. `@user@domain`) offered in the mention menu.
    var participants: [String] = []
    let onCancel: () -> Void
    let onSend: (_ text: String, _ crosspostBluesky: Bool) async -> Bool

    @State private var text: String
    @State private var crosspostBluesky = false
    @State private var isSending = false
    @FocusState private var focused: Bool

    init(post: FediPost,
         mode: Mode = .reply,
         participants: [String] = [],
         onCancel: @escaping () -> Void,
         onSend: @escaping (_ text: String, _ crosspostBluesky: Bool) async -> Bool) {
        self.post = post
        self.mode = mode
        self.participants = participants
        self.onCancel = onCancel
        self.onSend = onSend
        switch mode {
        case .reply:
            // Address the reply to the target; the server strips a duplicate leading handle.
            _text = State(initialValue: post.replyMentionHandle + " ")
        case .edit:
            // Editing our own reply: start from its current text.
            _text = State(initialValue: post.content)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: mode == .edit ? "pencil" : "arrowshape.turn.up.left.fill").font(.caption2)
                Text(mode == .edit ? "Editing your reply" : "Replying to \(post.authorName)").font(.caption)
                Spacer()
                if mode == .reply, !participants.isEmpty {
                    Menu {
                        ForEach(participants, id: \.self) { handle in
                            Button(handle) { insertMention(handle) }
                        }
                    } label: {
                        Image(systemName: "at")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Mention someone in the thread")
                }
                Button(action: onCancel) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .help("Cancel reply")
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 44, maxHeight: 110)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                    .focused($focused)

                Button {
                    Task {
                        isSending = true
                        _ = await onSend(text, crosspostBluesky)
                        isSending = false
                    }
                } label: {
                    if isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: mode == .edit ? "checkmark" : "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
                .help(mode == .edit ? "Save changes" : "Send reply")
            }

            if mode == .reply {
                Toggle("Also post to Bluesky", isOn: $crosspostBluesky)
                    .font(.caption)
                    .toggleStyle(.checkbox)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .onAppear { focused = true }
    }

    private func insertMention(_ handle: String) {
        if !text.isEmpty, !text.hasSuffix(" ") { text += " " }
        text += handle + " "
        focused = true
    }
}
