import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    @Environment(JobQueue.self) private var queue
    @State private var isTargeted = false

    private let acceptedTypes: [UTType] = [.audio, .movie, .mpeg4Audio, .mp3, .wav, .quickTimeMovie, .mpeg4Movie]

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Drop audio or video files here")
                .font(.headline)
            Text("or click to browse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { openPanel() }
        .onDrop(of: acceptedTypes, isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            for type in acceptedTypes where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let u = item as? URL {
                        url = u
                    } else if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        url = nil
                    }
                    if let url {
                        Task { @MainActor in
                            queue.enqueue(url)
                        }
                    }
                }
                handled = true
                break
            }
        }
        return handled
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = acceptedTypes
        if panel.runModal() == .OK {
            for url in panel.urls {
                queue.enqueue(url)
            }
        }
    }
}
