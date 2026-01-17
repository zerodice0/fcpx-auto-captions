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
    var cancelAction: (() -> Void)?

    // MARK: - Initialization
    init(model: String, progressHandler: ((Double) -> Void)? = nil, completionHandler: (() -> Void)? = nil) {
        self.model = model
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
    }

    // MARK: - URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
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
