import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TranscriptStore.self) private var store
    @Environment(JobQueue.self) private var queue

    @State private var showingSettings = false
    @State private var showingImporter = false
    @State private var searchText = ""
    @State private var didShowFirstRunSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.transcripts.isEmpty && activeJobs.isEmpty {
                    EmptyStateView()
                } else {
                    contentList
                }
            }
            .navigationTitle("Transcripts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingImporter = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.audio, .movie, .mpeg4Audio, .mp3, .wav, .quickTimeMovie, .mpeg4Movie],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .refreshable {
                store.reload()
                queue.processPending()
            }
            .onAppear {
                if settings.apiKey.isEmpty && !didShowFirstRunSettings {
                    didShowFirstRunSettings = true
                    showingSettings = true
                }
            }
            .navigationDestination(for: SavedTranscript.self) { transcript in
                TranscriptDetailView(transcript: transcript)
            }
        }
    }

    private var activeJobs: [TranscriptionJob] {
        queue.jobs.filter { !$0.isDone }
    }

    private var filteredTranscripts: [SavedTranscript] {
        guard !searchText.isEmpty else { return store.transcripts }
        let q = searchText.lowercased()
        return store.transcripts.filter {
            $0.filename.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            if !activeJobs.isEmpty {
                Section("Processing") {
                    ForEach(activeJobs) { job in
                        ProcessingRow(job: job)
                    }
                }
            }

            ForEach(groupedTranscripts(), id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items) { transcript in
                        NavigationLink(value: transcript) {
                            TranscriptRow(transcript: transcript)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(transcript.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private struct DateGroup {
        let title: String
        let items: [SavedTranscript]
    }

    private func groupedTranscripts() -> [DateGroup] {
        let cal = Calendar.current
        let now = Date()
        var today: [SavedTranscript] = []
        var yesterday: [SavedTranscript] = []
        var thisWeek: [SavedTranscript] = []
        var earlier: [SavedTranscript] = []

        for t in filteredTranscripts {
            if cal.isDateInToday(t.createdAt) {
                today.append(t)
            } else if cal.isDateInYesterday(t.createdAt) {
                yesterday.append(t)
            } else if let days = cal.dateComponents([.day], from: t.createdAt, to: now).day, days < 7 {
                thisWeek.append(t)
            } else {
                earlier.append(t)
            }
        }

        var groups: [DateGroup] = []
        if !today.isEmpty { groups.append(.init(title: "Today", items: today)) }
        if !yesterday.isEmpty { groups.append(.init(title: "Yesterday", items: yesterday)) }
        if !thisWeek.isEmpty { groups.append(.init(title: "This Week", items: thisWeek)) }
        if !earlier.isEmpty { groups.append(.init(title: "Earlier", items: earlier)) }
        return groups
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            let dest = store.sharedMediaDir.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            do {
                try FileManager.default.copyItem(at: url, to: dest)
                let rel = "media/\(dest.lastPathComponent)"
                queue.enqueue(dest, audioRelativePath: rel, displayName: url.lastPathComponent)
            } catch {
                continue
            }
        }
    }
}
