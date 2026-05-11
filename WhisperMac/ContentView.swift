import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(JobQueue.self) private var queue
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Whisper Mac")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            DropZoneView()
                .padding()

            Divider()

            if queue.jobs.isEmpty {
                ContentUnavailableView(
                    "No transcriptions yet",
                    systemImage: "waveform",
                    description: Text("Drop audio or video files above to get started.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(queue.jobs) { job in
                    TranscriptionRow(job: job)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 480, minHeight: 320)
        }
        .task {
            if settings.apiKey.isEmpty {
                showingSettings = true
            }
        }
    }
}
