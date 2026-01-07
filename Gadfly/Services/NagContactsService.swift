import Foundation
import MessageUI
import UIKit
import Contacts

@MainActor
class NagContactsService: ObservableObject {
    static let shared = NagContactsService()

    @Published var contacts: [NagContact] = []
    @Published var contactsAuthStatus: CNAuthorizationStatus = .notDetermined

    private let userDefaultsKey = "nag_contacts"

    init() {
        loadContacts()
    }

    // MARK: - Contact Management

    func addContact(_ contact: NagContact) {
        if !contacts.contains(where: { $0.phoneNumber == contact.phoneNumber }) {
            contacts.append(contact)
            saveContacts()
        }
    }

    func removeContact(_ contact: NagContact) {
        contacts.removeAll { $0.id == contact.id }
        saveContacts()
    }

    func updateContact(_ contact: NagContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
            saveContacts()
        }
    }

    func toggleContactActive(_ contact: NagContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index].isActive = !contacts[index].isActive
            saveContacts()
        }
    }

    // MARK: - Persistence

    private func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([NagContact].self, from: data) {
            contacts = decoded
        }
    }

    private func saveContacts() {
        if let encoded = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    // MARK: - Contacts Access

    func requestContactsAccess() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactsAuthStatus = CNContactStore.authorizationStatus(for: .contacts)
            return granted
        } catch {
            print("Contacts access error: \(error)")
            return false
        }
    }

    func fetchContactsFromDevice() async -> [CNContact] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor
        ]

        var fetchedContacts: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                if !contact.phoneNumbers.isEmpty {
                    fetchedContacts.append(contact)
                }
            }
        } catch {
            print("Failed to fetch contacts: \(error)")
        }

        return fetchedContacts.sorted { ($0.givenName + $0.familyName) < ($1.givenName + $1.familyName) }
    }

    // MARK: - Send Messages

    /// Send nag message to all active contacts about a task
    func sendNagMessages(taskTitle: String, message: String, completion: @escaping (Bool) -> Void) {
        let activeContacts = contacts.filter { $0.isActive }

        guard !activeContacts.isEmpty else {
            completion(false)
            return
        }

        // Format the message with task info
        let formattedMessage = "📋 Gadfly Reminder: \(taskTitle)\n\n\(message)"

        // Store message for sending via UI
        pendingNagMessage = PendingNagMessage(
            contacts: activeContacts,
            message: formattedMessage,
            completion: completion
        )

        // Post notification to trigger message UI
        NotificationCenter.default.post(
            name: .sendNagMessageNotification,
            object: nil,
            userInfo: ["message": formattedMessage, "contacts": activeContacts]
        )
    }

    var pendingNagMessage: PendingNagMessage?
}

// MARK: - Models

struct NagContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var relationship: String  // e.g., "Child", "Partner", "Team Member"
    var isActive: Bool

    init(id: UUID = UUID(), name: String, phoneNumber: String, relationship: String = "Contact", isActive: Bool = true) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isActive = isActive
    }
}

struct PendingNagMessage {
    let contacts: [NagContact]
    let message: String
    let completion: (Bool) -> Void
}

// MARK: - Notification Extension

extension Notification.Name {
    static let sendNagMessageNotification = Notification.Name("sendNagMessageNotification")
}

// MARK: - Message Composer Coordinator

class MessageComposerCoordinator: NSObject, MFMessageComposeViewControllerDelegate {
    var completion: ((Bool) -> Void)?

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        let success = result == .sent
        completion?(success)
        controller.dismiss(animated: true)
    }
}
