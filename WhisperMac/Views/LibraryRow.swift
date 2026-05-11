import SwiftUI

struct LibraryRow: View {
    let transcript: SavedTranscript

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(modelTint.opacity(0.18))
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(modelTint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(transcript.filename)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    if let dur = transcript.duration {
                        Label(formatDuration(dur), systemImage: "clock")
                    }
                    if let lang = transcript.language, !lang.isEmpty {
                        Text("·")
                        Text(lang.uppercased())
                    }
                    Text("·")
                    Text(transcript.model?.shortLabel ?? transcript.modelRaw)
                    Text("·")
                    Text(relativeDate(transcript.createdAt))
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
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private var modelTint: Color {
        transcript.model?.tintColor ?? .secondary
    }

    private var snippet: String {
        let t = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 110 { return t }
        return String(t.prefix(110)) + "…"
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

struct ProcessingJobRow: View {
    @Bindable var job: TranscriptionJob

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconTint.opacity(0.18))
                iconView
            }
            .frame(width: 38, height: 38)

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
                if case .failed(let msg) = job.status {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var iconTint: Color {
        switch job.status {
        case .failed: return .red
        case .done: return .green
        default: return .accentColor
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch job.status {
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.red)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
        default:
            ProgressView().controlSize(.small).tint(.accentColor)
        }
    }
}
