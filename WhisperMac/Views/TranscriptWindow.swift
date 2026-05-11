import SwiftUI
import AppKit

struct TranscriptWindow: View {
    let transcript: SavedTranscript
    @Environment(\.dismiss) private var dismiss
    @State private var copyToggle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(transcript.filename)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                        MetadataCapsule(icon: "calendar", text: shortDate(transcript.createdAt))
                    }
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                Text(transcript.text)
                    .font(.body)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript.text, forType: .string)
                    copyToggle.toggle()
                } label: {
                    Label("Copy text", systemImage: "doc.on.doc")
                }
                Spacer()
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.displayName) { export(format) }
                    }
                } label: {
                    Label("Export", systemImage: "arrow.down.doc")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func export(_ format: ExportFormat) {
        let result = TranscriptionResult(
            text: transcript.text,
            language: transcript.language,
            duration: transcript.duration,
            segments: transcript.segments,
            rawJSON: Data()
        )
        let data = TranscriptExport.render(result, as: format)
        let stem = (transcript.filename as NSString).deletingPathExtension
        ExportService.savePanel(suggestedName: stem, format: format, data: data)
    }

    private func formatDuration(_ s: Double) -> String {
        let total = Int(s.rounded())
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}
