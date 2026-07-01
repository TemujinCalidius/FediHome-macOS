import SwiftUI
import FediHomeKit

/// A recognized video embed: shows a poster + ▶ that swaps to the inline web player
/// on click. An "open in browser" affordance is always available.
struct VideoEmbedView: View {
    let embedURL: URL
    let pageURL: URL
    var posterURL: URL?
    var title: String?

    @State private var playing = false

    var body: some View {
        Group {
            if playing {
                WebVideoPlayer(url: embedURL)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                poster
            }
        }
        .frame(maxWidth: 480)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private var poster: some View {
        ZStack {
            if let posterURL {
                AsyncImage(url: posterURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.black.opacity(0.85))
                }
            } else {
                Rectangle().fill(.black.opacity(0.85))
            }

            Rectangle().fill(.black.opacity(0.25))

            Image(systemName: "play.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(radius: 8)

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    if let title, !title.isEmpty {
                        Text(title).font(.caption).bold().foregroundStyle(.white).lineLimit(1)
                    }
                    Spacer()
                    Link(destination: pageURL) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .help("Open in browser")
                }
                .padding(8)
                .background(.black.opacity(0.35))
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture { playing = true }
    }
}
