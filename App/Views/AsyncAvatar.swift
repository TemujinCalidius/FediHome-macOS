import SwiftUI

/// A rounded avatar backed by `AsyncImage`, with a graceful placeholder.
struct AsyncAvatar: View {
    let url: URL?
    var size: CGFloat = 44

    private var cornerRadius: CGFloat { size * 0.22 }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                placeholder.overlay(ProgressView().controlSize(.small))
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: size * 0.4))
            )
    }
}
