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
    enum TranscriptionState: Equatable {
        case idle
        case running
        case succeeded
        case cancelled
        case failed(String)
    }

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
    @Published var processingState: TranscriptionState = .idle
    
    // MARK: - Private Properties
    private var downloadDelegate: DownloadDelegate?
    private var downloadTask: URLSessionDownloadTask?
    private var isInitializing = true  // Prevents saving during init
    private let minimumValidModelSize: Int64 = 50 * 1024 * 1024
    private let transcriptionControlQueue = DispatchQueue(label: "WhisperAutoCaptions.HomeViewModel.transcription")
    private var activeWhisperProcess: Process?
    private var cancellationRequested = false

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

    var isProcessingComplete: Bool {
        if case .succeeded = processingState { return true }
        return false
    }

    var isProcessingRunning: Bool {
        if case .running = processingState { return true }
        return false
    }

    var isProcessingFinished: Bool {
        return !isProcessingRunning
    }

    var canStartTranscription: Bool {
        return fileURL != nil && isFpsValid && !SettingsManager.shared.settings.noTimestamps
    }

    var transcriptionBlockReason: String? {
        if fileURL == nil {
            return nil
        }
        if !isFpsValid {
            return String(localized: "Frame rate must be between 0 and 120.", comment: "Invalid frame rate transcription warning")
        }
        if SettingsManager.shared.settings.noTimestamps {
            return String(localized: "Disable Timestamps must be turned off to create SRT and FCPXML captions.", comment: "No timestamps transcription warning")
        }
        return nil
    }

    private var hasCancellationRequest: Bool {
        transcriptionControlQueue.sync {
            cancellationRequested
        }
    }

    private func beginTranscriptionRun() {
        transcriptionControlQueue.sync {
            cancellationRequested = false
            activeWhisperProcess = nil
        }
    }

    private func setActiveWhisperProcess(_ process: Process?) {
        transcriptionControlQueue.sync {
            activeWhisperProcess = process
        }
    }

    func cancelTranscription() {
        let process = transcriptionControlQueue.sync { () -> Process? in
            cancellationRequested = true
            return activeWhisperProcess
        }

        process?.terminate()
        status = String(localized: "Cancelling...", comment: "Transcription cancellation in progress status")
    }

    private func finishCancelledTranscription() {
        setActiveWhisperProcess(nil)
        let update = {
            self.progress = 0.0
            self.progressPercentage = 0
            self.remainingTime = "00:00"
            self.status = String(localized: "Cancelled", comment: "Transcription cancelled status")
            self.processingState = .cancelled
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
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
        guard let modelPath = getSelectedModelPath() else {
            status = "Error: Model file not found"
            processingState = .failed(status)
            return
        }

        beginTranscriptionRun()
        self.startCreatingAutoCaptions = true
        self.processingState = .running
        self.outputCaptions = ""
        let settings = SettingsManager.shared.settings
        let filePathString = fileURL.path
        let tempFolder = NSTemporaryDirectory()
        let projectName = self.projectName
        let fps = self.currentFps
        let language = self.selectedLanguage
        self.totalBatch = 100000
        self.status = String(localized: "Preparing audio...", comment: "Preparing audio status")
        self.currentBatch = -100000
        self.progress = 0.0
        self.progressPercentage = 0
        self.remainingTime = "00:00"
        self.outputSRTFilePath = ""
        self.outputFCPXMLFilePath = ""

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            // Prepare audio for whisper.cpp (converts to 16kHz WAV if needed)
            let outputWavFilePath = AudioService.shared.prepareAudioForWhisper(
                inputPath: filePathString,
                projectName: projectName,
                tempFolder: tempFolder
            )

            if self.hasCancellationRequest {
                self.finishCancelledTranscription()
                return
            }

            guard FileManager.default.fileExists(atPath: outputWavFilePath) else {
                DispatchQueue.main.async {
                    self.status = "Error: Failed to prepare audio"
                    self.processingState = .failed(self.status)
                }
                return
            }

            let segmentDuration = Double(settings.audioSegmentDuration)
            let validSegmentDuration = segmentDuration > 0 ? segmentDuration : 600.0
            let splitWavFilePaths = AudioService.shared.splitWav(inputFilePath: outputWavFilePath, segmentDuration: validSegmentDuration)

            if self.hasCancellationRequest {
                self.finishCancelledTranscription()
                return
            }

            DispatchQueue.main.async {
                self.totalBatch = splitWavFilePaths.count
                self.status = "Generating AI subtitles"
                self.currentBatch = 0
                self.transcribeSegments(
                    wavPaths: splitWavFilePaths,
                    nextIndex: 0,
                    srtFiles: [],
                    modelPath: modelPath.path,
                    settings: settings,
                    selectedLanguage: language,
                    segmentDurationSeconds: validSegmentDuration,
                    fps: fps,
                    projectName: projectName
                )
            }
        }
    }

    private func transcribeSegments(
        wavPaths: [String],
        nextIndex: Int,
        srtFiles: [String],
        modelPath: String,
        settings: WhisperSettings,
        selectedLanguage: String,
        segmentDurationSeconds: TimeInterval,
        fps: Float,
        projectName: String
    ) {
        if hasCancellationRequest {
            finishCancelledTranscription()
            return
        }

        guard nextIndex < wavPaths.count else {
            finishTranscription(
                srtFiles: srtFiles,
                segmentDurationSeconds: segmentDurationSeconds,
                fps: fps,
                projectName: projectName
            )
            return
        }

        currentBatch = nextIndex + 1
        transcribeSegment(
            wavPath: wavPaths[nextIndex],
            modelPath: modelPath,
            settings: settings,
            selectedLanguage: selectedLanguage
        ) { [weak self] srtFilePath in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if self.hasCancellationRequest {
                    self.finishCancelledTranscription()
                    return
                }

                guard !srtFilePath.isEmpty else {
                    self.failTranscription("Error: Failed to generate subtitles for batch \(nextIndex + 1)")
                    return
                }

                var nextSRTFiles = srtFiles
                nextSRTFiles.append(srtFilePath)
                self.progress = 0.0
                self.progressPercentage = 0
                self.transcribeSegments(
                    wavPaths: wavPaths,
                    nextIndex: nextIndex + 1,
                    srtFiles: nextSRTFiles,
                    modelPath: modelPath,
                    settings: settings,
                    selectedLanguage: selectedLanguage,
                    segmentDurationSeconds: segmentDurationSeconds,
                    fps: fps,
                    projectName: projectName
                )
            }
        }
    }

    private func finishTranscription(
        srtFiles: [String],
        segmentDurationSeconds: TimeInterval,
        fps: Float,
        projectName: String
    ) {
        progress = 1.0
        progressPercentage = 100
        remainingTime = "00:00"

        if hasCancellationRequest {
            finishCancelledTranscription()
            return
        }

        guard !srtFiles.isEmpty else {
            failTranscription("Error: No subtitles generated")
            return
        }

        // Use SRTService for merging
        let outputSRTFilePath = SRTService.shared.mergeSRT(
            srtFiles: srtFiles,
            segmentDurationSeconds: segmentDurationSeconds
        )

        guard SRTService.shared.isValidSRTFile(outputSRTFilePath) else {
            failTranscription("Error: Merged SRT is invalid")
            return
        }

        let outputFCPXMLFilePath = FCPXMLService.srtToFCPXML(
            srtPath: outputSRTFilePath,
            fps: fps,
            projectName: projectName
        )
        guard FCPXMLService.isValidFCPXMLFile(outputFCPXMLFilePath) else {
            failTranscription("Error: Failed to generate FCPXML")
            return
        }

        status = "Done"
        self.outputSRTFilePath = outputSRTFilePath
        self.outputFCPXMLFilePath = outputFCPXMLFilePath
        processingState = .succeeded
    }

    private func failTranscription(_ message: String) {
        setActiveWhisperProcess(nil)
        status = message
        processingState = .failed(message)
    }

    // MARK: - Whisper CLI Execution
    private func transcribeSegment(
        wavPath: String,
        modelPath: String,
        settings: WhisperSettings,
        selectedLanguage: String,
        completion: @escaping (String) -> Void
    ) {
        WhisperService.shared.transcribe(
            settings: settings,
            modelPath: modelPath,
            selectedLanguage: selectedLanguage,
            outputWavFilePath: wavPath,
            processStarted: { [weak self] process in
                self?.setActiveWhisperProcess(process)
            },
            progressCallback: { [weak self] percentage, progress, remainingTime in
                self?.progressPercentage = percentage
                self?.progress = progress
                self?.remainingTime = remainingTime
            },
            outputCallback: { [weak self] captions in
                self?.outputCaptions += captions
            },
            completion: { [weak self] srtFilePath in
                self?.setActiveWhisperProcess(nil)
                completion(srtFilePath)
            }
        )
    }

    // MARK: - Reset
    func reset() {
        outputCaptions = ""
        progress = 0.0
        progressPercentage = 0
        remainingTime = "00:00"
        startCreatingAutoCaptions = false
        processingState = .idle
        outputSRTFilePath = ""
        outputFCPXMLFilePath = ""
        totalBatch = 100000
        currentBatch = -100000
        status = "Splitting audio file..."
    }
    
    // MARK: - Model Validation
    func validateAndStartTranscription() {
        guard canStartTranscription else {
            if let reason = transcriptionBlockReason {
                status = "Error: \(reason)"
                processingState = .failed(status)
            }
            return
        }

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

        startOrDownloadModel(at: modelPath) { [weak self] in
            self?.downloadModel(model: modelFileName) { [weak self] success in
                if success { self?.startTranscription() }
            }
        }
    }

    /// Validate and start transcription for a custom model
    private func validateAndStartCustomModel(_ model: CustomModel) {
        guard let modelPath = try? customModelManager.getCustomModelPath(for: model) else {
            return
        }

        startOrDownloadModel(at: modelPath) { [weak self] in
            self?.downloadCustomModel(model)
        }
    }

    private func startOrDownloadModel(at modelPath: URL, download: @escaping () -> Void) {
        if isValidModelFile(at: modelPath) {
            startTranscription()
            return
        }

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try? FileManager.default.removeItem(at: modelPath)
        }

        download()
    }

    private func isValidModelFile(at modelPath: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: modelPath.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
              let size = attributes[.size] as? Int64 else {
            return false
        }
        return size >= minimumValidModelSize
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
