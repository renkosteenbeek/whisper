import Foundation
import Observation

enum WhisperModel: String, CaseIterable, Identifiable, Codable {
    case whisper1 = "whisper-1"
    case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"
    case gpt4oTranscribe = "gpt-4o-transcribe"
    case gpt4oTranscribeDiarize = "gpt-4o-transcribe-diarize"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .whisper1: return "whisper-1 (subtitles - SRT/VTT)"
        case .gpt4oMiniTranscribe: return "gpt-4o-mini-transcribe (cheap)"
        case .gpt4oTranscribe: return "gpt-4o-transcribe (best accuracy)"
        case .gpt4oTranscribeDiarize: return "gpt-4o-transcribe-diarize (speakers)"
        }
    }

    var supportsSegments: Bool { self == .whisper1 }
}

@Observable
final class AppSettings {
    nonisolated(unsafe) private static let defaults: UserDefaults = {
        UserDefaults(suiteName: "group.nl.gentle-innovations.whispermac") ?? .standard
    }()

    var apiKey: String {
        didSet { try? KeychainService.save(apiKey) }
    }
    var defaultModel: WhisperModel {
        didSet { Self.defaults.set(defaultModel.rawValue, forKey: "defaultModel") }
    }
    var defaultLanguage: String {
        didSet { Self.defaults.set(defaultLanguage, forKey: "defaultLanguage") }
    }

    init() {
        if let stored = KeychainService.load(), !stored.isEmpty {
            self.apiKey = stored
        } else {
            try? KeychainService.save(BundledDefaults.apiKey)
            self.apiKey = BundledDefaults.apiKey
        }
        let savedModel = Self.defaults.string(forKey: "defaultModel") ?? BundledDefaults.model.rawValue
        self.defaultModel = WhisperModel(rawValue: savedModel) ?? BundledDefaults.model
        self.defaultLanguage = Self.defaults.string(forKey: "defaultLanguage") ?? BundledDefaults.language
    }
}
