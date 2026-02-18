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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SortMenu(viewModel: viewModel)
            }
        }
    }
}

struct SortMenu: View {
    @ObservedObject var viewModel: EmailListViewModel

    var body: some View {
        Menu {
            sortButton("Date", ascending: .dateAscending, descending: .dateDescending)
            sortButton("Subject", ascending: .subjectAscending, descending: .subjectDescending)
            sortButton("From", ascending: .senderAscending, descending: .senderDescending)
            sortButton("Size", ascending: .sizeAscending, descending: .sizeDescending)
        } label: {
            Label(
                "Sort by \(viewModel.sortColumnLabel)",
                systemImage: viewModel.isSortAscending ? "arrow.up" : "arrow.down"
            )
        }
    }

    private func sortButton(
        _ label: String,
        ascending: EmailSortOrder,
        descending: EmailSortOrder
    ) -> some View {
        let isActive = viewModel.sortOrder == ascending || viewModel.sortOrder == descending
        return Button {
            if isActive {
                viewModel.sort(by: viewModel.isSortAscending ? descending : ascending)
            } else {
                viewModel.sort(by: descending)
            }
        } label: {
            HStack {
                Text(label)
                if isActive {
                    Image(systemName: viewModel.isSortAscending ? "arrow.up" : "arrow.down")
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

                if let size = email.sizeInBytes {
                    Text(formatByteCount(size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

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
