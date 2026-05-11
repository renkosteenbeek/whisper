import SwiftUI

struct ResultView: View {
    let filename: String
    let result: TranscriptionResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(filename).font(.headline)
                    if let lang = result.language {
                        Text("Language: \(lang)\(result.duration.map { String(format: " · %.1fs", $0) } ?? "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Copy") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(result.text, forType: .string)
                }
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                Text(result.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
}
