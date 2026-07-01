import SwiftUI

/// Drives the full-window image viewer. Each window/sheet that shows images owns its
/// own instance (so a viewer opened from a thread sheet renders above the sheet).
@MainActor
final class ImageViewerModel: ObservableObject {
    struct Presentation: Equatable {
        var urls: [URL]
        var index: Int
    }

    @Published var presentation: Presentation?

    func present(_ urls: [URL], index: Int) {
        guard !urls.isEmpty, urls.indices.contains(index) else { return }
        presentation = Presentation(urls: urls, index: index)
    }

    func dismiss() { presentation = nil }

    func next() {
        guard var p = presentation, p.index < p.urls.count - 1 else { return }
        p.index += 1
        presentation = p
    }

    func previous() {
        guard var p = presentation, p.index > 0 else { return }
        p.index -= 1
        presentation = p
    }
}

/// Mount at the root of a window/sheet: renders nothing until an image is presented.
struct ImageViewerOverlay: View {
    @EnvironmentObject private var viewer: ImageViewerModel

    var body: some View {
        ZStack {
            if let presentation = viewer.presentation {
                ImageViewerContent(presentation: presentation)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewer.presentation)
    }
}

private struct ImageViewerContent: View {
    let presentation: ImageViewerModel.Presentation
    @EnvironmentObject private var viewer: ImageViewerModel

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @FocusState private var focused: Bool

    private var url: URL { presentation.urls[presentation.index] }
    private var isMultiple: Bool { presentation.urls.count > 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.93)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { viewer.dismiss() }

            image

            controls
        }
        .focusable()
        .focused($focused)
        .onAppear { focused = true; resetTransform() }
        .onChange(of: presentation.index) { resetTransform() }
        .onKeyPress(.escape) { viewer.dismiss(); return .handled }
        .onKeyPress(.leftArrow) { viewer.previous(); return .handled }
        .onKeyPress(.rightArrow) { viewer.next(); return .handled }
    }

    private var image: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .offset(offset)
                    .gesture(magnify)
                    .gesture(pan)
                    .onTapGesture(count: 2) { toggleZoom() }
            case .empty:
                ProgressView().controlSize(.large).tint(.white)
            case .failure:
                Image(systemName: "photo").font(.system(size: 48)).foregroundStyle(.white.opacity(0.5))
            @unknown default:
                EmptyView()
            }
        }
        .padding(48)
    }

    private var controls: some View {
        VStack {
            HStack {
                if isMultiple {
                    Text("\(presentation.index + 1) / \(presentation.urls.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.black.opacity(0.4), in: Capsule())
                }
                Spacer()
                Button {
                    viewer.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            Spacer()
        }
        .padding(20)
        .overlay(alignment: .leading) { navButton(system: "chevron.left", enabled: presentation.index > 0, action: viewer.previous) }
        .overlay(alignment: .trailing) { navButton(system: "chevron.right", enabled: presentation.index < presentation.urls.count - 1, action: viewer.next) }
    }

    @ViewBuilder private func navButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        if isMultiple {
            Button(action: action) {
                Image(systemName: system)
                    .font(.title)
                    .foregroundStyle(.white.opacity(enabled ? 0.85 : 0.2))
                    .padding(12)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .padding(.horizontal, 12)
        }
    }

    // MARK: Zoom / pan

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in zoom = min(max(lastZoom * value, 1), 6) }
            .onEnded { _ in lastZoom = zoom; if zoom <= 1 { resetPan() } }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoom > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        if zoom > 1 { resetTransform() } else { zoom = 2.5; lastZoom = 2.5 }
    }

    private func resetTransform() { zoom = 1; lastZoom = 1; resetPan() }
    private func resetPan() { offset = .zero; lastOffset = .zero }
}
