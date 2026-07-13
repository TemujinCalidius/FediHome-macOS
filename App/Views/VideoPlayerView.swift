import SwiftUI
import AVKit

/// Inline player for a direct video file. Streaming *page* URLs (YouTube/Vimeo) are
/// handled separately as link cards — they can't play in an `AVPlayer`.
///
/// Backed by AppKit's `AVPlayerView` (via `NSViewRepresentable`) rather than SwiftUI's
/// `VideoPlayer`: the SwiftUI wrapper (`_AVKit_SwiftUI`) crashes during Swift generic
/// metadata instantiation when built into a `List` row on some macOS/toolchain
/// combinations. `AVPlayerView` is the stabler, more capable native player anyway
/// (inline controls, full-screen, Picture-in-Picture).
struct VideoPlayerView: View {
    let url: URL

    var body: some View {
        AVPlayerViewRepresentable(url: url)
            .frame(maxWidth: 460, minHeight: 240, maxHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AVPlayerViewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        view.player = AVPlayer(url: url)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Only swap the player when the URL actually changes (don't restart playback).
        let current = (nsView.player?.currentItem?.asset as? AVURLAsset)?.url
        if current != url {
            nsView.player = AVPlayer(url: url)
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}
