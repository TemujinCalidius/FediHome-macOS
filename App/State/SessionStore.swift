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
    /// The connected instance's base URL, for resolving relative media/embed paths.
    @Published private(set) var baseURL: URL?

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

    /// The base URL to resolve media against — the connected instance, or a best-effort
    /// normalization of the entered URL before connecting.
    var resolvedBaseURL: URL {
        baseURL ?? InstanceURL.normalize(instanceURLString) ?? URL(string: Self.defaultInstance)!
    }

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
            self.baseURL = instance
            self.account = account
            self.phase = .connected
        } catch APIError.unauthorized {
            keychain.delete(account: key) // token revoked/expired
        } catch {
            // Transient (offline, etc.) — keep the token, stay on Connect.
        }
    }

    /// Run the full OAuth flow, then hand off to `establish` to validate + persist.
    func connect() async {
        errorMessage = nil
        guard let instance = InstanceURL.normalize(instanceURLString) else {
            errorMessage = "Enter a valid instance URL, e.g. https://fedihome.social"
            return
        }
        phase = .connecting
        do {
            let token = try await auth.authenticate(instance: instance)
            // OAuth already tells us the canonical instance (token.me); dial that host.
            let dial = InstanceURL.normalize(token.me) ?? instance
            try await establish(dialURL: dial, accessToken: token.accessToken, scope: token.scope)
        } catch is AuthError {
            phase = .disconnected // user canceled — no error banner
        } catch {
            phase = .disconnected
            errorMessage = message(for: error)
        }
    }

    /// Sign in by pasting an access token (FediHome#60) — no OAuth browser round-trip.
    /// Validation happens in `establish` via `account()`. Scope is enforced server-side
    /// and never read back, so we store `""`.
    func connectWithToken(_ accessToken: String) async {
        errorMessage = nil
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            errorMessage = "Paste an access token."
            return
        }
        guard let instance = InstanceURL.normalize(instanceURLString) else {
            errorMessage = "Enter a valid instance URL, e.g. https://fedihome.social"
            return
        }
        phase = .connecting
        do {
            try await establish(dialURL: instance, accessToken: token, scope: "")
        } catch APIError.unauthorized {
            phase = .disconnected
            errorMessage = "That token was rejected. Check the token and your instance URL."
        } catch {
            phase = .disconnected
            errorMessage = message(for: error)
        }
    }

    /// Shared connect tail for both sign-in paths: dial `dialURL` with `accessToken`,
    /// validate the token and fetch identity via `account()` (401 → `APIError.unauthorized`),
    /// persist under the canonical instance key, and flip to `.connected`. Throws on failure;
    /// the caller owns `phase`/error handling. Validates *before* persisting, so a rejected
    /// token never leaves a stale entry in the Keychain.
    private func establish(dialURL: URL, accessToken: String, scope: String) async throws {
        let client = FediHomeClient(baseURL: dialURL, token: accessToken)
        let account = try await client.account()          // validates the token; 401 → .unauthorized
        let canonical = InstanceURL.normalize(account.me) ?? dialURL
        let key = canonical.absoluteString

        let stored = StoredToken(accessToken: accessToken, scope: scope, me: account.me)
        try keychain.save(JSONEncoder().encode(stored), account: key)
        UserDefaults.standard.set(key, forKey: Self.activeInstanceKey)
        instanceURLString = key

        self.client = client
        self.baseURL = canonical
        self.account = account
        self.phase = .connected
    }

    /// Applies an `update_profile` response to the current account in place, so the UI
    /// reflects exactly what the server stored without waiting on (or depending on) a refetch.
    func applyProfile(_ profile: ProfileUpdateResult.Profile) {
        account = account?.applying(profile)
    }

    /// Re-fetches the account (e.g. after editing the profile) so the UI reflects
    /// the new avatar/name/bio everywhere.
    func refreshAccount() async {
        guard let client else { return }
        do {
            account = try await client.account()
        } catch APIError.unauthorized {
            reportUnauthorized()
        } catch {
            // Transient — keep showing the last-known account.
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
        baseURL = nil
        phase = .disconnected
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
