//
//  AppDirectoryUtility.swift
//  Whisper Auto Captions
//
//  Centralized utility for app directory and model path management
//

import Foundation

/// Utility for managing application directories and model paths
enum AppDirectoryUtility {
    
    /// Application support directory name
    private static let appDirectoryName = "Whisper Auto Captions"
    
    // MARK: - Directory Access
    
    /// Get the application support directory for Whisper Auto Captions
    /// - Returns: URL to the app's directory in Application Support
    /// - Throws: Error if directory cannot be accessed or created
    static func getAppSupportDirectory() throws -> URL {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent(appDirectoryName)
    }
    
    /// Ensure the app support directory exists
    /// - Throws: Error if directory cannot be created
    static func ensureDirectoryExists() throws {
        let directory = try getAppSupportDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    // MARK: - Model Path Management
    
    /// Get the full path for a Whisper model file
    /// - Parameter model: Model name (e.g., "Medium", "large-v3")
    /// - Returns: URL to the model file
    /// - Throws: Error if directory cannot be accessed
    static func getModelPath(for model: String) throws -> URL {
        let directory = try getAppSupportDirectory()
        return directory.appendingPathComponent("ggml-\(model.lowercased()).bin")
    }
    
    /// Check if a model file exists
    /// - Parameter model: Model name to check
    /// - Returns: true if the model file exists and is accessible
    static func isModelDownloaded(_ model: String) -> Bool {
        guard let modelPath = try? getModelPath(for: model) else {
            return false
        }
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Get the size of a downloaded model file
    /// - Parameter model: Model name to check
    /// - Returns: File size in bytes, or nil if file doesn't exist
    static func getModelSize(_ model: String) -> Int64? {
        guard let modelPath = try? getModelPath(for: model),
              let attrs = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }
    
    /// Minimum valid model file size (50MB) - smallest model is ~75MB
    static let minimumValidModelSize: Int64 = 50 * 1024 * 1024
    
    /// Check if a model file is valid (exists and has sufficient size)
    /// - Parameter model: Model name to check
    /// - Returns: true if model exists and is valid
    static func isModelValid(_ model: String) -> Bool {
        guard let size = getModelSize(model) else {
            return false
        }
        return size >= minimumValidModelSize
    }
}
