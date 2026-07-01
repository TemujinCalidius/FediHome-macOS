import SwiftUI
import FediHomeKit

/// A sheet to compose a reply. `onSend` returns whether the send succeeded, so the
/// sheet only dismisses on success.
struct ReplyComposerView: View {
    let post: FediPost
    let onSend: (_ text: String, _ crosspostBluesky: Bool) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var crosspostBluesky = false
    @State private var isSending = false

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reply to \(post.authorName)")
                .font(.headline)
            Text(post.fediHandle)
                .font(.caption).foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 120)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))

            Toggle("Also post to Bluesky", isOn: $crosspostBluesky)
                .toggleStyle(.checkbox)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task {
                        isSending = true
                        let ok = await onSend(text, crosspostBluesky)
                        isSending = false
                        if ok { dismiss() }
                    }
                } label: {
                    if isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Reply")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSend)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
