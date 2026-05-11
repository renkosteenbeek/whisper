import SwiftUI

struct TranscriptionRow: View {
    @Bindable var job: TranscriptionJob
    @State private var showingResult = false

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(job.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(job.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .uploading(let p) = job.status {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                }
            }
            Spacer()
            if job.isDone {
                Button("View") { showingResult = true }
                    .buttonStyle(.bordered)
                exportMenu
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingResult) {
            if let result = job.result {
                ResultView(filename: job.displayName, result: result)
                    .frame(minWidth: 600, minHeight: 480)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .preprocessing:
            ProgressView().controlSize(.small)
        case .uploading:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var exportMenu: some View {
        Menu("Export") {
            ForEach(ExportFormat.allCases) { format in
                Button(format.displayName) { export(format) }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func export(_ format: ExportFormat) {
        guard let result = job.result else { return }
        let data = ExportService.render(result, as: format)
        let suggested = (job.sourceURL.deletingPathExtension().lastPathComponent)
        Task { @MainActor in
            ExportService.savePanel(suggestedName: suggested, format: format, data: data)
        }
    }
}
