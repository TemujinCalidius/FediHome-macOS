import SwiftUI
import AppKit
import UniformTypeIdentifiers
import FediHomeKit

/// Edits the owner's public profile (FediHome#201): avatar, banner, display name,
/// tagline, website bio, fediverse bio, accent color. Only changed fields are sent;
/// the instance federates an actor Update so remotes refresh.
struct EditProfileView: View {
    let account: Account
    let baseURL: URL
    let onDone: () -> Void

    @EnvironmentObject private var session: SessionStore

    @State private var authorName: String
    @State private var tagline: String
    @State private var bio: String
    @State private var summary: String
    @State private var accent: Color
    private let initialAccentHex: String

    // Pending image changes: uploaded immediately on pick, applied on Save.
    @State private var pendingAvatarPath: String?
    @State private var pendingAvatarPreview: Data?
    @State private var pendingBannerPath: String?
    @State private var pendingBannerPreview: Data?

    private enum PickTarget { case avatar, banner }
    @State private var pickTarget: PickTarget = .avatar
    @State private var showingPicker = false
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var error: String?

    init(account: Account, baseURL: URL, onDone: @escaping () -> Void) {
        self.account = account
        self.baseURL = baseURL
        self.onDone = onDone
        _authorName = State(initialValue: account.authorName ?? "")
        _tagline = State(initialValue: account.tagline ?? "")
        _bio = State(initialValue: account.bio ?? "")
        _summary = State(initialValue: account.summary ?? "")
        let hex = account.accentColor ?? "#3b82f6"
        initialAccentHex = hex
        _accent = State(initialValue: Color(hexRRGGBB: hex) ?? .accentColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            imagesHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("Display name", text: $authorName)
                    field("Tagline", text: $tagline)

                    Text("About (website bio)").font(.caption).bold().foregroundStyle(.secondary)
                    TextEditor(text: $bio)
                        .font(.body).frame(height: 64)
                        .padding(4).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))

                    Text("Fediverse bio (shown on your actor profile)")
                        .font(.caption).bold().foregroundStyle(.secondary)
                    TextEditor(text: $summary)
                        .font(.body).frame(height: 64)
                        .padding(4).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))

                    Text("Bios are a single paragraph — line breaks become spaces. Leaving a field blank restores your site's default.")
                        .font(.caption2).foregroundStyle(.secondary)

                    ColorPicker("Accent color", selection: $accent, supportsOpacity: false)

                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    }

                    HStack {
                        Button("Cancel", action: onDone).keyboardShortcut(.cancelAction)
                        Spacer()
                        if isUploading { ProgressView().controlSize(.small) }
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving { ProgressView().controlSize(.small) } else { Text("Save") }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isSaving || isUploading)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 560)
        .fileImporter(isPresented: $showingPicker,
                      allowedContentTypes: [.jpeg, .png, .webP, .gif, .heic],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await upload(url) }
            }
        }
    }

    // MARK: Images

    private var imagesHeader: some View {
        ZStack(alignment: .bottomLeading) {
            bannerImage
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { pickTarget = .banner; showingPicker = true }
                .overlay(alignment: .topTrailing) {
                    Label("Change banner", systemImage: "photo")
                        .font(.caption2).padding(5)
                        .background(.black.opacity(0.45), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(8)
                        .allowsHitTesting(false)
                }

            avatarImage
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.background, lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture { pickTarget = .avatar; showingPicker = true }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.white, .tint)
                        .allowsHitTesting(false)
                }
                .offset(x: 16, y: 24)
        }
        .padding(.bottom, 28)
    }

    @ViewBuilder private var bannerImage: some View {
        if let data = pendingBannerPreview, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            AsyncImage(url: MediaURL.resolve(account.banner, relativeTo: baseURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
        }
    }

    @ViewBuilder private var avatarImage: some View {
        if let data = pendingAvatarPreview, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            AsyncAvatar(url: MediaURL.resolve(account.avatar, relativeTo: baseURL), size: 64)
        }
    }

    private func upload(_ url: URL) async {
        guard let client = session.client else { return }
        let target = pickTarget // capture now — a re-tap mid-upload must not misroute this result
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            error = "Couldn't read \(url.lastPathComponent)."
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let upload = try await client.uploadMedia(data, filename: url.lastPathComponent,
                                                      mimeType: mimeType(for: url))
            switch target {
            case .avatar: pendingAvatarPath = upload.url; pendingAvatarPreview = data
            case .banner: pendingBannerPath = upload.url; pendingBannerPreview = data
            }
            error = nil
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Save

    private func save() async {
        guard let client = session.client else { return }
        // The server forbids newlines in every profile field — flatten to a single
        // paragraph so a multi-line bio can't fail the whole save with an opaque 400.
        let cleanName = singleLine(authorName)
        let cleanTagline = singleLine(tagline)
        let cleanBio = singleLine(bio)
        let cleanSummary = singleLine(summary)

        // Only send what changed (the server requires ≥1 field and leaves the rest).
        let newHex = accent.hexRRGGBB ?? initialAccentHex
        let nameChange = cleanName != (account.authorName ?? "") ? cleanName : nil
        let taglineChange = cleanTagline != (account.tagline ?? "") ? cleanTagline : nil
        let bioChange = cleanBio != (account.bio ?? "") ? cleanBio : nil
        let summaryChange = cleanSummary != (account.summary ?? "") ? cleanSummary : nil
        let accentChange = newHex.lowercased() != initialAccentHex.lowercased() ? newHex : nil

        let anyChange = nameChange != nil || taglineChange != nil || bioChange != nil
            || summaryChange != nil || accentChange != nil
            || pendingAvatarPath != nil || pendingBannerPath != nil
        guard anyChange else { onDone(); return }

        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await client.updateProfile(
                authorName: nameChange,
                bio: bioChange,
                tagline: taglineChange,
                summary: summaryChange,
                accentColor: accentChange,
                avatarPath: pendingAvatarPath,
                bannerPath: pendingBannerPath
            )
            // Apply the authoritative response immediately (so a field the server
            // reverted to its default shows correctly even if the refetch below fails),
            // then refresh counts/etc. best-effort.
            session.applyProfile(result.profile)
            await session.refreshAccount()
            onDone()
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Helpers

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).bold().foregroundStyle(.secondary)
            TextField(label, text: text).textFieldStyle(.roundedBorder).labelsHidden()
        }
    }

    private func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Hex color bridging

private extension Color {
    init?(hexRRGGBB hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }

    var hexRRGGBB: String? {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(srgb.redComponent * 255))
        let g = Int(round(srgb.greenComponent * 255))
        let b = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
