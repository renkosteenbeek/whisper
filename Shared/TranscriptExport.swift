import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case txt, srt, vtt, json
    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }

    var contentType: UTType {
        switch self {
        case .txt: return .plainText
        case .srt: return UTType(filenameExtension: "srt") ?? .plainText
        case .vtt: return UTType(filenameExtension: "vtt") ?? .plainText
        case .json: return .json
        }
    }
}

enum TranscriptExport {
    static func render(_ result: TranscriptionResult, as format: ExportFormat) -> Data {
        switch format {
        case .txt:
            return Data(result.text.utf8)
        case .srt:
            return Data(renderSRT(result.segments).utf8)
        case .vtt:
            return Data(renderVTT(result.segments).utf8)
        case .json:
            if !result.rawJSON.isEmpty { return result.rawJSON }
            let payload: [String: Any] = [
                "text": result.text,
                "language": result.language ?? NSNull(),
                "duration": result.duration ?? NSNull(),
                "segments": result.segments.map { ["start": $0.start, "end": $0.end, "text": $0.text] }
            ]
            return (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])) ?? Data()
        }
    }

    private static func renderSRT(_ segments: [TranscriptionSegment]) -> String {
        var out = ""
        for (i, seg) in segments.enumerated() {
            out += "\(i + 1)\n"
            out += "\(formatTimestamp(seg.start, comma: true)) --> \(formatTimestamp(seg.end, comma: true))\n"
            out += "\(seg.text.trimmingCharacters(in: .whitespaces))\n\n"
        }
        return out
    }

    private static func renderVTT(_ segments: [TranscriptionSegment]) -> String {
        var out = "WEBVTT\n\n"
        for seg in segments {
            out += "\(formatTimestamp(seg.start, comma: false)) --> \(formatTimestamp(seg.end, comma: false))\n"
            out += "\(seg.text.trimmingCharacters(in: .whitespaces))\n\n"
        }
        return out
    }

    private static func formatTimestamp(_ seconds: Double, comma: Bool) -> String {
        let total = max(0, seconds)
        let h = Int(total / 3600)
        let m = Int((total.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(total.truncatingRemainder(dividingBy: 60))
        let ms = Int((total - floor(total)) * 1000)
        let sep = comma ? "," : "."
        return String(format: "%02d:%02d:%02d\(sep)%03d", h, m, s, ms)
    }
}
