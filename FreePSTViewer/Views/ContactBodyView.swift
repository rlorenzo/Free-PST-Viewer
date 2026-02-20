import SwiftUI
@preconcurrency import PstReader

struct ContactBodyView: View {
    let message: PstFile.Message

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !message.contactEmailAddresses.isEmpty {
                    contactSection("Email") {
                        ForEach(message.contactEmailAddresses, id: \.self) { email in
                            Text(email)
                                .textSelection(.enabled)
                        }
                    }
                }

                if !message.contactPhoneNumbers.isEmpty {
                    contactSection("Phone") {
                        ForEach(message.contactPhoneNumbers, id: \.label) { entry in
                            HStack(spacing: 4) {
                                Text(entry.label)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .trailing)
                                Text(entry.number)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if hasOrganizationInfo {
                    contactSection("Organization") {
                        if let title = message.contactTitle {
                            labeledRow("Title", value: title)
                        }
                        if let dept = message.contactDepartment {
                            labeledRow("Department", value: dept)
                        }
                        if let company = message.contactCompanyName {
                            labeledRow("Company", value: company)
                        }
                    }
                }

                if let address = message.contactWorkAddress {
                    contactSection("Work Address") {
                        Text(address)
                            .textSelection(.enabled)
                    }
                }

                if let address = message.contactHomeAddress {
                    contactSection("Home Address") {
                        Text(address)
                            .textSelection(.enabled)
                    }
                }

                if let birthday = message.contactBirthday {
                    contactSection("Birthday") {
                        Text(birthday, style: .date)
                            .textSelection(.enabled)
                    }
                }

                if let nickname = message.contactNickname {
                    contactSection("Nickname") {
                        Text(nickname)
                            .textSelection(.enabled)
                    }
                }

                if isEmpty {
                    Text("No contact details available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasOrganizationInfo: Bool {
        message.contactTitle != nil
            || message.contactDepartment != nil
            || message.contactCompanyName != nil
    }

    private var isEmpty: Bool {
        message.contactEmailAddresses.isEmpty
            && message.contactPhoneNumbers.isEmpty
            && !hasOrganizationInfo
            && message.contactWorkAddress == nil
            && message.contactHomeAddress == nil
            && message.contactBirthday == nil
            && message.contactNickname == nil
    }

    private func contactSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            content()
        }
    }

    private func labeledRow(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
