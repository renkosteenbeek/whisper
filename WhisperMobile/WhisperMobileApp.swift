import SwiftUI

@main
struct WhisperMobileApp: App {
    @State private var settings: AppSettings
    @State private var store: TranscriptStore
    @State private var queue: JobQueue

    init() {
        let s = AppSettings()
        let st = TranscriptStore()
        let q = JobQueue(settings: s, store: st)
        _settings = State(initialValue: s)
        _store = State(initialValue: st)
        _queue = State(initialValue: q)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(settings)
                .environment(store)
                .environment(queue)
                .onOpenURL { url in
                    handleURL(url)
                }
                .task {
                    queue.processPending()
                }
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "whispermac" else { return }
        queue.processPending()
    }
}
