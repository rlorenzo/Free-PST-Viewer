import SwiftUI
@preconcurrency import PstReader

struct ContentView: View {
    @StateObject private var pstViewModel = PSTViewModel()
    @StateObject private var folderViewModel = FolderViewModel()

    var body: some View {
        NavigationSplitView {
            if let rootFolder = pstViewModel.currentFile?.rootFolder {
                FolderTreeView(rootFolder: rootFolder, viewModel: folderViewModel)
            } else {
                VStack {
                    Text("No file open")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } content: {
            if let folder = folderViewModel.selectedFolder,
               let folderID = folderViewModel.selectedFolderID {
                EmailListPanel(folder: folder, folderID: folderID, parserService: pstViewModel.parserService)
            } else {
                Text("Select a folder")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            Text("Select an email to view its contents")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FilePickerButton { url in
                    Task {
                        await pstViewModel.loadFile(from: url)
                        folderViewModel.selectedFolder = nil
                        folderViewModel.selectedFolderID = nil
                        if let rootFolder = pstViewModel.currentFile?.rootFolder {
                            folderViewModel.expandTopLevel(rootFolder: rootFolder)
                        }
                    }
                }
            }
        }
        .overlay {
            if pstViewModel.isLoading {
                ProgressView("Loading file...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("Error", isPresented: Binding(
            get: { pstViewModel.errorMessage != nil },
            set: { if !$0 { pstViewModel.errorMessage = nil } }
        )) {
            Button("OK") { pstViewModel.errorMessage = nil }
        } message: {
            Text(pstViewModel.errorMessage ?? "")
        }
    }
}

/// Helper view that creates its own EmailListViewModel for the given folder.
struct EmailListPanel: View {
    let folder: PstFile.Folder
    let folderID: String
    let parserService: PSTParserService
    @StateObject private var viewModel: EmailListViewModel

    init(folder: PstFile.Folder, folderID: String, parserService: PSTParserService) {
        self.folder = folder
        self.folderID = folderID
        self.parserService = parserService
        _viewModel = StateObject(wrappedValue: EmailListViewModel(parserService: parserService))
    }

    var body: some View {
        EmailListView(viewModel: viewModel)
            .task(id: folderID) {
                await viewModel.loadEmails(for: folder)
            }
    }
}
