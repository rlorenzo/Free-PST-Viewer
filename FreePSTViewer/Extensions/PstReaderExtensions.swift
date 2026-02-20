import Foundation
@preconcurrency import PstReader

// MARK: - PstFile Convenience

extension PstFile {
    /// The user-visible root folder (IPM subtree), e.g.
    /// "Top of Personal Folders". Excludes internal system
    /// folders like IPM_VIEWS and Search Root. Falls back to
    /// `rootFolder` if the IPM subtree cannot be identified.
    var userRootFolder: Folder? {
        guard let entryId = messageStore?.ipmSubTreeEntryId,
              let folder = try? getFolder(nid: entryId.nid)
        else {
            return rootFolder
        }
        return folder
    }
}

// MARK: - Message Contact Properties

extension PstFile.Message {
    /// Whether this message represents a contact (IPM.Contact).
    var isContact: Bool {
        messageClass?.hasPrefix("IPM.Contact") == true
    }

    /// All non-nil email addresses for this contact.
    var contactEmailAddresses: [String] {
        [
            email1EmailAddress,
            email2EmailAddress,
            email3EmailAddress
        ].compactMap { $0 }
    }

    /// Labeled phone numbers for this contact.
    var contactPhoneNumbers: [(label: String, number: String)] {
        var result: [(String, String)] = []
        if let number = businessTelephoneNumber {
            result.append(("Business", number))
        }
        if let number = homeTelephoneNumber {
            result.append(("Home", number))
        }
        if let number = mobileTelephoneNumber {
            result.append(("Mobile", number))
        }
        if let number = primaryTelephoneNumber {
            result.append(("Primary", number))
        }
        if let number = businessFaxNumber {
            result.append(("Business Fax", number))
        }
        return result
    }

    /// The contact's company name.
    var contactCompanyName: String? { companyName }

    /// The contact's job title.
    var contactTitle: String? { title }

    /// The contact's department.
    var contactDepartment: String? { department }

    /// The contact's nickname.
    var contactNickname: String? { nickname }

    /// The contact's home address (formatted).
    var contactHomeAddress: String? { homeAddress }

    /// The contact's work address (formatted).
    var contactWorkAddress: String? { workAddress }

    /// The contact's birthday.
    var contactBirthday: Date? { birthday }
}
