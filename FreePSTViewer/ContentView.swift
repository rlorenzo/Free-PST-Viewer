import SwiftUI
@preconcurrency import PstReader

struct ContentView: View {
    private let parserService: PSTParserService
    private let attachmentService: AttachmentService
    @StateObject private var pstViewModel: PSTViewModel
    @StateObject private var folderViewModel = FolderViewModel()
    @StateObject private var detailViewModel: EmailDetailViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @State private var selectedSearchIndex: Int?

    init() {
        let service = PSTParserService()
        self.parserService = service
        self.attachmentService = AttachmentService(
            parserService: service
        )
        _pstViewModel = StateObject(
            wrappedValue: PSTViewModel(parserService: service)
        )
        _detailViewModel = StateObject(
            wrappedValue: EmailDetailViewModel(parserService: service)
        )
        _searchViewModel = StateObject(
            wrappedValue: SearchViewModel(parserService: service)
        )
    }

    var body: some View {
        NavigationSplitView {
            if let rootFolder = pstViewModel.currentFile?.userRootFolder {
                FolderTreeView(
                    rootFolder: rootFolder,
                    viewModel: folderViewModel
                )
            } else {
                VStack {
                    Text("No file open")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } content: {
            contentPane
        } detail: {
            EmailDetailView(
                viewModel: detailViewModel,
                attachmentService: attachmentService
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FilePickerButton { url in
                    Task {
                        detailViewModel.clear()
                        searchViewModel.clearSearch()
                        selectedSearchIndex = nil
                        await pstViewModel.loadFile(from: url)
                        folderViewModel.selectedFolder = nil
                        folderViewModel.selectedFolderID = nil
                        if let root = pstViewModel.currentFile?.userRootFolder {
                            folderViewModel.expandTopLevel(rootFolder: root)
                        }
                    }
                }
            }
            ToolbarItem(placement: .automatic) {
                if pstViewModel.currentFile != nil {
                    SearchBarView(
                        viewModel: searchViewModel,
                        folders: searchFolders
                    )
                }
            }
        }
        .overlay {
            if pstViewModel.isLoading {
                ProgressView("Loading file...")
                    .padding()
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
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
        .onChange(of: selectedSearchIndex) { _, newIndex in
            if let index = newIndex,
               searchViewModel.searchResults.indices.contains(index) {
                let message = searchViewModel.searchResults[index]
                Task {
                    await detailViewModel.loadDetails(for: message)
                }
            } else {
                detailViewModel.clear()
            }
        }
        .onChange(of: searchViewModel.isActive) { _, isActive in
            if !isActive {
                selectedSearchIndex = nil
                detailViewModel.clear()
            }
        }
    }

    @ViewBuilder
    private var contentPane: some View {
        if searchViewModel.isActive {
            SearchResultsView(
                viewModel: searchViewModel,
                selectedIndex: $selectedSearchIndex
            )
        } else if let folder = folderViewModel.selectedFolder,
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
    }

    private var searchFolders: [PstFile.Folder] {
        if let root = pstViewModel.currentFile?.userRootFolder {
            return [root]
        }
        return []
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
        _listViewModel = StateObject(
            wrappedValue: EmailListViewModel(parserService: parserService)
        )
    }

    var body: some View {
        EmailListView(viewModel: listViewModel) { message, format in
            Task {
                await listViewModel.exportSingleEmail(
                    message, format: format
                )
            }
        }
            .task(id: folderID) {
                detailViewModel.clear()
                await listViewModel.loadEmails(for: folder)
            }
            .onChange(of: listViewModel.selectedEmailIndex) { _, newIndex in
                if let index = newIndex,
                   listViewModel.emails.indices.contains(index) {
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
