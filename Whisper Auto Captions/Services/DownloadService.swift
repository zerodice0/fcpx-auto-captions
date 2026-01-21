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
        do {
            try AppDirectoryUtility.ensureDirectoryExists()
        } catch {
            completion(false)
            return
        }

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
        return AppDirectoryUtility.isModelDownloaded(model)
    }

    // MARK: - Get Model Path
    func getModelPath(for model: String) -> URL? {
        return try? AppDirectoryUtility.getModelPath(for: model)
    }

}
