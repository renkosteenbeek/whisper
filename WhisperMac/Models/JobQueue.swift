import Foundation
import Observation

@MainActor
@Observable
final class JobQueue {
    var jobs: [TranscriptionJob] = []
    private var isRunning = false

    private let settings: AppSettings
    private let store: TranscriptStore?

    init(settings: AppSettings, store: TranscriptStore? = nil) {
        self.settings = settings
        self.store = store
    }

    func enqueue(_ url: URL, model: WhisperModel? = nil, language: String? = nil, audioRelativePath: String? = nil, displayName: String? = nil) {
        let job = TranscriptionJob(
            sourceURL: url,
            model: model ?? settings.defaultModel,
            language: language ?? settings.defaultLanguage,
            audioRelativePath: audioRelativePath,
            displayName: displayName
        )
        jobs.append(job)
        Task { await processNext() }
    }

    func processPending() {
        guard let store else { return }
        for pending in store.pendingJobs() {
            let audioURL = store.mediaURL(for: pending.audioRelativePath)
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                store.consumePending(pending.id)
                continue
            }
            enqueue(
                audioURL,
                model: pending.model,
                language: pending.language,
                audioRelativePath: pending.audioRelativePath,
                displayName: pending.filename
            )
            store.consumePending(pending.id)
        }
    }

    private func processNext() async {
        guard !isRunning else { return }
        guard let job = jobs.first(where: { if case .queued = $0.status { return true } else { return false } }) else {
            return
        }
        isRunning = true
        defer { isRunning = false }

        await run(job: job)

        await processNext()
    }

    private func run(job: TranscriptionJob) async {
        guard !settings.apiKey.isEmpty else {
            job.status = .failed("OpenAI API key not set. Open Settings.")
            return
        }

        var workingURL = job.sourceURL
        var tempURL: URL?

        do {
            job.status = .preprocessing
            let prepared = try await AudioPreprocessor.prepareIfNeeded(url: job.sourceURL)
            workingURL = prepared.url
            tempURL = prepared.tempURL

            let client = WhisperAPIClient(apiKey: settings.apiKey)
            let result = try await client.transcribe(
                fileURL: workingURL,
                model: job.model,
                language: job.language.isEmpty ? nil : job.language,
                onProgress: { [weak job] p in
                    Task { @MainActor [weak job] in
                        job?.status = .uploading(progress: p)
                    }
                }
            )
            job.status = .done(result)

            if let store {
                try? store.save(
                    result: result,
                    filename: job.displayName,
                    model: job.model,
                    audioRelativePath: job.audioRelativePath
                )
            }
        } catch {
            job.status = .failed(error.localizedDescription)
        }

        if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
    }
}
