import SwiftUI

struct ShareView: View {
    let audioURL: URL
    let originalName: String
    let duration: Double
    let relativePath: String
    let initialModel: WhisperModel
    let language: String
    let onSubmit: (WhisperModel, String) -> Void
    let onCancel: () -> Void

    @State private var selectedModel: WhisperModel
    @State private var queued = false

    init(
        audioURL: URL,
        originalName: String,
        duration: Double,
        relativePath: String,
        initialModel: WhisperModel,
        language: String,
        onSubmit: @escaping (WhisperModel, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.audioURL = audioURL
        self.originalName = originalName
        self.duration = duration
        self.relativePath = relativePath
        self.initialModel = initialModel
        self.language = language
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _selectedModel = State(initialValue: initialModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(selectedModel.tintColor.opacity(0.15))
                    Image(systemName: "waveform")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(selectedModel.tintColor)
                }
                .frame(width: 76, height: 76)

                VStack(spacing: 4) {
                    Text(originalName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if duration > 0 {
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                Picker("Model", selection: $selectedModel) {
                    ForEach(WhisperModel.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    queued = true
                    onSubmit(selectedModel, language)
                } label: {
                    HStack {
                        if queued {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolEffect(.bounce, value: queued)
                            Text("Queued. Open WhisperMac to view.")
                        } else {
                            Image(systemName: "waveform.badge.mic")
                            Text("Transcribe")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(queued)
                .sensoryFeedback(.success, trigger: queued)

                Button("Cancel", role: .cancel) { onCancel() }
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .background(Color(uiColor: .systemBackground))
    }

    private func formatDuration(_ s: Double) -> String {
        let total = Int(s.rounded())
        let m = total / 60
        let sec = total % 60
        return String(format: "%d:%02d", m, sec)
    }
}
