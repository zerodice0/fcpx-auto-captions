//
//  WhisperSettings.swift
//  Whisper Auto Captions
//
//  Advanced settings for whisper.cpp transcription
//

import Foundation

/// Stores all configurable parameters for whisper.cpp transcription
struct WhisperSettings: Codable, Equatable {
    // MARK: - Basic Settings
    var model: String = "Medium"
    var language: String = "Auto"
    var fps: String = ""
    var selectedFrameRate: String = "30"  // FrameRate.rawValue for persistence
    var customFps: String = "30"

    // MARK: - Quality Settings
    /// Number of candidates to consider for best transcription (1-10)
    var bestOf: Int = 5
    /// Beam search width for decoding (1-10)
    var beamSize: Int = 5
    /// Sampling temperature (0.0 = greedy, higher = more random)
    var temperature: Double = 0.0
    /// Entropy threshold for segment validation
    var entropyThreshold: Double = 2.4
    /// Log probability threshold for segment validation
    var logProbThreshold: Double = -1.0

    // MARK: - Performance Settings
    /// Number of threads for computation
    var threads: Int = 4
    /// Number of processors to use
    var processors: Int = 1
    /// Disable GPU acceleration
    var noGPU: Bool = false
    /// Enable Flash Attention for faster inference
    var flashAttention: Bool = false

    // MARK: - Output Settings
    /// Audio segment duration in seconds for splitting long files (default: 600 = 10 minutes)
    var audioSegmentDuration: Int = 600
    /// Use custom audio segment duration instead of preset
    var useCustomSegmentDuration: Bool = false
    /// Custom audio segment duration in minutes (1-30)
    var customSegmentDurationMinutes: Int = 10
    /// Maximum segment length in characters (0 = no limit)
    var maxLen: Int = 0
    /// Split segments on word boundaries
    var splitOnWord: Bool = false
    /// Disable timestamps in output
    var noTimestamps: Bool = false
    /// Translate to English
    var translate: Bool = false

    // MARK: - Advanced Settings
    /// Initial prompt to guide transcription
    var prompt: String = ""
    /// Threshold for detecting no speech
    var noSpeechThreshold: Double = 0.6
    /// Word timestamp probability threshold
    var wordThreshold: Double = 0.01
    /// Enable speaker diarization
    var diarize: Bool = false
    /// Enable experimental tiny diarization
    var tinyDiarize: Bool = false

    // MARK: - Default Instance
    static let `default` = WhisperSettings()

    // MARK: - Comparison with defaults
    var isDefault: Bool {
        return self == WhisperSettings.default
    }

    // MARK: - Reset to defaults
    mutating func resetToDefaults() {
        self = WhisperSettings.default
    }
}
