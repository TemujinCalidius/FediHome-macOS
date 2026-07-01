import Foundation
import SwiftUI
import FediHomeKit

/// The app's single source of truth for the connection: which instance we're
/// signed into, the authenticated client, and the owner's account. Drives
/// `RootView`'s Connect ↔ Main switch.
@MainActor
final class SessionStore: ObservableObject {
    enum Phase: Equatable { case disconnected, connecting, connected }

    @Published var phase: Phase = .disconnected
    @Published var account: Account?
    @Published var instanceURLString: String
    @Published var errorMessage: String?

    /// The authenticated read client, available once connected.
    private(set) var client: FediHomeClient?

    private let keychain = KeychainStore()
    private let auth = AuthController()

    static let defaultInstance = "https://fedihome.social"
    private static let activeInstanceKey = "activeInstance"

    init() {
        instanceURLString = UserDefaults.standard.string(forKey: Self.activeInstanceKey) ?? Self.defaultInstance
    }

    var isBusy: Bool { phase == .connecting }

    /// On launch, silently restore a stored token if `/api/account` still accepts it.
    func restore() async {
        guard phase == .disconnected, client == nil else { return }
        guard let instance = InstanceURL.normalize(instanceURLString) else { return }
        let key = instance.absoluteString
        guard let data = keychain.load(account: key),
              let stored = try? JSONDecoder().decode(StoredToken.self, from: data) else { return }

        let client = FediHomeClient(baseURL: instance, token: stored.accessToken)
        do {
            let account = try await client.account()
            self.client = client
            self.account = account
            self.phase = .connected
        } catch APIError.unauthorized {
            keychain.delete(account: key) // token revoked/expired
        } catch {
            // Transient (offline, etc.) — keep the token, stay on Connect.
        }
    }

    /// Run the full OAuth flow, persist the token, and confirm identity.
    func connect() async {
        errorMessage = nil
        guard let instance = InstanceURL.normalize(instanceURLString) else {
            errorMessage = "Enter a valid instance URL, e.g. https://fedihome.social"
            return
        }
        phase = .connecting
        do {
            let token = try await auth.authenticate(instance: instance)
            let canonical = InstanceURL.normalize(token.me) ?? instance
            let key = canonical.absoluteString

            let stored = StoredToken(accessToken: token.accessToken, scope: token.scope, me: token.me)
            try keychain.save(JSONEncoder().encode(stored), account: key)
            UserDefaults.standard.set(key, forKey: Self.activeInstanceKey)
            instanceURLString = key

            let client = FediHomeClient(baseURL: canonical, token: token.accessToken)
            let account = try await client.account()
            self.client = client
            self.account = account
            self.phase = .connected
        } catch is AuthError {
            phase = .disconnected // user canceled — no error banner
        } catch {
            phase = .disconnected
            errorMessage = message(for: error)
        }
    }

    /// Called by view models when a read call returns 401.
    func reportUnauthorized() {
        guard phase == .connected else { return }
        disconnect(clearToken: true)
        errorMessage = "Your session expired. Please reconnect."
    }

    func disconnect(clearToken: Bool = true) {
        if clearToken, let instance = InstanceURL.normalize(instanceURLString) {
            keychain.delete(account: instance.absoluteString)
        }
        client = nil
        account = nil
        phase = .disconnected
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
