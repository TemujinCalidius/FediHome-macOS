import Foundation
import FediHomeKit

/// A conversation = all messages sharing a `conversationKey`, plus its read state.
struct DMConversation: Identifiable, Equatable {
    let key: String
    let messages: [DirectMessage]   // ascending by createdAt
    let lastReadAt: Date?

    var id: String { key }
    var isFedi: Bool { messages.first?.isFedi ?? key.hasPrefix("fedi:") }
    var latest: DirectMessage? { messages.last }

    /// The first message we received in this thread identifies the other party;
    /// for an all-outgoing thread, fall back to the actorUri in the key.
    private var partnerMessage: DirectMessage? { messages.first { !$0.isOutgoing } }
    var partnerName: String { partnerMessage?.senderDisplayName ?? partnerHandle }
    var partnerHandle: String { partnerMessage?.senderHandle ?? String(key.drop(while: { $0 != ":" }).dropFirst()) }
    var partnerAvatar: String? { partnerMessage?.senderAvatar }
    var partnerUri: String? {
        partnerMessage?.senderUri ?? (key.hasPrefix("fedi:") ? String(key.dropFirst("fedi:".count)) : nil)
    }

    var unread: Bool {
        guard let latest, !latest.isOutgoing else { return false }
        guard let lastReadAt else { return true }
        return latest.createdAt > lastReadAt
    }
}

@MainActor
final class DirectMessagesViewModel: ObservableObject {
    @Published private(set) var conversations: [DMConversation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var actionError: String?

    func conversation(key: String) -> DMConversation? {
        conversations.first { $0.key == key }
    }

    func load(session: SessionStore) async {
        guard let client = session.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            conversations = Self.group(try await client.directMessages())
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Reply into an existing fediverse conversation.
    func reply(to conversation: DMConversation, text: String, session: SessionStore) async -> Bool {
        guard let client = session.client, let uri = conversation.partnerUri else { return false }
        do {
            try await client.sendDM(content: text, recipientUri: uri, reply: true)
            await load(session: session)
            return true
        } catch APIError.unauthorized {
            session.reportUnauthorized(); return false
        } catch {
            actionError = Self.message(for: error); return false
        }
    }

    /// Start a new fediverse conversation by handle.
    func startConversation(handle: String, text: String, session: SessionStore) async -> Bool {
        guard let client = session.client else { return false }
        guard let normalized = PeopleViewModel.normalizedHandle(handle) else {
            actionError = "Enter a handle like @name@server.social"; return false
        }
        do {
            try await client.sendDM(content: text, recipientHandle: normalized, reply: false)
            await load(session: session)
            return true
        } catch APIError.unauthorized {
            session.reportUnauthorized(); return false
        } catch {
            actionError = Self.message(for: error); return false
        }
    }

    func markRead(_ conversation: DMConversation, session: SessionStore) async {
        guard let client = session.client, conversation.unread else { return }
        do {
            try await client.markDMRead(conversationKey: conversation.key)
            await load(session: session)
        } catch {
            // best-effort; leave unread if it fails
        }
    }

    static func group(_ response: DirectMessagesResponse) -> [DMConversation] {
        Dictionary(grouping: response.messages, by: \.conversationKey)
            .map { key, msgs in
                DMConversation(key: key,
                               messages: msgs.sorted { $0.createdAt < $1.createdAt },
                               lastReadAt: response.readState[key])
            }
            .sorted { ($0.latest?.createdAt ?? .distantPast) > ($1.latest?.createdAt ?? .distantPast) }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
