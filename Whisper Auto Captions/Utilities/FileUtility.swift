import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - File Utility
struct FileUtility {
    static func saveFileWithDialog(filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileManager = FileManager.default

        // Verify source file exists
        guard fileManager.fileExists(atPath: filePath) else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileURL.lastPathComponent
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = String(localized: "Save File", comment: "Save panel title")
        savePanel.message = String(localized: "Choose a location to save the file", comment: "Save panel message")

        // Set allowed file type based on the file extension
        let fileExtension = fileURL.pathExtension
        if let contentType = UTType(filenameExtension: fileExtension) {
            savePanel.allowedContentTypes = [contentType]
        }

        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                do {
                    // Remove existing file if it exists at destination
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: fileURL, to: destinationURL)
                } catch {
                    // Handle error silently
                }
            }
        }
    }
}
