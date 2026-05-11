import Foundation
import Observation

struct SavedTranscript: Identifiable, Codable, Hashable {
    let id: UUID
    let filename: String
    let createdAt: Date
    let modelRaw: String
    let language: String?
    let duration: Double?
    let text: String
    let segments: [TranscriptionSegment]
    let audioRelativePath: String?

    var model: WhisperModel? { WhisperModel(rawValue: modelRaw) }
    var isProcessing: Bool { false }
}

struct PendingJob: Identifiable, Codable {
    let id: UUID
    let filename: String
    let audioRelativePath: String
    let modelRaw: String
    let language: String?
    let createdAt: Date

    var model: WhisperModel { WhisperModel(rawValue: modelRaw) ?? .whisper1 }
}

@MainActor
@Observable
final class TranscriptStore {
    static let appGroup = "group.nl.gentle-innovations.whispermac"

    var transcripts: [SavedTranscript] = []

    private let containerURL: URL
    private let transcriptsDir: URL
    private let pendingDir: URL
    private let mediaDir: URL

    init() {
        let fm = FileManager.default
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WhisperMac", isDirectory: true)

        self.containerURL = base
        self.transcriptsDir = base.appendingPathComponent("transcripts", isDirectory: true)
        self.pendingDir = base.appendingPathComponent("pending", isDirectory: true)
        self.mediaDir = base.appendingPathComponent("media", isDirectory: true)

        for dir in [transcriptsDir, pendingDir, mediaDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        reload()
    }

    var sharedContainerURL: URL { containerURL }
    var sharedMediaDir: URL { mediaDir }
    var sharedPendingDir: URL { pendingDir }

    func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: transcriptsDir, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var loaded: [SavedTranscript] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let t = try? decoder.decode(SavedTranscript.self, from: data) else { continue }
            loaded.append(t)
        }
        transcripts = loaded.sorted { $0.createdAt > $1.createdAt }
    }

    func save(result: TranscriptionResult, filename: String, model: WhisperModel, audioRelativePath: String?) throws {
        let t = SavedTranscript(
            id: UUID(),
            filename: filename,
            createdAt: Date(),
            modelRaw: model.rawValue,
            language: result.language,
            duration: result.duration,
            text: result.text,
            segments: result.segments,
            audioRelativePath: audioRelativePath
        )
        try writeTranscript(t)
        transcripts.insert(t, at: 0)
    }

    private func writeTranscript(_ t: SavedTranscript) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(t)
        let url = transcriptsDir.appendingPathComponent("\(t.id.uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    func delete(_ id: UUID) {
        let fm = FileManager.default
        if let t = transcripts.first(where: { $0.id == id }), let rel = t.audioRelativePath {
            try? fm.removeItem(at: containerURL.appendingPathComponent(rel))
        }
        let url = transcriptsDir.appendingPathComponent("\(id.uuidString).json")
        try? fm.removeItem(at: url)
        transcripts.removeAll { $0.id == id }
    }

    func deleteAll() {
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: transcriptsDir, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }
        for url in (try? fm.contentsOfDirectory(at: mediaDir, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }
        transcripts.removeAll()
    }

    func storageBytes() -> Int {
        let fm = FileManager.default
        var total = 0
        for dir in [transcriptsDir, mediaDir] {
            for url in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? [] {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                total += size
            }
        }
        return total
    }

    func pendingJobs() -> [PendingJob] {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var jobs: [PendingJob] = []
        for url in urls where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let j = try? decoder.decode(PendingJob.self, from: data) {
                jobs.append(j)
            }
        }
        return jobs.sorted { $0.createdAt < $1.createdAt }
    }

    func consumePending(_ id: UUID) {
        let url = pendingDir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    func writePending(_ job: PendingJob) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(job)
        let url = pendingDir.appendingPathComponent("\(job.id.uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    func mediaURL(for relativePath: String) -> URL {
        containerURL.appendingPathComponent(relativePath)
    }
}
