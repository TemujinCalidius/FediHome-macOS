import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "house.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Connect to FediHome")
                    .font(.title).bold()
                Text("Sign in to your instance to read your feed and notifications.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instance URL")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("https://fedihome.social", text: $session.instanceURLString)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .onSubmit(connect)
                    .frame(maxWidth: 360)
            }

            Button(action: connect) {
                if session.isBusy {
                    ProgressView().controlSize(.small).frame(maxWidth: 360)
                } else {
                    Text("Connect").frame(maxWidth: 360)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session.isBusy || session.instanceURLString.trimmingCharacters(in: .whitespaces).isEmpty)

            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Spacer()

            Text("You'll sign in on your own site — this app never sees your password.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func connect() {
        Task { await session.connect() }
    }
}
