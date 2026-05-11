import SwiftUI

struct ContentView: View {
    @Environment(JobQueue.self) private var queue
    @Environment(TranscriptStore.self) private var store
    @State private var showingSettings = false
    @State private var detailTranscript: SavedTranscript?
    @State private var pendingDelete: SavedTranscript?
    @State private var inFlightResult: InFlightResult?

    var body: some View {
        VStack(spacing: 0) {
            DropZoneView()
                .padding()

            Divider()

            if queue.jobs.isEmpty && store.transcripts.isEmpty {
                ContentUnavailableView(
                    "No transcriptions yet",
                    systemImage: "waveform",
                    description: Text("Drop audio or video files above to get started.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !queue.jobs.isEmpty {
                        Section(processingSectionTitle) {
                            ForEach(queue.jobs) { job in
                                ProcessingJobRow(job: job) {
                                    inFlightResult = InFlightResult(job: job)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        queue.jobs.removeAll { $0.id == job.id }
                                    } label: {
                                        Label("Dismiss", systemImage: "xmark")
                                    }
                                }
                            }
                        }
                    }
                    if !store.transcripts.isEmpty {
                        Section("Transcripts") {
                            ForEach(store.transcripts) { transcript in
                                Button {
                                    detailTranscript = transcript
                                } label: {
                                    LibraryRow(transcript: transcript)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Open") { detailTranscript = transcript }
                                    Divider()
                                    Button(role: .destructive) {
                                        pendingDelete = transcript
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        pendingDelete = transcript
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 520, minHeight: 380)
        }
        .sheet(item: $detailTranscript) { transcript in
            TranscriptWindow(transcript: transcript)
                .frame(minWidth: 640, minHeight: 480)
        }
        .sheet(item: $inFlightResult) { item in
            TranscriptWindow(transcript: item.asTranscript)
                .frame(minWidth: 640, minHeight: 480)
        }
        .confirmationDialog(
            "Delete this transcript?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { t in
            Button("Delete", role: .destructive) {
                store.delete(t.id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { t in
            Text("\(t.filename) and its audio file will be removed.")
        }
    }

    private var processingSectionTitle: String {
        let allDone = queue.jobs.allSatisfy { if case .done = $0.status { return true } else { return false } }
        return allDone ? "Recent" : "Processing"
    }
}
