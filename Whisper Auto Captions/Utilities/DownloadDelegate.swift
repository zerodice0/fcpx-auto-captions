//
//  DownloadDelegate.swift
//  Whisper Auto Captions
//
//  URLSession delegate for handling model downloads
//

import Foundation

/// Delegate for handling URLSession download tasks
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    // MARK: - Properties
    var model: String
    var progressHandler: ((Double) -> Void)?
    var completionHandler: (() -> Void)?
    var errorHandler: ((String) -> Void)?
    var cancelAction: (() -> Void)?
    private var didNotifyCompletion = false
    private let completionLock = NSLock()

    // Minimum valid model file size (50MB) - smallest model is ~75MB
    private let minimumValidFileSize: Int64 = 50 * 1024 * 1024

    // MARK: - Initialization
    init(model: String, progressHandler: ((Double) -> Void)? = nil, completionHandler: (() -> Void)? = nil, errorHandler: ((String) -> Void)? = nil) {
        self.model = model
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
        self.errorHandler = errorHandler
    }

    // MARK: - URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default

        // Validate downloaded file size
        do {
            let fileAttributes = try fileManager.attributesOfItem(atPath: location.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            if fileSize < minimumValidFileSize {
                // File is too small - likely an error response from server
                // Try to read content to provide better error message
                var errorMessage = "Downloaded file is invalid (only \(fileSize) bytes). "
                if let content = try? String(contentsOf: location, encoding: .utf8), content.count < 1000 {
                    errorMessage += "Server response: \(content)"
                } else {
                    errorMessage += "The model download may have failed due to authentication requirements."
                }
                print("Download validation failed: \(errorMessage)")
                try? fileManager.removeItem(at: location)
                notifyFailure(errorMessage)
                return
            }
        } catch {
            print("Failed to validate downloaded file: \(error)")
            try? fileManager.removeItem(at: location)
            notifyFailure("Failed to validate downloaded file: \(error.localizedDescription)")
            return
        }

        // Get destination path using AppDirectoryUtility
        guard let destinationURL = try? AppDirectoryUtility.getModelPath(for: model) else {
            try? fileManager.removeItem(at: location)
            notifyFailure("Failed to get model destination path")
            return
        }

        // Ensure directory exists
        try? AppDirectoryUtility.ensureDirectoryExists()

        // Move the downloaded file to the destination URL
        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            print("File downloaded and moved to: \(destinationURL.path)")
            notifySuccess()
        } catch {
            try? fileManager.removeItem(at: location)
            print("Failed to move downloaded file: \(error)")
            notifyFailure("Failed to save downloaded file: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else {
            DispatchQueue.main.async {
                self.progressHandler?(0.0)
            }
            return
        }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Download failed with error: \(error.localizedDescription)")
            notifyFailure(message(for: error))
        }
    }

    // MARK: - Completion Handling

    private func notifySuccess() {
        guard markCompletionNotified() else { return }

        DispatchQueue.main.async {
            self.completionHandler?()
        }
    }

    private func notifyFailure(_ message: String) {
        guard markCompletionNotified() else { return }

        DispatchQueue.main.async {
            self.errorHandler?(message)
        }
    }

    private func markCompletionNotified() -> Bool {
        completionLock.lock()
        defer { completionLock.unlock() }

        guard !didNotifyCompletion else { return false }
        didNotifyCompletion = true
        return true
    }

    private func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return "Download cancelled."
        }
        return "Download failed: \(error.localizedDescription)"
    }
}

struct ModelDownloadTarget: Equatable {
    let id: String
    let displayName: String
    let fileName: String
    let url: URL
}

final class ModelDownloadManager: ObservableObject {
    static let shared = ModelDownloadManager()

    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentTargetID: String?
    @Published private(set) var currentDisplayName: String?
    @Published var errorMessage: String?

    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: DownloadDelegate?
    private var activeDownloadID: UUID?
    private var isCancellingDownload = false

    private init() {}

    func download(
        target: ModelDownloadTarget,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard !isDownloading else {
            let message = String(localized: "Another model download is already in progress.", comment: "Concurrent model download error")
            errorMessage = message
            completion(false, message)
            return
        }

        do {
            try AppDirectoryUtility.ensureDirectoryExists()
        } catch {
            let message = String(localized: "Failed to prepare the model storage folder: \(error.localizedDescription)", comment: "Model storage error")
            errorMessage = message
            completion(false, message)
            return
        }

        let downloadID = UUID()
        activeDownloadID = downloadID
        isCancellingDownload = false
        isDownloading = true
        progress = 0.0
        currentTargetID = target.id
        currentDisplayName = target.displayName
        errorMessage = nil

        downloadDelegate = DownloadDelegate(
            model: target.fileName,
            progressHandler: { [weak self] progress in
                guard self?.activeDownloadID == downloadID else { return }
                self?.progress = progress
            },
            completionHandler: { [weak self] in
                guard self?.activeDownloadID == downloadID else { return }
                self?.finishDownload(errorMessage: nil)
                completion(true, nil)
            },
            errorHandler: { [weak self] errorMessage in
                guard let self = self else { return }
                guard self.activeDownloadID == downloadID else { return }

                let wasCancelled = self.isCancellingDownload || errorMessage == "Download cancelled."
                self.finishDownload(errorMessage: wasCancelled ? nil : errorMessage)
                completion(false, wasCancelled ? nil : errorMessage)
            }
        )

        downloadDelegate?.cancelAction = { [weak self] in
            self?.progress = 0.0
            self?.downloadTask?.cancel()
        }

        let session = URLSession(configuration: .default, delegate: downloadDelegate, delegateQueue: nil)
        let task = session.downloadTask(with: target.url)
        downloadTask = task
        task.resume()
    }

    func cancelDownload() {
        isCancellingDownload = true
        activeDownloadID = nil
        downloadDelegate?.cancelAction?()
        finishDownload(errorMessage: nil)
    }

    private func finishDownload(errorMessage: String?) {
        isDownloading = false
        progress = 0.0
        currentTargetID = nil
        currentDisplayName = nil
        downloadTask = nil
        downloadDelegate = nil
        activeDownloadID = nil
        isCancellingDownload = false
        self.errorMessage = errorMessage
    }
}
