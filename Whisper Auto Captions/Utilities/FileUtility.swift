import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - File Utility
struct FileUtility {
    
    // MARK: - Time Formatting
    /// Format seconds into a human-readable time string (MM:SS or HH:MM:SS)
    /// - Parameter seconds: The number of seconds to format
    /// - Returns: Formatted time string
    static func formatSeconds(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        if seconds >= 3600 {
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.maximumUnitCount = 3
        } else {
            formatter.allowedUnits = [.minute, .second]
            formatter.maximumUnitCount = 2
        }
        
        return formatter.string(from: seconds) ?? "00:00"
    }
    
    // MARK: - File Selection
    /// Present a file selection dialog
    /// - Parameters:
    ///   - allowedTypes: Array of UTTypes to allow
    ///   - allowDirectories: Whether to allow directory selection
    ///   - completion: Callback with selected URL or nil if cancelled
    static func selectFile(
        allowedTypes: [UTType],
        allowDirectories: Bool = false,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowDirectories
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedTypes
        
        if panel.runModal() == .OK {
            completion(panel.urls.first)
        } else {
            completion(nil)
        }
    }
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
