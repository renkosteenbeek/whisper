import Foundation
import AppKit

enum ExportService {
    static func render(_ result: TranscriptionResult, as format: ExportFormat) -> Data {
        TranscriptExport.render(result, as: format)
    }

    @MainActor
    static func savePanel(suggestedName: String, format: ExportFormat, data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(suggestedName).\(format.fileExtension)"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }
}
