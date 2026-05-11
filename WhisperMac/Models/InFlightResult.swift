import Foundation

struct InFlightResult: Identifiable {
    let id: UUID
    let filename: String
    let model: WhisperModel
    let result: TranscriptionResult

    @MainActor
    init?(job: TranscriptionJob) {
        guard let result = job.result else { return nil }
        self.id = job.id
        self.filename = job.displayName
        self.model = job.model
        self.result = result
    }

    var asTranscript: SavedTranscript {
        SavedTranscript(
            id: id,
            filename: filename,
            createdAt: Date(),
            modelRaw: model.rawValue,
            language: result.language,
            duration: result.duration,
            text: result.text,
            segments: result.segments,
            audioRelativePath: nil
        )
    }
}
