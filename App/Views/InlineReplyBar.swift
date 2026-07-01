import SwiftUI
import FediHomeKit

/// A compact reply composer pinned to the bottom of the thread (avoids a fragile
/// sheet-inside-a-sheet). `onSend` returns success so the caller can clear + refresh.
struct InlineReplyBar: View {
    let post: FediPost
    let onCancel: () -> Void
    let onSend: (_ text: String, _ crosspostBluesky: Bool) async -> Bool

    @State private var text = ""
    @State private var crosspostBluesky = false
    @State private var isSending = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill").font(.caption2)
                Text("Replying to \(post.authorName)").font(.caption)
                Spacer()
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
                        Image(systemName: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
            }

            Toggle("Also post to Bluesky", isOn: $crosspostBluesky)
                .font(.caption)
                .toggleStyle(.checkbox)
        }
        .padding(10)
        .background(.regularMaterial)
        .onAppear { focused = true }
    }
}
