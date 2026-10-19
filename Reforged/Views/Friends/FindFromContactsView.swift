import SwiftUI

// MARK: - Find friends from Contacts (opt-in, 18+)
//
// Members must opt in to being findable before they can look. Emails are hashed
// on-device; only hashes are sent, and only opted-in members come back.

struct FindFromContactsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = FriendsStore.shared

    var body: some View {
        NavigationStack {
            List {
                if let msg = store.errorMessage {
                    Section { Label(msg, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.subheadline) }
                }

                if !store.discoverable {
                    optInSection
                } else if store.isSearchingContacts {
                    Section { HStack { ProgressView(); Text("Checking your contacts…").padding(.leading, 8) } }
                } else if store.contactSearchDone {
                    resultsSection
                } else {
                    Section {
                        Button { Task { await store.findFriendsInContacts() } } label: {
                            Label("Check my contacts", systemImage: "person.crop.circle.badge.questionmark")
                        }
                    } footer: { privacyFootnote }
                }
            }
            .navigationTitle("Find friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var privacyFootnote: some View {
        Text("Your contacts stay on your phone. We only send scrambled (hashed) email addresses to check for matches, and we don't store them. People only appear if they chose to be findable.")
    }

    private var optInSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Turn on \"Let people with my email find me\" first")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                Text("To look for friends, you also need to be findable by them. Anyone who has your email in their contacts and has turned this on can see your first name and send you a friend request. They can't see anything else until you accept, and you can turn it off at any time.")
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
            }
            .padding(.vertical, 4)
            Button {
                Task {
                    await store.setDiscoverable(true)
                    if store.discoverable { await store.findFriendsInContacts() }
                }
            } label: {
                Label("Turn on and check my contacts", systemImage: "checkmark.shield")
            }
        } footer: { privacyFootnote }
    }

    private var resultsSection: some View {
        Section {
            if store.matches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No one from your contacts is findable yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    Text("Use Invite from Contacts to send them a link instead.")
                        .font(.footnote)
                        .foregroundStyle(Color.adaptiveTextSecondary(colorScheme))
                }
                .padding(.vertical, 4)
            }
            ForEach(store.matches) { match in
                HStack {
                    ZStack {
                        Circle().fill(Color.reforgedGold.opacity(0.18)).frame(width: 36, height: 36)
                        Text(String(match.displayName.prefix(1)).uppercased())
                            .font(.headline).foregroundStyle(Color.reforgedGold)
                    }
                    Text(match.displayName).foregroundStyle(Color.adaptiveText(colorScheme))
                    Spacer()
                    if store.requestedIds.contains(match.userId) {
                        Label("Requested", systemImage: "checkmark").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Button("Send request") { Task { await store.sendRequest(to: match) } }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.reforgedGold)
                            .controlSize(.small)
                    }
                }
            }
        } header: {
            Text("On Reforged")
        } footer: {
            Text("They'll get your request and choose whether to accept. Nothing is shared until they do.")
        }
    }
}
