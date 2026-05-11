import Foundation

struct TranscriptionSegment: Codable, Hashable {
    let id: Int?
    let start: Double
    let end: Double
    let text: String
}

struct TranscriptionResult {
    let text: String
    let language: String?
    let duration: Double?
    let segments: [TranscriptionSegment]
    let rawJSON: Data

    init(text: String, language: String?, duration: Double?, segments: [TranscriptionSegment], rawJSON: Data) {
        self.text = text
        self.language = language
        self.duration = duration
        self.segments = segments
        self.rawJSON = rawJSON
    }

    static func decode(from data: Data) throws -> TranscriptionResult {
        let decoder = JSONDecoder()
        struct Wire: Decodable {
            let text: String
            let language: String?
            let duration: Double?
            let segments: [TranscriptionSegment]?
        }
        let wire = try decoder.decode(Wire.self, from: data)
        return TranscriptionResult(
            text: wire.text,
            language: wire.language,
            duration: wire.duration,
            segments: wire.segments ?? [],
            rawJSON: data
        )
    }
}
