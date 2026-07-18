import SwiftUI
import FediHomeKit

/// Compose gallery-category input: free-type a new category **or** pick a known one from a
/// menu. The bound `text` is the raw user string (the view model slugifies it at send time).
/// A caption resolves a typed value to its known label, and otherwise previews the slug the
/// server will store — so slugification is never a silent surprise.
struct CategoryField: View {
    @Binding var text: String
    let options: [MediaCategory]

    private var slug: String { CategorySlug.slugify(text) }
    private var knownLabel: String? { options.first { $0.slug == slug }?.label }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                TextField("Category (optional)", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .font(.callout)
                if !options.isEmpty {
                    Menu {
                        ForEach(options) { option in
                            Button(option.label) { text = option.slug }
                        }
                    } label: {
                        Image(systemName: "chevron.down.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Choose a known category")
                }
            }
            if let knownLabel {
                Label(knownLabel, systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !slug.isEmpty, slug != text {
                Text("Posts as “\(slug)”")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
