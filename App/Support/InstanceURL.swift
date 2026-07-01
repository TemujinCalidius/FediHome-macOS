import Foundation

/// Normalizes user-entered instance text into a canonical `https://host[:port]`
/// URL — forcing HTTPS and stripping any path, query, fragment, or trailing slash.
enum InstanceURL {
    static func normalize(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text),
              let host = components.host, host.contains(".")
        else { return nil }
        components.scheme = "https"
        components.path = ""
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil
        return components.url
    }
}
