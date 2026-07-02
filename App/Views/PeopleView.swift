import SwiftUI
import FediHomeKit

struct PeopleView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @StateObject private var model = PeopleViewModel()
    @State private var tab: Tab = .following

    private enum Tab: Hashable { case following, followers }

    var body: some View {
        VStack(spacing: 0) {
            followBar
            Divider()
            picker
            content
        }
        .navigationTitle("People")
        .toolbar {
            Button { Task { await model.load(session: session) } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            .help("Refresh")
        }
        .task { if model.graph == nil { await model.load(session: session) } }
        .onChange(of: navigator.refreshTick) { Task { await model.load(session: session) } }
    }

    private var followBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Follow someone — @name@server.social", text: $model.followHandle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.follow(session: session) } }
                Button {
                    Task { await model.follow(session: session) }
                } label: {
                    if model.isFollowing { ProgressView().controlSize(.small) } else { Text("Follow") }
                }
                .disabled(model.isFollowing || model.followHandle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let message = model.actionMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var picker: some View {
        Picker("", selection: $tab) {
            Text("Following (\(model.graph?.counts.following ?? 0))").tag(Tab.following)
            Text("Followers (\(model.graph?.counts.followers ?? 0))").tag(Tab.followers)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var content: some View {
        let people = tab == .following ? (model.graph?.following ?? []) : (model.graph?.followers ?? [])
        if model.isLoading && model.graph == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage, model.graph == nil {
            ContentUnavailableView("Couldn't load people", systemImage: "person.2.slash", description: Text(error))
        } else if people.isEmpty {
            ContentUnavailableView(tab == .following ? "Not following anyone yet" : "No followers yet",
                                   systemImage: "person.2")
        } else {
            List(people) { person in
                PersonRow(person: person, baseURL: session.resolvedBaseURL)
            }
            .listStyle(.inset)
        }
    }
}

struct PersonRow: View {
    let person: GraphPerson
    let baseURL: URL
    @State private var showingProfile = false

    private var profileTarget: ProfileTarget? { ProfileTarget(person: person) }

    var body: some View {
        HStack(spacing: 10) {
            AsyncAvatar(url: MediaURL.resolve(person.avatarUrl ?? "", relativeTo: baseURL), size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.name).font(.callout).bold().lineLimit(1)
                Text(person.fediHandle ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if !person.isFedi {
                Text("Bluesky").font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if profileTarget != nil { showingProfile = true } }
        .popover(isPresented: $showingProfile, arrowEdge: .trailing) {
            if let target = profileTarget {
                ProfileView(target: target, baseURL: baseURL)
            }
        }
    }
}

extension ProfileTarget {
    /// Fediverse graph people can be profiled; Bluesky people lack an `actorUri`.
    init?(person: GraphPerson) {
        guard let actorUri = person.actorUri, let username = person.username, let domain = person.domain else {
            return nil
        }
        self.init(actorUri: actorUri, username: username, domain: domain,
                  displayName: person.displayName, avatarUrl: person.avatarUrl)
    }
}
