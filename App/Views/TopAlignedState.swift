import SwiftUI

/// Aligns placeholder content (loading / error / empty states) to the **top** of the
/// detail pane — matching how populated Lists start at the top — instead of SwiftUI's
/// default vertical centering, which made empty pages look unlike every other page.
struct TopAlignedState<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.top, 40)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
