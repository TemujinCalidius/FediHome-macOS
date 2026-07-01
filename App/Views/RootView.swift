import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if session.phase == .connected {
                MainView()
            } else {
                ConnectView()
            }
        }
        .task { await session.restore() }
    }
}
