import Foundation
import AVFoundation

// MARK: - Home ViewModel
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var fileURL: URL?
    @Published var fileName: String = ""
    @Published var projectName: String = ""
    @Published var isSelected: Bool = false
    @Published var selectedFrameRate: FrameRate = .fps30 {
        didSet { saveFrameRateSettings() }
    }
    @Published var customFps: String = "30" {
        didSet { saveFrameRateSettings() }
    }
    @Published var selectedLanguage = "Auto" {
        didSet { saveLanguageSetting() }
    }
    @Published var selectedModel = "Medium" {
        didSet { saveModelSetting() }
    }
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
    @Published var status = "Splitting audio file..."
    @Published var outputCaptions = ""
    @Published var outputSRTFilePath = ""
    @Published var outputFCPXMLFilePath = ""
    
    // MARK: - Private Properties
    private var downloadDelegate: DownloadDelegate?
    private var downloadTask: URLSessionDownloadTask?
    private var isInitializing = true  // Prevents saving during init

    // MARK: - Initialization
    init() {
        let settings = SettingsManager.shared.settings

        // Restore FPS settings
        if let frameRate = FrameRate(rawValue: settings.selectedFrameRate) {
            self.selectedFrameRate = frameRate
        }
        self.customFps = settings.customFps

        // Restore language and model
        self.selectedLanguage = settings.language
        self.selectedModel = settings.model

        // Mark initialization complete
        isInitializing = false
    }

    // MARK: - Settings Persistence
    private func saveFrameRateSettings() {
        guard !isInitializing else { return }
        SettingsManager.shared.settings.selectedFrameRate = selectedFrameRate.rawValue
        SettingsManager.shared.settings.customFps = customFps
    }

    private func saveLanguageSetting() {
        guard !isInitializing else { return }
        SettingsManager.shared.settings.language = selectedLanguage
    }

    private func saveModelSetting() {
        guard !isInitializing else { return }
        SettingsManager.shared.settings.model = selectedModel
    }

    // MARK: - Data
    let languages = LanguageData.languages
    let languagesMapping = LanguageData.languageToCode
    let models = ModelData.models
    let modelsMapping = ModelData.modelToFileName

    // MARK: - Custom Models
    private let customModelManager = CustomModelManager.shared

    /// All available custom models
    var customModels: [CustomModel] {
        customModelManager.customModels
    }

    /// Check if the selected model is a custom model
    var isCustomModelSelected: Bool {
        customModelManager.isCustomModel(selectedModel)
    }

    /// Get the path for the currently selected model
    func getSelectedModelPath() -> URL? {
        // Check if it's a custom model first
        if let customModel = customModelManager.findModel(byName: selectedModel) {
            return try? customModelManager.getCustomModelPath(for: customModel)
        }

        // Fall back to built-in model
        guard let modelFileName = modelsMapping[selectedModel] else { return nil }
        return try? AppDirectoryUtility.getModelPath(for: modelFileName)
    }
    
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

        // Extract frame rate from video files
        if VideoService.shared.isVideoFile(url: url) {
            Task {
                await extractAndSetFrameRate(from: url)
            }
        }
    }

    /// Extract frame rate from video and update settings
    @MainActor
    private func extractAndSetFrameRate(from url: URL) async {
        guard let fps = await VideoService.shared.extractFrameRate(from: url) else {
            return
        }

        if let matchedFrameRate = FrameRate.fromValue(fps) {
            selectedFrameRate = matchedFrameRate
        } else if FrameRate.isValidFrameRate(fps) {
            selectedFrameRate = .custom
            customFps = String(format: "%.3f", fps)
        }
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

        // Prepare audio for whisper.cpp (converts to 16kHz WAV if needed)
        let outputWavFilePath = AudioService.shared.prepareAudioForWhisper(
            inputPath: filePathString,
            projectName: projectName,
            tempFolder: tempFolder
        )

        let segmentDuration = Double(SettingsManager.shared.settings.audioSegmentDuration)
        let splitedWavFilesPaths = AudioService.shared.splitWav(inputFilePath: outputWavFilePath, segmentDuration: segmentDuration)
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

            guard let modelPath = self.getSelectedModelPath() else {
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
        status = "Splitting audio file..."
    }
    
    // MARK: - Model Validation
    func validateAndStartTranscription() {
        let fm = FileManager.default

        // Ensure app directory exists
        try? AppDirectoryUtility.ensureDirectoryExists()

        // Handle custom models
        if let customModel = customModelManager.findModel(byName: selectedModel) {
            validateAndStartCustomModel(customModel)
            return
        }

        // Handle built-in models
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

    /// Validate and start transcription for a custom model
    private func validateAndStartCustomModel(_ model: CustomModel) {
        let fm = FileManager.default

        guard let modelPath = try? customModelManager.getCustomModelPath(for: model) else {
            return
        }

        if fm.fileExists(atPath: modelPath.path) {
            let attrs = try? fm.attributesOfItem(atPath: modelPath.path)
            let size = attrs?[.size] as? Int64 ?? 0
            if size >= 50 * 1024 * 1024 {
                startTranscription()
            } else {
                // File exists but is too small - need to re-download
                try? fm.removeItem(at: modelPath)
                downloadCustomModel(model)
            }
        } else {
            // Model not downloaded yet
            downloadCustomModel(model)
        }
    }

    /// Download a custom model and start transcription when complete
    private func downloadCustomModel(_ model: CustomModel) {
        guard case .url = model.source else {
            // Local models should already be imported - can't download
            return
        }

        isDownloading = true
        showAlert = true

        customModelManager.downloadModel(model) { [weak self] success in
            DispatchQueue.main.async {
                self?.isDownloading = false
                self?.showAlert = false
                if success {
                    self?.startTranscription()
                }
            }
        }
    }
}
