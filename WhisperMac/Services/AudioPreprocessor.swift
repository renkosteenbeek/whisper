import Foundation
import AVFoundation

enum AudioPreprocessor {
    static let openAILimit = 25 * 1024 * 1024

    struct Prepared {
        let url: URL
        let tempURL: URL?
    }

    enum PrepError: LocalizedError {
        case fileTooLarge(bytes: Int)
        case exportFailed(String)
        case noTracks

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let b):
                return "File still \(b / 1_048_576) MB after re-encoding. OpenAI limit is 25 MB."
            case .exportFailed(let m):
                return "Audio re-encoding failed: \(m)"
            case .noTracks:
                return "No audio tracks found in file."
            }
        }
    }

    static func prepareIfNeeded(url: URL) async throws -> Prepared {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if size <= openAILimit {
            return Prepared(url: url, tempURL: nil)
        }

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw PrepError.noTracks }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whispermac-\(UUID().uuidString).m4a")

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw PrepError.exportFailed("Could not create exporter")
        }
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = true

        try await exporter.export(to: outURL, as: .m4a)

        let outSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
        if outSize > openAILimit {
            try? FileManager.default.removeItem(at: outURL)
            throw PrepError.fileTooLarge(bytes: outSize)
        }
        return Prepared(url: outURL, tempURL: outURL)
    }
}
