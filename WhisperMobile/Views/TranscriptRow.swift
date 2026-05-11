import SwiftUI

struct TranscriptRow: View {
    let transcript: SavedTranscript

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(modelTint.opacity(0.18))
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(modelTint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(transcript.filename)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    if let d = transcript.duration {
                        Label(formatDuration(d), systemImage: "clock")
                    }
                    if let lang = transcript.language, !lang.isEmpty {
                        Text("·")
                        Text(lang.uppercased())
                    }
                    Text("·")
                    Text(transcript.model?.shortLabel ?? transcript.modelRaw)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    private var modelTint: Color {
        transcript.model?.tintColor ?? .secondary
    }

    private var snippet: String {
        let t = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 90 { return t }
        return String(t.prefix(90)) + "…"
    }

    private func formatDuration(_ s: Double) -> String {
        let total = Int(s.rounded())
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }
}

struct ProcessingRow: View {
    @Bindable var job: TranscriptionJob

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                ProgressView()
                    .controlSize(.small)
                    .tint(.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(job.statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .uploading(let p) = job.status {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
