import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)
                .padding(.bottom, 8)
            Text("No transcripts yet")
                .font(.title2.weight(.semibold))
            VStack(spacing: 6) {
                Text("Share a Voice Memo from the Voice Memos app")
                Text("or tap **+** to import a file.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
