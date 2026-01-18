import Foundation
import AVFoundation
import Combine

// MARK: - Home ViewModel
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var fileURL: URL?
    @Published var fileName: String = ""
    @Published var projectName: String = ""
    @Published var isSelected: Bool = false
    @Published var selectedFrameRate: FrameRate = .fps30
    @Published var customFps: String = "30"
    @Published var selectedLanguage = "Auto"
    @Published var selectedModel = "Medium"
    @Published var selectedPreset: WhisperPreset = .balanced
    @Published var showSettings = false
    
    // Download state
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var showAlert = false
    
    // Processing state
    @Published var startCreatingAutoCaptions = false
    @Published var progress = 0.0
    @Published var progressPercentage = 0
    @Published var totalBatch = 100000
    @Published var currentBatch = -100000
    @Published var remainingTime = "00:00"
    @Published var status = "Spliting audio file by every 10 minutes···"
    @Published var outputCaptions = ""
    @Published var outputSRTFilePath = ""
    @Published var outputFCPXMLFilePath = ""
    
    // MARK: - Private Properties
    private var downloadDelegate: DownloadDelegate?
    private var downloadTask: URLSessionDownloadTask?
    
    // MARK: - Data
    let languages = LanguageData.languages
    let languagesMapping = LanguageData.languageToCode
    let models = ModelData.models
    let modelsMapping = ModelData.modelToFileName
    
    // MARK: - Computed Properties
    var currentFps: Float {
        if selectedFrameRate == .custom {
            return Float(customFps) ?? 30.0
        }
        return selectedFrameRate.value
    }
    
    var isFpsValid: Bool {
        return FrameRate.isValidFrameRate(currentFps)
    }
    
    // MARK: - File Selection
    func selectFile(url: URL) {
        self.fileURL = url
        self.fileName = url.lastPathComponent
        self.projectName = (url.lastPathComponent as NSString).deletingPathExtension
    }
    
    // MARK: - Model Download
    func downloadModel(model: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(model.lowercased()).bin") else {
            completion(false)
            return
        }

        self.downloadDelegate = DownloadDelegate(model: selectedModel, progressHandler: { [weak self] progress in
            DispatchQueue.main.async { self?.downloadProgress = progress }
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.isDownloading = false
                self?.showAlert = false
            }
            completion(true)
        }, errorHandler: { [weak self] errorMessage in
            DispatchQueue.main.async {
                self?.isDownloading = false
                self?.showAlert = false
            }
            completion(false)
        })
        
        self.downloadDelegate?.cancelAction = { [weak self] in
            self?.downloadProgress = 0.0
            self?.downloadTask?.cancel()
        }
    
        let session = URLSession(configuration: .default, delegate: self.downloadDelegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        self.isDownloading = true
        self.showAlert = true
        task.resume()
    }
    
    func cancelDownload() {
        self.downloadDelegate?.cancelAction?()
        self.isDownloading = false
        self.showAlert = false
    }
    
    // MARK: - Main Processing
    func startTranscription() {
        guard let fileURL = fileURL else { return }
        
        self.startCreatingAutoCaptions = true
        let filePathString = fileURL.path
        let tempFolder = NSTemporaryDirectory()

        // Use AudioService for conversion
        let outputWavFilePath = AudioService.shared.mp3ToWav(
            filePathString: filePathString,
            projectName: projectName,
            tempFolder: tempFolder
        )

        let splitedWavFilesPaths = AudioService.shared.splitWav(inputFilePath: outputWavFilePath)
        self.totalBatch = splitedWavFilesPaths.count
        self.status = "Generating AI subtitles"

        var srtFiles = [String]()

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let group = DispatchGroup()

            for (b, splitedWavFilePath) in splitedWavFilesPaths.enumerated() {
                DispatchQueue.main.async { self.currentBatch = b + 1 }
                var outputSplitSRTFilePath: String?
                group.enter()
                self.runWhisperCli(outputWavFilePath: splitedWavFilePath) { srtFilePath in
                    outputSplitSRTFilePath = srtFilePath
                    group.leave()
                }
                group.wait()

                if let srtFilePath = outputSplitSRTFilePath, !srtFilePath.isEmpty {
                    DispatchQueue.main.async {
                        srtFiles.append(srtFilePath)
                        self.progress = 0.0
                        self.progressPercentage = 0
                    }
                }
            }

            DispatchQueue.main.async {
                self.progress = 1.0
                self.progressPercentage = 100

                if srtFiles.isEmpty {
                    self.status = "Error: No subtitles generated"
                    self.startCreatingAutoCaptions = false
                    return
                }

                // Use SRTService for merging
                let outputSRTFilePath = SRTService.shared.mergeSRT(srtFiles: srtFiles)
                self.status = "Done"
                self.outputFCPXMLFilePath = FCPXMLService.srtToFCPXML(
                    srtPath: outputSRTFilePath,
                    fps: self.currentFps,
                    projectName: self.projectName,
                    language: self.selectedLanguage
                )
                self.outputSRTFilePath = outputSRTFilePath
            }
        }
    }
    
    // MARK: - Whisper CLI Execution
    private func runWhisperCli(outputWavFilePath: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion("")
                return
            }
            
            guard let modelPath = try? AppDirectoryUtility.getModelPath(for: selectedModel) else {
                completion("")
                return
            }
            
            guard let whisperCliPath = Bundle.main.path(forResource: "whisper-cli", ofType: nil),
                  let langCode = languagesMapping[selectedLanguage] else {
                completion("")
                return
            }

            let task = Process()
            task.launchPath = whisperCliPath
            task.arguments = self.buildWhisperArgs(modelPath: modelPath.path, wavPath: outputWavFilePath, langCode: langCode)

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
                if !errorData.isEmpty, let error = String(data: errorData, encoding: .utf8) {
                    self.parseProgress(from: error, startTime: startTime)
                }
                let outputData = outputHandle.availableData
                if !outputData.isEmpty, let captions = String(data: outputData, encoding: .utf8) {
                    DispatchQueue.main.async { self.outputCaptions += captions }
                }
            }
            
            task.waitUntilExit()
            DispatchQueue.main.async {
                self.progress = 1.0
                self.progressPercentage = 100
                self.remainingTime = "00:00"
            }

            let srtFilePath = outputWavFilePath + ".srt"
            self.validateSrtFile(srtFilePath, completion: completion)
        }
    }
    
    private func buildWhisperArgs(modelPath: String, wavPath: String, langCode: String) -> [String] {
        var args = ["-m", modelPath, "-l", langCode, "-pp", "-osrt", "-f", wavPath]
        if langCode == "zh" {
            let prompt = selectedLanguage == "Chinese Simplified" ? "以下是普通话的句子" : "以下是普通話的句子"
            args += ["--prompt", "\"\(prompt)\""]
        }
        return args
    }
    
    private func parseProgress(from error: String, startTime: Date) {
        let lines = error.split(separator: "\n")
        guard let lastLine = lines.last,
              lastLine.hasPrefix("whisper_full_with_state: progress"),
              let progressStr = lastLine.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines).dropLast() else {
            return
        }
        
        let pct = Int(progressStr) ?? 0
        let prog = Double(pct) * 0.01
        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = prog > 0 ? round((1 - prog) / prog * elapsed) : 0
        
        DispatchQueue.main.async {
            self.progressPercentage = pct
            self.progress = prog
            self.remainingTime = FileUtility.formatSeconds(remaining)
        }
    }
    
    private func validateSrtFile(_ path: String, completion: @escaping (String) -> Void) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0,
              let content = try? String(contentsOfFile: path, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              content.contains("-->") else {
            completion("")
            return
        }
        completion(path)
    }

    // MARK: - Reset
    func reset() {
        outputCaptions = ""
        progress = 0.0
        progressPercentage = 0
        remainingTime = "00:00"
        startCreatingAutoCaptions = false
        outputSRTFilePath = ""
        outputFCPXMLFilePath = ""
        totalBatch = 100000
        currentBatch = -100000
        status = "Spliting audio file by every 10 minutes···"
    }
    
    // MARK: - Model Validation
    func validateAndStartTranscription() {
        let fm = FileManager.default
        
        // Ensure app directory exists
        try? AppDirectoryUtility.ensureDirectoryExists()
        
        guard let modelFileName = modelsMapping[selectedModel],
              let modelPath = try? AppDirectoryUtility.getModelPath(for: modelFileName) else { return }

        if fm.fileExists(atPath: modelPath.path) {
            let attrs = try? fm.attributesOfItem(atPath: modelPath.path)
            let size = attrs?[.size] as? Int64 ?? 0
            if size >= 50 * 1024 * 1024 {
                startTranscription()
            } else {
                try? fm.removeItem(at: modelPath)
                downloadModel(model: modelFileName) { [weak self] success in
                    if success { self?.startTranscription() }
                }
            }
        } else {
            downloadModel(model: modelFileName) { [weak self] success in
                if success { self?.startTranscription() }
            }
        }
    }
}
