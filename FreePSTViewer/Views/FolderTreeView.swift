import SwiftUI
@preconcurrency import PstReader

struct FolderTreeView: View {
    let rootFolder: PstFile.Folder
    @ObservedObject var viewModel: FolderViewModel

    var body: some View {
        List {
            ForEach(Array(rootFolder.children.enumerated()), id: \.offset) { index, child in
                FolderRow(folder: child, viewModel: viewModel, depth: 0, indexPath: [0, index])
            }
        }
        .listStyle(.sidebar)
    }
}

struct FolderRow: View {
    let folder: PstFile.Folder
    @ObservedObject var viewModel: FolderViewModel
    let depth: Int
    let indexPath: [Int]

    private var folderID: String {
        viewModel.folderID(folder, path: indexPath)
    }

    private var isExpanded: Bool {
        viewModel.expandedFolderIDs.contains(folderID)
    }

    private var isSelected: Bool {
        viewModel.selectedFolderID == folderID
    }

    private var hasChildren: Bool {
        !folder.children.isEmpty
    }

    private var folderName: String {
        folder.name ?? "Unknown"
    }

    private var itemCount: UInt32 {
        folder.emailCount ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if hasChildren {
                    Image(systemName: isExpanded
                        ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .accessibilityLabel(
                            isExpanded ? "Collapse" : "Expand"
                        )
                        .onTapGesture {
                            viewModel.toggleExpansion(id: folderID)
                        }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0)
                }

                Image(systemName: "folder")
                    .foregroundColor(.accentColor)

                Text(folderName)

                Spacer()

                if itemCount > 0 {
                    Text("\(itemCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectFolder(folder, id: folderID)
                if hasChildren {
                    viewModel.toggleExpansion(id: folderID)
                }
            }
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.2) : Color.clear
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(folderName) folder, \(itemCount) items"
            )
            .accessibilityHint("Click to select this folder")
            .accessibilityAddTraits(.isButton)

            if isExpanded {
                ForEach(
                    Array(folder.children.enumerated()),
                    id: \.offset
                ) { index, child in
                    FolderRow(
                        folder: child,
                        viewModel: viewModel,
                        depth: depth + 1,
                        indexPath: indexPath + [index]
                    )
                    .padding(.leading, 16)
                }
            }
        }
    }
}
