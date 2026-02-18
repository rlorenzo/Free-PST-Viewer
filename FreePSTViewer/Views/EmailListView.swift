import SwiftUI
@preconcurrency import PstReader

struct EmailListView: View {
    @ObservedObject var viewModel: EmailListViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading emails...")
            } else if viewModel.emails.isEmpty {
                Text("No emails in this folder")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedEmailIndex) {
                    ForEach(Array(viewModel.emails.enumerated()), id: \.offset) { index, email in
                        EmailRow(email: email)
                            .tag(index)
                    }
                }
            }
        }
    }
}

struct EmailRow: View {
    let email: PstFile.Message

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(email.subjectText ?? "(No Subject)")
                .font(.headline)
                .lineLimit(1)

            HStack {
                Text(email.senderDisplayString ?? "Unknown Sender")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                if let date = email.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
