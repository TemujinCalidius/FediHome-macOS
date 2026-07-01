import SwiftUI
import AVKit

/// Inline player for a direct video file. Streaming *page* URLs (YouTube/Vimeo) are
/// handled separately as link cards — they can't play in an `AVPlayer`.
struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .frame(maxWidth: 460, minHeight: 240, maxHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onAppear { if player == nil { player = AVPlayer(url: url) } }
            .onDisappear { player?.pause() }
    }
}
