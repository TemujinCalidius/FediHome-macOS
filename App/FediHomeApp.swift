import SwiftUI

@main
struct FediHomeApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 980, height: 680)
    }
}
