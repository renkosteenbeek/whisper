import SwiftUI

@main
struct WhisperMacApp: App {
    @State private var settings = AppSettings()
    @State private var queue: JobQueue

    init() {
        let s = AppSettings()
        _settings = State(initialValue: s)
        _queue = State(initialValue: JobQueue(settings: s))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(queue)
                .frame(minWidth: 640, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
    }
}
