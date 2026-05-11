import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TranscriptStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var keyDraft: String = ""
    @State private var testStatus: String?
    @State private var testing = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("OpenAI") {
                SecureField("Override API key (optional)", text: $keyDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack {
                    Button("Test connection") { Task { await testConnection() } }
                        .disabled(testing)
                    Spacer()
                    if testing {
                        ProgressView().controlSize(.small)
                    } else if let testStatus {
                        Text(testStatus)
                            .font(.caption)
                            .foregroundStyle(testStatus.hasPrefix("OK") ? .green : .red)
                    }
                }

                Text("A default key is bundled. Leave the field empty to keep using it, or paste your own to override.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Defaults") {
                Picker("Model", selection: $settings.defaultModel) {
                    ForEach(WhisperModel.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                HStack {
                    Text("Language")
                    Spacer()
                    TextField("Auto", text: $settings.defaultLanguage)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: 120)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("• whisper-1 - $0.006/min, only model with SRT/VTT timestamps")
                    Text("• gpt-4o-mini-transcribe - $0.003/min, cheapest")
                    Text("• gpt-4o-transcribe - $0.006/min, best accuracy")
                    Text("• gpt-4o-transcribe-diarize - $0.015/min, speaker labels")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Library") {
                LabeledContent("Transcripts", value: "\(store.transcripts.count)")
                LabeledContent("Storage used", value: formatBytes(store.storageBytes()))
                Button("Clear all transcripts", role: .destructive) {
                    showingDeleteConfirm = true
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link("OpenAI usage dashboard", destination: URL(string: "https://platform.openai.com/usage")!)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { save(); dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { keyDraft = "" }
        .confirmationDialog(
            "Delete all transcripts?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                store.deleteAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone. Audio files are also removed.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private func save() {
        let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.apiKey = trimmed
    }

    private func testConnection() async {
        testing = true
        testStatus = nil
        defer { testing = false }

        let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToTest = trimmed.isEmpty ? settings.apiKey : trimmed

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(keyToTest)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                testStatus = "OK - key works"
            } else if let http = response as? HTTPURLResponse {
                testStatus = "HTTP \(http.statusCode)"
            } else {
                testStatus = "No response"
            }
        } catch {
            testStatus = error.localizedDescription
        }
    }

    private func formatBytes(_ b: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file)
    }
}
