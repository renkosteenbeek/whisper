import SwiftUI

extension WhisperModel {
    var tintColor: Color {
        switch self {
        case .whisper1: return .blue
        case .gpt4oMiniTranscribe: return .green
        case .gpt4oTranscribe: return .purple
        case .gpt4oTranscribeDiarize: return .orange
        }
    }

    var shortLabel: String {
        switch self {
        case .whisper1: return "whisper-1"
        case .gpt4oMiniTranscribe: return "4o-mini"
        case .gpt4oTranscribe: return "4o"
        case .gpt4oTranscribeDiarize: return "4o-diarize"
        }
    }
}
