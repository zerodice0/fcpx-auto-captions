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
                DispatchQueue.main.async {
                    self.errorHandler?(errorMessage)
                }
                return
            }
        } catch {
            print("Failed to validate downloaded file: \(error)")
            try? fileManager.removeItem(at: location)
            DispatchQueue.main.async {
                self.errorHandler?("Failed to validate downloaded file: \(error.localizedDescription)")
            }
            return
        }

        let applicationSupportDirectory = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let whisperAutoCaptionsURL = applicationSupportDirectory.appendingPathComponent("Whisper Auto Captions")

        // Ensure directory exists
        try? fileManager.createDirectory(at: whisperAutoCaptionsURL, withIntermediateDirectories: true, attributes: nil)

        let destinationURL = whisperAutoCaptionsURL.appendingPathComponent("ggml-\(model.lowercased()).bin")

        // Move the downloaded file to the destination URL
        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            print("File downloaded and moved to: \(destinationURL.path)")
            DispatchQueue.main.async {
                self.completionHandler?()
            }
        } catch {
            try? fileManager.removeItem(at: location)
            print("Failed to move downloaded file: \(error)")
            DispatchQueue.main.async {
                self.errorHandler?("Failed to save downloaded file: \(error.localizedDescription)")
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Download failed with error: \(error.localizedDescription)")
        }
    }
}
