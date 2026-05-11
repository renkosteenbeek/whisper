import UIKit
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadAttachment()
    }

    private func loadAttachment() {
        guard let item = (extensionContext?.inputItems.first as? NSExtensionItem),
              let attachments = item.attachments,
              let provider = attachments.first else {
            showError("No audio attachment found.")
            return
        }

        let typeIdentifiers: [String] = [
            UTType.audio.identifier,
            UTType.movie.identifier,
            UTType.mpeg4Audio.identifier,
            UTType.mp3.identifier,
            UTType.wav.identifier,
            UTType.quickTimeMovie.identifier,
            UTType.mpeg4Movie.identifier
        ]

        let matchingType = typeIdentifiers.first { provider.hasItemConformingToTypeIdentifier($0) }
        guard let type = matchingType else {
            showError("Attachment is not audio.")
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] tempURL, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.showError(error.localizedDescription) }
                return
            }
            guard let tempURL else {
                DispatchQueue.main.async { self.showError("No file URL provided.") }
                return
            }

            do {
                let store = TranscriptStore()
                let ext = tempURL.pathExtension.isEmpty ? "m4a" : tempURL.pathExtension
                let id = UUID()
                let fileName = "\(id.uuidString).\(ext)"
                let dest = store.sharedMediaDir.appendingPathComponent(fileName)
                try FileManager.default.copyItem(at: tempURL, to: dest)

                let originalName: String = {
                    let ext = tempURL.pathExtension
                    if let suggested = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !suggested.isEmpty {
                        return ext.isEmpty ? suggested : "\(suggested).\(ext)"
                    }
                    return tempURL.lastPathComponent
                }()
                Task { [weak self] in
                    let duration = (try? await AVURLAsset(url: dest).load(.duration).seconds) ?? 0
                    await MainActor.run {
                        self?.presentShareUI(
                            audioURL: dest,
                            originalName: originalName,
                            duration: duration,
                            relativePath: "media/\(fileName)"
                        )
                    }
                }
            } catch {
                DispatchQueue.main.async { self.showError("Could not copy: \(error.localizedDescription)") }
            }
        }
    }

    @MainActor
    private func presentShareUI(audioURL: URL, originalName: String, duration: Double, relativePath: String) {
        let settings = AppSettings()
        let shareView = ShareView(
            audioURL: audioURL,
            originalName: originalName,
            duration: duration,
            relativePath: relativePath,
            initialModel: settings.defaultModel,
            language: settings.defaultLanguage,
            onSubmit: { [weak self] selectedModel, language in
                self?.queueAndOpen(
                    relativePath: relativePath,
                    originalName: originalName,
                    model: selectedModel,
                    language: language
                )
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let host = UIHostingController(rootView: shareView)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func queueAndOpen(relativePath: String, originalName: String, model: WhisperModel, language: String) {
        let store = TranscriptStore()
        let pending = PendingJob(
            id: UUID(),
            filename: originalName,
            audioRelativePath: relativePath,
            modelRaw: model.rawValue,
            language: language.isEmpty ? nil : language,
            createdAt: Date()
        )
        try? store.writePending(pending)

        let url = URL(string: "whispermac://process?id=\(pending.id.uuidString)")!
        openHostURL(url)

        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "WhisperShare", code: 0))
    }

    private func openHostURL(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                return
            }
            if r.responds(to: selector) {
                _ = r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.cancel()
        })
        present(alert, animated: true)
    }
}
