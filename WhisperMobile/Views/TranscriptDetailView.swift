import SwiftUI
import UniformTypeIdentifiers

struct TranscriptDetailView: View {
    let transcript: SavedTranscript

    @State private var exportFormat: ExportFormat?
    @State private var showCopyConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metadataRow
                Divider()
                Text(transcript.text)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .navigationTitle(transcript.filename)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sensoryFeedback(.success, trigger: showCopyConfirmation)
        .fileExporter(
            isPresented: Binding(get: { exportFormat != nil }, set: { if !$0 { exportFormat = nil } }),
            document: exportDocument,
            contentType: exportFormat?.contentType ?? .plainText,
            defaultFilename: defaultFilename
        ) { _ in
            exportFormat = nil
        }
    }

    private var metadataRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let model = transcript.model {
                    MetadataCapsule(icon: "cpu", text: model.shortLabel, tint: model.tintColor)
                }
                if let lang = transcript.language, !lang.isEmpty {
                    MetadataCapsule(icon: "globe", text: lang.uppercased())
                }
                if let dur = transcript.duration {
                    MetadataCapsule(icon: "clock", text: formatDuration(dur))
                }
                MetadataCapsule(icon: "calendar", text: relativeDate(transcript.createdAt))
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Button {
                UIPasteboard.general.string = transcript.text
                showCopyConfirmation.toggle()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            ShareLink(item: transcript.text) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Menu {
                ForEach(ExportFormat.allCases) { f in
                    Button(f.displayName) { exportFormat = f }
                }
            } label: {
                Label("Export", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var defaultFilename: String {
        let stem = (transcript.filename as NSString).deletingPathExtension
        return stem
    }

    private var exportDocument: TranscriptExportDocument? {
        guard let format = exportFormat else { return nil }
        let result = TranscriptionResult(
            text: transcript.text,
            language: transcript.language,
            duration: transcript.duration,
            segments: transcript.segments,
            rawJSON: Data()
        )
        let data = TranscriptExport.render(result, as: format)
        return TranscriptExportDocument(data: data, contentType: format.contentType)
    }

    private func formatDuration(_ s: Double) -> String {
        let total = Int(s.rounded())
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }
}

import UniformTypeIdentifiers

struct TranscriptExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText, .json]

    let data: Data
    let contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = .plainText
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
