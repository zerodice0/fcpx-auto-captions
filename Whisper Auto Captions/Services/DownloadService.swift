//
//  DownloadService.swift
//  Whisper Auto Captions
//
//  Handles Whisper model downloads from HuggingFace
//

import Foundation

/// Service for downloading Whisper models
class DownloadService: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = DownloadService()

    // MARK: - Published Properties
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var currentModel: String = ""

    // MARK: - Private Properties
    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: DownloadDelegate?
    private var completionHandler: ((Bool) -> Void)?

    // MARK: - Constants
    private let huggingFaceBaseURL = "https://huggingface.co/datasets/ggerganov/whisper.cpp/resolve/main"

    // MARK: - Initialization
    override private init() {
        super.init()
    }

    // MARK: - Download Model
    /// Download a Whisper model from HuggingFace
    func downloadModel(model: String, completion: @escaping (Bool) -> Void) {
        let modelLower = model.lowercased()
        guard let url = URL(string: "\(huggingFaceBaseURL)/ggml-\(modelLower).bin") else {
            completion(false)
            return
        }

        // Setup download directory
        let fileManager = FileManager.default
        let applicationSupportDirectory = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let whisperAutoCaptionsURL = applicationSupportDirectory.appendingPathComponent("Whisper Auto Captions")
        try? fileManager.createDirectory(at: whisperAutoCaptionsURL, withIntermediateDirectories: true, attributes: nil)

        self.currentModel = model
        self.completionHandler = completion

        // Create download delegate
        self.downloadDelegate = DownloadDelegate(
            model: model,
            progressHandler: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.downloadProgress = progress
                }
            },
            completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.isDownloading = false
                    self?.completionHandler?(true)
                }
            }
        )

        // Setup cancel action
        self.downloadDelegate?.cancelAction = { [weak self] in
            self?.downloadProgress = 0.0
            self?.downloadTask?.cancel()
        }

        // Create session and start download
        let session = URLSession(
            configuration: .default,
            delegate: self.downloadDelegate,
            delegateQueue: nil
        )
        let task = session.downloadTask(with: url)
        self.downloadTask = task

        DispatchQueue.main.async {
            self.isDownloading = true
        }

        task.resume()
    }

    // MARK: - Cancel Download
    func cancelDownload() {
        downloadDelegate?.cancelAction?()
        DispatchQueue.main.async {
            self.isDownloading = false
            self.downloadProgress = 0.0
        }
        completionHandler?(false)
    }

    // MARK: - Check Model Exists
    func isModelDownloaded(_ model: String) -> Bool {
        let fileManager = FileManager.default
        let applicationSupportDirectory = try! fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let whisperAutoCaptionsURL = applicationSupportDirectory.appendingPathComponent("Whisper Auto Captions")
        let destinationURL = whisperAutoCaptionsURL.appendingPathComponent("ggml-\(model.lowercased()).bin")

        return fileManager.fileExists(atPath: destinationURL.path)
    }

    // MARK: - Get Model Path
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

    // MARK: - Delete Model
    func deleteModel(_ model: String) -> Bool {
        let modelPath = getModelPath(for: model)
        do {
            try FileManager.default.removeItem(at: modelPath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Get Downloaded Models
    func getDownloadedModels() -> [String] {
        return ModelData.models.filter { isModelDownloaded($0) }
    }
}
