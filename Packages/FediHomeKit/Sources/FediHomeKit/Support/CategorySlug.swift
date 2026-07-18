import Foundation

/// Client-side category slugification, mirroring the server's `normalizeCategory`
/// (accepts `^[a-z0-9-]+$`, else falls back to `"general"`). The server lowercases and
/// validates but does *not* turn spaces into hyphens, so a raw "Photo walk" would collapse
/// to "general". We pre-hyphenate so free-typed categories survive: lowercase; collapse
/// each run of non-`[a-z0-9]` into a single `-`; strip leading/trailing `-`. Non-ASCII is
/// dropped, matching the server's own rejection.
public enum CategorySlug {
    public static func slugify(_ raw: String) -> String {
        var slug = ""
        var lastWasHyphen = false
        for scalar in raw.lowercased().unicodeScalars {
            if (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9") {
                slug.unicodeScalars.append(scalar)
                lastWasHyphen = false
            } else if !slug.isEmpty && !lastWasHyphen {
                slug.append("-")
                lastWasHyphen = true
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug
    }
}
