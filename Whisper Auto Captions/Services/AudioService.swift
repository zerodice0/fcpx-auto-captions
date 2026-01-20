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
    private let whisperSampleRate: Double = 16000  // Required sample rate for whisper.cpp

    // MARK: - Audio Analysis

    /// Get the sample rate of an audio file
    func getAudioSampleRate(_ path: String) -> Double? {
        let url = URL(fileURLWithPath: path)
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        return audioFile.processingFormat.sampleRate
    }

    /// Check if the audio file needs conversion for whisper.cpp
    /// Returns false only if it's already a 16kHz WAV file
    func needsConversion(_ path: String) -> Bool {
        // Not a WAV file -> needs conversion
        guard path.lowercased().hasSuffix(".wav") else { return true }

        // Check sample rate - must be 16kHz for whisper.cpp
        guard let sampleRate = getAudioSampleRate(path),
              sampleRate == whisperSampleRate else { return true }

        return false
    }

    // MARK: - Audio Preparation

    /// Prepare input audio file for whisper.cpp processing
    /// - If input is already a 16kHz WAV, returns the original path (no conversion)
    /// - Otherwise, converts to 16kHz mono WAV using ffmpeg
    func prepareAudioForWhisper(inputPath: String, projectName: String, tempFolder: String) -> String {
        // Skip conversion if already a 16kHz WAV file
        if !needsConversion(inputPath) {
            return inputPath
        }

        // Generate output path
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

        // Convert to 16kHz mono 16-bit PCM WAV
        let task = Process()
        task.launchPath = ffmpegPath
        task.arguments = ["-i", inputPath, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wavFilePath]
        task.launch()
        task.waitUntilExit()

        return wavFilePath
    }

    // MARK: - Split WAV File
    /// Split a WAV file into segments for processing
    /// - Parameters:
    ///   - inputFilePath: Path to the input WAV file
    ///   - segmentDuration: Duration of each segment in seconds (default: 600 = 10 minutes)
    /// - Returns: Array of paths to the split WAV files
    func splitWav(inputFilePath: String, segmentDuration: Double = 600) -> [String] {
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
