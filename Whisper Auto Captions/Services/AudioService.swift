//
//  AudioService.swift
//  Whisper Auto Captions
//
//  Handles audio file conversion and splitting
//

import Foundation
import AVFoundation

/// Service for audio file operations
class AudioService {
    // MARK: - Singleton
    static let shared = AudioService()
    private init() {}

    // MARK: - Constants
    private let segmentDuration: Double = 600  // 10 minutes in seconds

    // MARK: - MP3 to WAV Conversion
    /// Convert MP3 file to 16kHz WAV format required by whisper.cpp
    func mp3ToWav(filePathString: String, projectName: String, tempFolder: String) -> String {
        var wavFileName = projectName + ".wav"
        var wavFilePath = tempFolder + wavFileName

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: wavFilePath) {
            // Rename the file if it already exists
            var counter = 1
            while fileManager.fileExists(atPath: wavFilePath) {
                wavFileName = "\(projectName)_\(counter).wav"
                wavFilePath = tempFolder + wavFileName
                counter += 1
            }
        }

        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            return wavFilePath
        }

        let task = Process()
        task.launchPath = ffmpegPath
        task.arguments = ["-i", filePathString, "-ar", "16000", wavFilePath]
        task.launch()
        task.waitUntilExit()

        return wavFilePath
    }

    // MARK: - Split WAV File
    /// Split a WAV file into 10-minute segments for processing
    func splitWav(inputFilePath: String) -> [String] {
        var result: [String] = []

        let fileURL = URL(fileURLWithPath: inputFilePath)
        guard let asset = try? AVAudioPlayer(contentsOf: fileURL),
              asset.duration > 0 else {
            return [inputFilePath]
        }

        let duration: TimeInterval = asset.duration

        // If duration is less than segment duration, return original file
        if duration < segmentDuration {
            return [inputFilePath]
        }

        let numberOfSegments = Int(ceil(duration / segmentDuration) - 1)
        let outputPrefix = "\(inputFilePath)_p"

        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            return [inputFilePath]
        }

        for i in 0...numberOfSegments {
            let outputFilePath = "\(outputPrefix)\(i).wav"

            let task = Process()
            task.launchPath = ffmpegPath
            task.arguments = [
                "-i", inputFilePath,
                "-ss", String(i * Int(segmentDuration)),
                "-t", String(Int(segmentDuration)),
                "-c", "copy",
                outputFilePath
            ]
            task.launch()
            task.waitUntilExit()
            result.append(outputFilePath)
        }

        return result
    }

    // MARK: - Get Audio Duration
    /// Get the duration of an audio file in seconds
    func getAudioDuration(filePath: String) -> TimeInterval? {
        let fileURL = URL(fileURLWithPath: filePath)
        guard let asset = try? AVAudioPlayer(contentsOf: fileURL) else {
            return nil
        }
        return asset.duration
    }

    // MARK: - Cleanup
    /// Remove temporary WAV files
    func cleanupTempFiles(paths: [String]) {
        let fileManager = FileManager.default
        for path in paths {
            try? fileManager.removeItem(atPath: path)
        }
    }
}
