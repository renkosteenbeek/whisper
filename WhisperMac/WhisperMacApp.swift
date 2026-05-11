import SwiftUI

@main
struct WhisperMacApp: App {
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
            ContentView()
                .environment(settings)
                .environment(store)
                .environment(queue)
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}
