import Foundation

actor WhisperAPIClient {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        case bodyWriteFailed(String)
        case decodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .http(let code, let body): return "OpenAI HTTP \(code): \(body)"
            case .bodyWriteFailed(let m): return "Could not build request body: \(m)"
            case .decodeFailed(let m): return "Could not decode response: \(m)"
            }
        }
    }

    func transcribe(
        fileURL: URL,
        model: WhisperModel,
        language: String?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult {
        let boundary = "----whispermac-\(UUID().uuidString)"
        let bodyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whispermac-body-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let responseFormat: String = model.supportsSegments ? "verbose_json" : "json"

        try Self.writeMultipartBody(
            to: bodyURL,
            fileURL: fileURL,
            model: model.rawValue,
            language: language,
            responseFormat: responseFormat,
            boundary: boundary
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600

        let delegate = ProgressDelegate(onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.upload(for: request, fromFile: bodyURL)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(-1, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.http(http.statusCode, body)
        }

        do {
            return try TranscriptionResult.decode(from: data)
        } catch {
            throw APIError.decodeFailed(String(describing: error))
        }
    }

    private static func writeMultipartBody(
        to bodyURL: URL,
        fileURL: URL,
        model: String,
        language: String?,
        responseFormat: String,
        boundary: String
    ) throws {
        FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: bodyURL) else {
            throw APIError.bodyWriteFailed("Cannot open temp body file")
        }
        defer { try? handle.close() }

        func writeString(_ s: String) {
            try? handle.write(contentsOf: Data(s.utf8))
        }

        func writeField(name: String, value: String) {
            writeString("--\(boundary)\r\n")
            writeString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            writeString("\(value)\r\n")
        }

        writeField(name: "model", value: model)
        writeField(name: "response_format", value: responseFormat)
        if let language, !language.isEmpty {
            writeField(name: "language", value: language)
        }

        let filename = fileURL.lastPathComponent
        let mime = mimeType(for: fileURL)
        writeString("--\(boundary)\r\n")
        writeString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        writeString("Content-Type: \(mime)\r\n\r\n")

        guard let inHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw APIError.bodyWriteFailed("Cannot open input file")
        }
        defer { try? inHandle.close() }
        while autoreleasepool(invoking: {
            let chunk = inHandle.availableData
            if chunk.isEmpty { return false }
            try? handle.write(contentsOf: chunk)
            return true
        }) {}

        writeString("\r\n--\(boundary)--\r\n")
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "mp4": return "video/mp4"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "ogg", "oga": return "audio/ogg"
        case "flac": return "audio/flac"
        case "mov": return "video/quicktime"
        case "mpga": return "audio/mpeg"
        case "mpeg": return "video/mpeg"
        default: return "application/octet-stream"
        }
    }
}

private final class ProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let onProgress: @Sendable (Double) -> Void
    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let p = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(min(max(p, 0), 1))
    }
}
