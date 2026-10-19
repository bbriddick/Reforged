import SwiftUI
import ContactsUI
import MessageUI

// MARK: - Invite from Contacts (local only)
//
// Uses the system contact picker, which runs out of process: the app never
// requests Contacts permission and only receives the single contact the user
// taps. Nothing is stored or uploaded, and no matching against Reforged members
// happens. The invite goes out through Messages (or Mail / the share sheet).

struct ContactPickerView: UIViewControllerRepresentable {
    let onPick: (CNContact) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        vc.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
        return vc
    }

    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick; self.onCancel = onCancel
        }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) { onPick(contact) }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { onCancel() }
    }
}

struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) { onFinish() }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// A button that picks a contact and sends them a fresh single-use invite.
struct InviteFromContactsButton: View {
    @ObservedObject private var store = FriendsStore.shared
    @Environment(\.openURL) private var openURL

    private enum Outgoing: Identifiable {
        case message(recipient: String, body: String)
        case share(body: String)
        var id: String {
            switch self { case .message(let r, _): return "m-\(r)"; case .share: return "share" }
        }
    }

    @State private var showPicker = false
    @State private var outgoing: Outgoing?
    @State private var busy = false

    var body: some View {
        Button { showPicker = true } label: {
            Label(busy ? "Preparing invite…" : "Invite from Contacts", systemImage: "person.crop.circle.badge.plus")
        }
        .disabled(busy)
        .sheet(isPresented: $showPicker) {
            ContactPickerView(onPick: { contact in
                showPicker = false
                Task { await prepare(for: contact) }
            }, onCancel: { showPicker = false })
            .ignoresSafeArea()
        }
        .sheet(item: $outgoing) { item in
            switch item {
            case .message(let recipient, let body):
                MessageComposerView(recipients: [recipient], body: body) { outgoing = nil }
                    .ignoresSafeArea()
            case .share(let body):
                ActivityShareSheet(items: [body])
            }
        }
    }

    private func prepare(for contact: CNContact) async {
        busy = true
        defer { busy = false }
        guard let code = await store.newInviteCode() else { return }

        let first = contact.givenName.trimmingCharacters(in: .whitespaces)
        let greeting = first.isEmpty ? "Hey" : "Hey \(first)"
        let link = "https://reforgedapp.org/friend/\(code)"
        let text = "\(greeting), I'm using Reforged to read and memorize Scripture and I'd love to do it with you. "
            + "Join me here: \(link)  (invite code \(code))"

        let phone = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?

        if let phone, MFMessageComposeViewController.canSendText() {
            outgoing = .message(recipient: phone, body: text)
        } else if let email,
                  let subject = "Join me on Reforged".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let body = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "mailto:\(email)?subject=\(subject)&body=\(body)") {
            openURL(url)
        } else {
            outgoing = .share(body: text)   // no number/email, or this device can't text
        }
    }
}
