import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = ComposeViewModel()
    @State private var showingPhotoImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                typeBadge

                TextField("Title (optional — adding one makes it an Article)", text: $model.title)
                    .textFieldStyle(.plain)
                    .font(.title3.bold())

                Divider()

                contentEditor

                if model.isArticle { descriptionEditor }

                if !model.attachments.isEmpty { photoStrip }

                controls
                publishingOptions

                if let success = model.successURL { successBanner(success) }
                if let error = model.errorMessage { errorBanner(error) }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .disabled(model.isPosting) // don't let text typed mid-post get wiped by reset()
        }
        .navigationTitle("New Post")
        .toolbar {
            Button {
                Task { await model.post(session: session) }
            } label: {
                if model.isPosting {
                    ProgressView().controlSize(.small)
                } else {
                    Text(model.isDraft ? "Save Draft" : (model.isScheduling ? "Schedule" : "Post"))
                }
            }
            .disabled(!model.canPost)
            .keyboardShortcut(.return, modifiers: .command)
            .help(model.isScheduling ? "Schedule for later" : "Publish")
        }
        .fileImporter(isPresented: $showingPhotoImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await model.addPhotos(urls: urls, session: session) }
            }
        }
    }

    private var typeBadge: some View {
        HStack(spacing: 8) {
            Label(model.isArticle ? "Article" : "Journal note",
                  systemImage: model.isArticle ? "doc.richtext" : "text.quote")
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.tint.opacity(0.15), in: Capsule())
                .foregroundStyle(.tint)
            Spacer()
            Text("\(model.characterCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(model.suggestsArticle ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        }
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $model.content)
                .font(.body)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if model.content.isEmpty {
                        Text("What's on your mind?")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8).padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            if model.suggestsArticle {
                Label("Long posts read better as Articles — add a title.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    /// Article description → excerpt/AP summary. Microblog-length, shown under the body.
    private var descriptionEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Description").font(.caption).bold().foregroundStyle(.secondary)
                Spacer()
                Text("\(model.descriptionCount)/300")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(model.descriptionOverLimit ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            }
            TextField("A short summary shown with the article…", text: $model.postDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            if model.descriptionOverLimit {
                Label("Descriptions read best under 300 characters.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        thumbnail(attachment.previewData)
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Button {
                            model.removeAttachment(attachment)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(3)
                    }
                }
            }
        }
    }

    @ViewBuilder private func thumbnail(_ data: Data) -> some View {
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            Rectangle().fill(.quaternary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                showingPhotoImporter = true
            } label: {
                Label("Add Photo", systemImage: "photo.badge.plus")
            }
            .disabled(model.isUploading)

            if model.isUploading { ProgressView().controlSize(.small) }

            Spacer()

            Toggle("Save as draft", isOn: $model.isDraft)
                .toggleStyle(.checkbox)
                .disabled(model.isScheduling) // drafts publish via Micropub; scheduling via /api/compose
        }
    }

    /// Scheduling + crossposting (not applicable to drafts).
    private var publishingOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 12) {
                Toggle("Schedule for later", isOn: $model.isScheduling)
                    .toggleStyle(.checkbox)
                    .disabled(model.isDraft)
                if model.isScheduling {
                    DatePicker("", selection: $model.scheduledDate, in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                Spacer()
            }
            if !model.isDraft {
                HStack(spacing: 16) {
                    Toggle("Cross-post to Bluesky", isOn: $model.crosspostBluesky)
                        .toggleStyle(.checkbox)
                    Toggle("Cross-post to Threads", isOn: $model.crosspostThreads)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
                .font(.callout)
            }
        }
    }

    private func successBanner(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: model.scheduledConfirmation != nil ? "clock.badge.checkmark" : "checkmark.circle.fill")
                .foregroundStyle(.green)
            if let when = model.scheduledConfirmation {
                Text("Scheduled for \(when.formatted(date: .abbreviated, time: .shortened)).")
            } else {
                Text("Posted.")
                Link("View post", destination: url)
            }
            Spacer()
            Button("New Post") { model.startNew() }
        }
        .padding(10)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .padding(10)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
