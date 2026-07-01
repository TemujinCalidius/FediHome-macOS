import SwiftUI

@main
struct FediHomeApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var imageViewer = ImageViewerModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(imageViewer)
                .overlay { ImageViewerOverlay().environmentObject(imageViewer) }
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 980, height: 680)
    }
}
