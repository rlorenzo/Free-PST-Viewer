import Foundation
@preconcurrency import PstReader

@MainActor
class FolderViewModel: ObservableObject {
    @Published var selectedFolderID: String?
    @Published var expandedFolderIDs: Set<String> = []

    // Keep a reference to the selected folder for loading emails
    @Published var selectedFolder: PstFile.Folder?

    func selectFolder(_ folder: PstFile.Folder, id: String) {
        selectedFolder = folder
        selectedFolderID = id
    }

    func expandTopLevel(rootFolder: PstFile.Folder) {
        expandedFolderIDs.removeAll()
        for (index, child) in rootFolder.children.enumerated() {
            let id = folderID(child, path: [0, index])
            expandedFolderIDs.insert(id)
        }
    }

    func toggleExpansion(id: String) {
        if expandedFolderIDs.contains(id) {
            expandedFolderIDs.remove(id)
        } else {
            expandedFolderIDs.insert(id)
        }
    }

    func folderID(_ folder: PstFile.Folder, path: [Int] = []) -> String {
        return path.map(String.init).joined(separator: ".") + "." + (folder.name ?? "Unknown")
    }
}
