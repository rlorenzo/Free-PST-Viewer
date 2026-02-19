import SwiftUI
@preconcurrency import PstReader

struct SearchResultsView: View {
    @ObservedObject var viewModel: SearchViewModel
    @Binding var selectedIndex: Int?

    var body: some View {
        Group {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(
                            "\(viewModel.searchResults.count) result"
                            + (viewModel.searchResults.count == 1 ? "" : "s")
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Spacer()
                        Button("Clear search") {
                            selectedIndex = nil
                            viewModel.clearSearch()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                    List(selection: $selectedIndex) {
                        ForEach(
                            Array(
                                viewModel.searchResults.enumerated()
                            ),
                            id: \.offset
                        ) { index, email in
                            SearchResultRow(
                                email: email,
                                query: viewModel.query
                            )
                            .tag(index)
                        }
                    }
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let email: PstFile.Message
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            highlightedText(
                email.subjectText ?? "(No Subject)",
                query: query
            )
            .font(.headline)
            .lineLimit(1)

            HStack {
                highlightedText(
                    email.senderDisplayString ?? "Unknown Sender",
                    query: query
                )
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

    private func highlightedText(
        _ text: String,
        query: String
    ) -> Text {
        guard !query.isEmpty else { return Text(text) }
        let queryLowered = query.lowercased()
        var parts: [Text] = []
        var remaining = text[text.startIndex...]

        while let range = remaining.lowercased().range(of: queryLowered) {
            let startOffset = remaining.distance(
                from: remaining.startIndex,
                to: range.lowerBound
            )
            let textStart = remaining.index(
                remaining.startIndex, offsetBy: startOffset
            )
            let endOffset = remaining.distance(
                from: remaining.startIndex,
                to: range.upperBound
            )
            let textEnd = remaining.index(
                remaining.startIndex, offsetBy: endOffset
            )

            let before = remaining[remaining.startIndex..<textStart]
            let match = remaining[textStart..<textEnd]

            parts.append(Text(before))
            parts.append(
                Text(match).foregroundColor(.accentColor).bold()
            )
            remaining = remaining[textEnd...]
        }
        parts.append(Text(remaining))
        return parts.reduce(Text(""), +)
    }
}
