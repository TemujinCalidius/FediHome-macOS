import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @EnvironmentObject private var session: SessionStore
    /// Owned by MainView so an in-progress post survives switching sidebar sections.
    @ObservedObject var model: ComposeViewModel

    private enum ImporterMode { case photo, audio }
    @State private var importerMode: ImporterMode = .photo
    @State private var showingImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                typeBadge

                TextField(model.isEditing ? "Title"
                          : "Title (optional — adding one makes it an Article)",
                          text: $model.title)
                    .textFieldStyle(.plain)
                    .font(.title3.bold())

                Divider()

                contentEditor

                if model.isArticle { descriptionEditor }

                if !model.attachments.isEmpty { photoStrip }
                if model.includeVideo && !model.isDraft { videoSection }
                if !model.audioAttachments.isEmpty && !model.isDraft { audioSection }

                if model.isEditing {
                    Label("Attached media is kept as-is when editing.", systemImage: "paperclip")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    controls
                    publishingOptions
                }

                if let reason = model.blockedReason, hasAnyInput || model.isEditing {
                    Label(reason, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if let success = model.successURL { successBanner(success) }
                if let error = model.errorMessage { errorBanner(error) }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .disabled(model.isPosting) // don't let text typed mid-post get wiped by reset()
        }
        .navigationTitle(model.isEditing ? "Edit Post" : "New Post")
        .task { await model.loadCategoriesIfNeeded(session: session) }
        .toolbar {
            if model.isEditing {
                Button("Cancel") { model.cancelEditing() }
            }
            Button {
                Task { await model.post(session: session) }
            } label: {
                if model.isPosting {
                    ProgressView().controlSize(.small)
                } else {
                    Text(model.isEditing ? "Save Changes"
                         : (model.isDraft ? "Save Draft" : (model.isScheduling ? "Schedule" : "Post")))
                }
            }
            .disabled(!model.canPost)
            .keyboardShortcut(.return, modifiers: .command)
            .help(model.isEditing ? "Save the edit (federates an update)"
                  : (model.isScheduling ? "Schedule for later" : "Publish"))
        }
        .fileImporter(isPresented: $showingImporter,
                      // Only types /api/media accepts (an unmapped image would 400).
                      allowedContentTypes: importerMode == .photo ? [.jpeg, .png, .webP, .gif, .heic] : [.mp3],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                switch importerMode {
                case .photo: Task { await model.addPhotos(urls: urls, session: session) }
                case .audio: Task { await model.addAudio(urls: urls, session: session) }
                }
            }
        }
    }

    /// Whether the user has started something (gates the blocked-reason hint so an
    /// empty composer isn't nagged).
    private var hasAnyInput: Bool {
        !model.content.isEmpty || !model.title.isEmpty || !model.attachments.isEmpty
            || !model.audioAttachments.isEmpty || model.includeVideo || model.isScheduling
    }

    private var typeBadge: some View {
        HStack(spacing: 8) {
            if model.isEditing {
                Label("Editing: \(model.editingDisplayTitle)", systemImage: "pencil")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            // In edit mode the type is fixed (the "Editing:" badge stands in); showing a
            // live note/article label here would imply clearing the title converts the post.
            if !model.isEditing {
                Label(model.isArticle ? "Article" : "Journal note",
                      systemImage: model.isArticle ? "doc.richtext" : "text.quote")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }
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
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach($model.attachments) { $attachment in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                thumbnail(attachment.previewData)
                                    .frame(width: 132, height: 96)
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
                            if !model.isDraft {
                                TextField("Caption", text: $attachment.alt)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .frame(width: 132)
                            }
                        }
                    }
                }
            }
            if !model.isDraft {
                HStack(spacing: 10) {
                    Toggle("Add to photo gallery", isOn: $model.addPhotosToGallery)
                        .toggleStyle(.checkbox)
                        .font(.callout)
                    if model.addPhotosToGallery {
                        CategoryField(text: $model.photoCategory, options: model.photoCategoryOptions)
                    }
                    Spacer()
                }
            }
        }
    }

    /// Video embed by URL (the file stays on its host; the instance stores embed metadata).
    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Video", systemImage: "play.rectangle").font(.caption).bold().foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.includeVideo = false
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove video")
            }
            TextField("Video URL (PeerTube / MakerTube / YouTube / Vimeo)", text: $model.videoURLString)
                .textFieldStyle(.roundedBorder)
            if model.videoURLInvalid {
                Label("That URL isn't a recognized video host.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            } else if let info = model.videoEmbedInfo {
                Label("Will embed from \(info.embedHost)", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.green)
            }
            TextField("Video title", text: $model.videoTitle)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 10) {
                Toggle("Add to videos gallery", isOn: $model.addVideoToGallery)
                    .toggleStyle(.checkbox)
                    .font(.callout)
                if model.addVideoToGallery {
                    CategoryField(text: $model.videoCategory, options: model.videoCategoryOptions)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Uploaded audio files → the post renders an audio player per track.
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Audio", systemImage: "waveform").font(.caption).bold().foregroundStyle(.secondary)
            ForEach($model.audioAttachments) { $audio in
                HStack(spacing: 8) {
                    Image(systemName: "music.note").foregroundStyle(.tint)
                    TextField("Track title", text: $audio.title)
                        .textFieldStyle(.roundedBorder)
                    if let seconds = audio.durationSec {
                        Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Button {
                        model.removeAudio(audio)
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Toggle("Add to audio gallery", isOn: $model.addAudioToGallery)
                    .toggleStyle(.checkbox)
                    .font(.callout)
                if model.addAudioToGallery {
                    CategoryField(text: $model.audioCategory, options: model.audioCategoryOptions)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
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
                importerMode = .photo
                showingImporter = true
            } label: {
                Label("Add Photo", systemImage: "photo.badge.plus")
            }
            .disabled(model.isUploading)

            if !model.isDraft {
                Button {
                    model.includeVideo = true
                } label: {
                    Label("Add Video", systemImage: "play.rectangle")
                }
                .disabled(model.includeVideo)

                Button {
                    importerMode = .audio
                    showingImporter = true
                } label: {
                    Label("Add Audio", systemImage: "waveform.badge.plus")
                }
                .disabled(model.isUploading)
            }

            if model.isUploading { ProgressView().controlSize(.small) }

            Spacer()

            Toggle("Save as draft", isOn: $model.isDraft)
                .toggleStyle(.checkbox)
                .disabled(model.isScheduling) // drafts publish via Micropub; scheduling via /api/compose
                .help(model.isDraft ? "Drafts save text and photos (captions/galleries/video/audio publish-only)" : "")
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
            } else if model.savedEdit {
                Text("Changes saved.")
                Link("View post", destination: url)
            } else if model.savedAsDraft {
                Text("Draft saved.")
                Link("Open", destination: url)
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
