import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(JobQueue.self) private var queue
    @Environment(TranscriptStore.self) private var store
    @State private var showingSettings = false
    @State private var detailTranscript: SavedTranscript?
    @State private var pendingDelete: SavedTranscript?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WhisperMac")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            DropZoneView()
                .padding()

            Divider()

            if activeJobs.isEmpty && store.transcripts.isEmpty {
                ContentUnavailableView(
                    "No transcriptions yet",
                    systemImage: "waveform",
                    description: Text("Drop audio or video files above to get started.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !activeJobs.isEmpty {
                        Section("Processing") {
                            ForEach(activeJobs) { job in
                                ProcessingJobRow(job: job)
                            }
                        }
                    }
                    if !store.transcripts.isEmpty {
                        Section("Transcripts") {
                            ForEach(store.transcripts) { transcript in
                                LibraryRow(transcript: transcript)
                                    .contentShape(Rectangle())
                                    .onTapGesture { detailTranscript = transcript }
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 520, minHeight: 380)
        }
        .sheet(item: $detailTranscript) { transcript in
            TranscriptWindow(transcript: transcript)
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

    private var activeJobs: [TranscriptionJob] {
        queue.jobs.filter { !$0.isDone }
    }
}
