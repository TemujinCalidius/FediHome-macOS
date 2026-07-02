import XCTest
@testable import FediHomeKit

final class DirectMessagesTests: XCTestCase {
    func testDecodesMessagesAndReadState() throws {
        let json = Data("""
        { "messages": [
            { "id": "m1", "source": "fedi", "senderUri": "https://m.social/users/a",
              "senderHandle": "@a@m.social", "senderName": "Alice", "senderAvatar": null,
              "content": "hi there", "contentHtml": "<p>hi there</p>", "apId": "https://m.social/dm/1",
              "conversationKey": "fedi:https://m.social/users/a", "isOutgoing": false,
              "deliveredAt": null, "deliveryError": null, "createdAt": "2026-07-02T10:00:00Z" },
            { "id": "m2", "source": "fedi", "senderUri": "https://me/ap/actor",
              "senderHandle": "@me@home", "senderName": "Me", "senderAvatar": null,
              "content": "hello back", "contentHtml": null, "apId": "https://me/dm/2",
              "conversationKey": "fedi:https://m.social/users/a", "isOutgoing": true,
              "deliveredAt": "2026-07-02T10:01:00Z", "deliveryError": null, "createdAt": "2026-07-02T10:01:00Z" }
          ],
          "readState": { "fedi:https://m.social/users/a": "2026-07-02T09:00:00Z" } }
        """.utf8)
        let response = try JSONDecoder.fediHome.decode(DirectMessagesResponse.self, from: json)
        XCTAssertEqual(response.messages.count, 2)
        XCTAssertEqual(response.readState["fedi:https://m.social/users/a"],
                       FediDate.parse("2026-07-02T09:00:00Z"))
        XCTAssertTrue(response.messages[0].isFedi)
        XCTAssertTrue(response.messages[1].isOutgoing)
        XCTAssertEqual(response.messages[0].senderDisplayName, "Alice")
    }
}
