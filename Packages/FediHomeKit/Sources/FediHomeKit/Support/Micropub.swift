import Foundation

/// Builds the Micropub h-entry body for `POST /api/micropub`.
///
/// FediHome routing (from `src/app/api/micropub/route.ts`): a `name` (title) makes
/// the post an **article**; without one it's a **note** (which the instance shows in
/// its Journal). Tags are intentionally omitted — FediHome uses `category[0]` as the
/// post *kind*, so sending tags via `category` would hijack the note/article routing.
public enum Micropub {
    public static func hEntry(content: String, title: String?, photoURLs: [String], draft: Bool) -> [String: Any] {
        var properties: [String: Any] = [:]
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContent.isEmpty { properties["content"] = [trimmedContent] }
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            properties["name"] = [title]
        }
        if !photoURLs.isEmpty { properties["photo"] = photoURLs }
        if draft { properties["post-status"] = ["draft"] }
        return ["type": ["h-entry"], "properties": properties]
    }
}
