import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var keyDraft: String = ""
    @State private var testStatus: String?
    @State private var testing = false

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { save(); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            GroupBox("OpenAI API") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Override API key (optional)")
                        .font(.subheadline)
                    SecureField("Leave empty to use bundled default", text: $keyDraft)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Test connection") { Task { await testConnection() } }
                            .disabled(testing)
                        if testing { ProgressView().controlSize(.small) }
                        if let testStatus { Text(testStatus).font(.caption) }
                    }
                    Text("A default key is bundled. Paste your own to override.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("Defaults") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Model")
                        Spacer()
                        Picker("", selection: $settings.defaultModel) {
                            ForEach(WhisperModel.allCases) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    HStack {
                        Text("Language (ISO-639-1, blank = auto)")
                        Spacer()
                        TextField("e.g. nl, en", text: $settings.defaultLanguage)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• whisper-1 ($0.006/min) - only model that returns SRT/VTT timestamps")
                        Text("• gpt-4o-mini-transcribe ($0.003/min) - cheapest, text only")
                        Text("• gpt-4o-transcribe ($0.006/min) - best accuracy, text only")
                        Text("• gpt-4o-transcribe-diarize ($0.015/min) - adds speaker labels")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            Spacer()
        }
        .padding()
        .onAppear { keyDraft = "" }
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
}
