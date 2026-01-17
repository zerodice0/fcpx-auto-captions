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
            args += ["--prompt", "\"\(effectivePrompt)\""]
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
        selectedModel: String,
        selectedLanguage: String,
        outputWavFilePath: String,
        progressCallback: @escaping ProgressCallback,
        outputCallback: @escaping OutputCallback,
        completion: @escaping CompletionCallback
    ) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            let applicationSupportDirectory = try! fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let whisperAutoCaptionsURL = applicationSupportDirectory.appendingPathComponent("Whisper Auto Captions")
            let modelPath = whisperAutoCaptionsURL.appendingPathComponent("ggml-\(selectedModel.lowercased()).bin")

            guard let mainPath = Bundle.main.path(forResource: "main", ofType: nil) else {
                completion("")
                return
            }

            let task = Process()
            task.launchPath = mainPath
            task.arguments = self.buildArguments(
                settings: settings,
                modelPath: modelPath.path,
                inputPath: outputWavFilePath,
                language: selectedLanguage
            )

            let errorPipe = Pipe()
            let outputPipe = Pipe()

            task.standardError = errorPipe
            task.standardOutput = outputPipe

            task.launch()
            let startTime = Date()

            let errorHandle = errorPipe.fileHandleForReading
            let outputHandle = outputPipe.fileHandleForReading

            while task.isRunning || errorHandle.availableData.count > 0 {
                let errorData = errorHandle.availableData
                if !errorData.isEmpty {
                    if let error = String(data: errorData, encoding: .utf8) {
                        let lines = error.split(separator: "\n")
                        if let lastLine = lines.last, lastLine.hasPrefix("whisper_full_with_state: progress") {
                            if let progressString = lastLine.components(separatedBy: "=").last?
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .dropLast() {
                                let progressPercentage = Int(progressString) ?? 0
                                let progress = Double(progressPercentage) * 0.01

                                let currentTime = Date()
                                let elapsed = currentTime.timeIntervalSince(startTime)
                                let remainingSeconds = progress > 0 ? round((1 - progress) / progress * elapsed) : 0
                                let remainingTime = self.formatSeconds(remainingSeconds)

                                DispatchQueue.main.async {
                                    progressCallback(progressPercentage, progress, remainingTime)
                                }
                            }
                        }
                    }
                }

                let outputData = outputHandle.availableData
                if !outputData.isEmpty {
                    if let output = String(data: outputData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            outputCallback(output)
                        }
                    }
                }
            }

            task.waitUntilExit()

            DispatchQueue.main.async {
                progressCallback(100, 1.0, "00:00")
            }

            // Read any remaining output
            _ = outputHandle.readDataToEndOfFile()

            let srtFilePath = outputWavFilePath + ".srt"
            completion(srtFilePath)
        }
    }

    // MARK: - Helpers
    private func formatSeconds(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad

        if seconds >= 3600 {
            formatter.maximumUnitCount = 3
        } else {
            formatter.maximumUnitCount = 2
            formatter.allowedUnits = [.minute, .second]
        }

        return formatter.string(from: seconds) ?? "00:00"
    }

    // MARK: - Model Path
    func getModelPath(for model: String) -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let whisperAutoCaptionsURL = applicationSupportDirectory.appendingPathComponent("Whisper Auto Captions")
        return whisperAutoCaptionsURL.appendingPathComponent("ggml-\(model.lowercased()).bin")
    }

    func isModelDownloaded(_ model: String) -> Bool {
        let modelPath = getModelPath(for: model)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
}
