import Foundation
@preconcurrency import PstReader

@MainActor
class PSTViewModel: ObservableObject {
    @Published var currentFile: PstFile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let parserService: PSTParserService

    init(parserService: PSTParserService = PSTParserService()) {
        self.parserService = parserService
    }

    func loadFile(from url: URL) async {
        isLoading = true
        errorMessage = nil
        do {
            let file = try await parserService.loadPSTFile(from: url)
            if file.rootFolder == nil {
                let parseError = PSTViewerError.parseError("Could not read folder structure from this file.")
                errorMessage = parseError.errorDescription
                currentFile = nil
            } else {
                currentFile = file
            }
        } catch {
            errorMessage = PSTViewerError.invalidFileFormat(underlying: error).errorDescription
            currentFile = nil
        }
        isLoading = false
    }

    func closeFile() {
        currentFile = nil
        errorMessage = nil
    }
}
