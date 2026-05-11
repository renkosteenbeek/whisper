import Foundation

enum BundledDefaults {
    static let language = "nl"
    static let model = WhisperModel.gpt4oTranscribe

    static var apiKey: String {
        guard let url = Bundle.main.url(forResource: "openai-key", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
