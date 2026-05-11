import Foundation
import Observation

@MainActor
@Observable
final class TranscriptionJob: Identifiable {
    enum Status {
        case queued
        case preprocessing
        case uploading(progress: Double)
        case done(TranscriptionResult)
        case failed(String)
    }

    let id = UUID()
    let sourceURL: URL
    var status: Status = .queued
    var model: WhisperModel
    var language: String
    var audioRelativePath: String?
    private let displayNameOverride: String?

    init(sourceURL: URL, model: WhisperModel, language: String, audioRelativePath: String? = nil, displayName: String? = nil) {
        self.sourceURL = sourceURL
        self.model = model
        self.language = language
        self.audioRelativePath = audioRelativePath
        self.displayNameOverride = displayName
    }

    var displayName: String { displayNameOverride ?? sourceURL.lastPathComponent }

    var statusLabel: String {
        switch status {
        case .queued: return "Queued"
        case .preprocessing: return "Preparing audio..."
        case .uploading(let p): return "Uploading \(Int(p * 100))%"
        case .done: return "Done"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }

    var isDone: Bool {
        if case .done = status { return true }
        return false
    }

    var result: TranscriptionResult? {
        if case .done(let r) = status { return r }
        return nil
    }
}
