import SwiftUI
@preconcurrency import PstReader

struct SearchBarView: View {
    @ObservedObject var viewModel: SearchViewModel
    let folders: [PstFile.Folder]

    @State private var showFilters = false

    var body: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search emails...", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        viewModel.performSearch(in: folders)
                    }
                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Button {
                showFilters.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .popover(isPresented: $showFilters) {
                SearchFilterPopover(viewModel: viewModel)
            }

            Button("Search") {
                viewModel.performSearch(in: folders)
            }
            .disabled(
                viewModel.query
                    .trimmingCharacters(in: .whitespaces).isEmpty
            )
        }
        .frame(maxWidth: 400)
    }
}

struct SearchFilterPopover: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Search email body", isOn: $viewModel.includeBody)

            Divider()

            Text("Sender")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(
                "Filter by sender...",
                text: Binding(
                    get: { viewModel.senderFilter ?? "" },
                    set: { viewModel.senderFilter = $0.isEmpty ? nil : $0 }
                )
            )
            .textFieldStyle(.roundedBorder)

            Divider()

            Text("Date Range")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                DatePicker(
                    "From",
                    selection: Binding(
                        get: { viewModel.dateFrom ?? .distantPast },
                        set: { viewModel.dateFrom = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                Text("to")
                    .foregroundColor(.secondary)
                DatePicker(
                    "To",
                    selection: Binding(
                        get: { viewModel.dateTo ?? Date() },
                        set: { viewModel.dateTo = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
            HStack {
                if viewModel.dateFrom != nil || viewModel.dateTo != nil {
                    Button("Clear dates") {
                        viewModel.dateFrom = nil
                        viewModel.dateTo = nil
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
}
