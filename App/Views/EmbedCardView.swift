import SwiftUI
import FediHomeKit

/// A link-preview card for a post's single-link embed (image + title + description + site).
struct EmbedCardView: View {
    let card: FediPost.EmbedCard

    var body: some View {
        Link(destination: card.url) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = card.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let title = card.title, !title.isEmpty {
                        Text(title).font(.callout).bold().lineLimit(2)
                    }
                    if let description = card.description, !description.isEmpty {
                        Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Text(card.displaySite).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 460, alignment: .leading)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}

/// A compact "Watch on …" card for a streaming-page video URL that can't inline-play.
struct LinkMediaCard: View {
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill").font(.title3).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Watch video").font(.callout).bold()
                    Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(.tertiary)
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 460)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
