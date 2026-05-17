//
//  WhisperService.swift
//  Whisper Auto Captions
//
//  Handles whisper.cpp execution and argument building
//

import Foundation

/// Service for running whisper.cpp transcription
class WhisperService {
    // MARK: - Singleton
    static let shared = WhisperService()
    private init() {}

    // MARK: - Progress Callback Types
    typealias ProgressCallback = (Int, Double, String) -> Void  // (percentage, progress, remainingTime)
    typealias OutputCallback = (String) -> Void
    typealias CompletionCallback = (String) -> Void  // srtFilePath

    // MARK: - Build Arguments
    /// Build command line arguments for whisper.cpp based on settings
    func buildArguments(
        settings: WhisperSettings,
        modelPath: String,
        inputPath: String,
        language: String
    ) -> [String] {
        var args = ["-m", modelPath]

        // Language
        if let langCode = LanguageData.code(for: language) {
            args += ["-l", langCode]
        }

        // Standard output options
        args += ["-pp", "-osrt", "-f", inputPath]

        // Quality settings (only add if different from defaults)
        if settings.bestOf != 5 {
            args += ["--best-of", "\(settings.bestOf)"]
        }
        if settings.beamSize != 5 {
            args += ["--beam-size", "\(settings.beamSize)"]
        }
        if settings.temperature != 0.0 {
            args += ["--temperature", "\(settings.temperature)"]
        }
        if settings.entropyThreshold != 2.4 {
            args += ["--entropy-thold", "\(settings.entropyThreshold)"]
        }
        if settings.logProbThreshold != -1.0 {
            args += ["--logprob-thold", "\(settings.logProbThreshold)"]
        }

        // Performance settings
        if settings.threads != 4 {
            args += ["-t", "\(settings.threads)"]
        }
        if settings.processors != 1 {
            args += ["-p", "\(settings.processors)"]
        }
        if settings.noGPU {
            args += ["--no-gpu"]
        }
        if settings.flashAttention {
            args += ["--flash-attn"]
        }

        // Output settings
        if settings.maxLen > 0 {
            args += ["--max-len", "\(settings.maxLen)"]
        }
        if settings.splitOnWord {
            args += ["--split-on-word"]
        }
        if settings.noTimestamps {
            args += ["--no-timestamps"]
        }
        if settings.translate {
            args += ["--translate"]
        }

        // Advanced settings
        let effectivePrompt = settings.prompt.isEmpty ? LanguageData.defaultPrompt(for: language) : settings.prompt
        if !effectivePrompt.isEmpty {
            args += ["--prompt", effectivePrompt]
        }

        if settings.noSpeechThreshold != 0.6 {
            args += ["--no-speech-thold", "\(settings.noSpeechThreshold)"]
        }
        if settings.wordThreshold != 0.01 {
            args += ["--word-thold", "\(settings.wordThreshold)"]
        }
        if settings.diarize {
            args += ["--diarize"]
        }
        if settings.tinyDiarize {
            args += ["--tinydiarize"]
        }

        return args
    }

    // MARK: - Run Transcription
    /// Run whisper.cpp transcription on a WAV file
    func transcribe(
        settings: WhisperSettings,
        modelPath: String,
        selectedLanguage: String,
        outputWavFilePath: String,
        progressCallback: @escaping ProgressCallback,
        outputCallback: @escaping OutputCallback,
        completion: @escaping CompletionCallback
    ) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            guard let whisperCliPath = Bundle.main.path(forResource: "whisper-cli", ofType: nil) else {
                completion("")
                return
            }

            let task = Process()
            task.launchPath = whisperCliPath
            task.arguments = self.buildArguments(
                settings: settings,
                modelPath: modelPath,
                inputPath: outputWavFilePath,
                language: selectedLanguage
            )

            let errorPipe = Pipe()
            let outputPipe = Pipe()

            task.standardError = errorPipe
            task.standardOutput = outputPipe

            let startTime = Date()

            let errorHandle = errorPipe.fileHandleForReading
            let outputHandle = outputPipe.fileHandleForReading

            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let error = String(data: data, encoding: .utf8) {
                    let lines = error.split(whereSeparator: \.isNewline)
                    if let lastLine = lines.last, lastLine.hasPrefix("whisper_full_with_state: progress") {
                        if let progressString = lastLine.components(separatedBy: "=").last?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .dropLast() {
                            let progressPercentage = Int(progressString) ?? 0
                            let progress = Double(progressPercentage) * 0.01

                            let currentTime = Date()
                            let elapsed = currentTime.timeIntervalSince(startTime)
                            let remainingSeconds = progress > 0 ? round((1 - progress) / progress * elapsed) : 0
                            let remainingTime = FileUtility.formatSeconds(remainingSeconds)

                            DispatchQueue.main.async {
                                progressCallback(progressPercentage, progress, remainingTime)
                            }
                        }
                    }
                }
            }

            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputCallback(output)
                    }
                }
            }

            task.terminationHandler = { terminatedTask in
                errorHandle.readabilityHandler = nil
                outputHandle.readabilityHandler = nil
                _ = outputHandle.readDataToEndOfFile()
                _ = errorHandle.readDataToEndOfFile()

                if terminatedTask.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        progressCallback(100, 1.0, "00:00")
                    }
                }

                let srtFilePath = outputWavFilePath + ".srt"
                if terminatedTask.terminationStatus == 0 && SRTService.shared.isValidSRTFile(srtFilePath) {
                    completion(srtFilePath)
                } else {
                    completion("")
                }
            }

            task.launch()
        }
    }
}
