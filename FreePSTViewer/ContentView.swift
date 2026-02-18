import SwiftUI
@preconcurrency import PstReader

struct ContentView: View {
    private let parserService: PSTParserService
    @StateObject private var pstViewModel: PSTViewModel
    @StateObject private var folderViewModel = FolderViewModel()
    @StateObject private var detailViewModel: EmailDetailViewModel

    init() {
        let service = PSTParserService()
        self.parserService = service
        _pstViewModel = StateObject(wrappedValue: PSTViewModel(parserService: service))
        _detailViewModel = StateObject(wrappedValue: EmailDetailViewModel(parserService: service))
    }

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
                EmailListPanel(
                    folder: folder,
                    folderID: folderID,
                    parserService: parserService,
                    detailViewModel: detailViewModel
                )
            } else {
                Text("Select a folder")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            EmailDetailView(viewModel: detailViewModel)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FilePickerButton { url in
                    Task {
                        detailViewModel.clear()
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
    @ObservedObject var detailViewModel: EmailDetailViewModel
    @StateObject private var listViewModel: EmailListViewModel

    init(
        folder: PstFile.Folder,
        folderID: String,
        parserService: PSTParserService,
        detailViewModel: EmailDetailViewModel
    ) {
        self.folder = folder
        self.folderID = folderID
        self.parserService = parserService
        self.detailViewModel = detailViewModel
        _listViewModel = StateObject(wrappedValue: EmailListViewModel(parserService: parserService))
    }

    var body: some View {
        EmailListView(viewModel: listViewModel)
            .task(id: folderID) {
                detailViewModel.clear()
                await listViewModel.loadEmails(for: folder)
            }
            .onChange(of: listViewModel.selectedEmailIndex) { _, newIndex in
                if let index = newIndex, listViewModel.emails.indices.contains(index) {
                    let message = listViewModel.emails[index]
                    Task {
                        await detailViewModel.loadDetails(for: message)
                    }
                } else {
                    detailViewModel.clear()
                }
            }
    }
}
