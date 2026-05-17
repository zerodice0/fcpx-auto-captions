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
