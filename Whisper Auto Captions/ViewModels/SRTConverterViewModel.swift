import Foundation
import SwiftUI

// MARK: - SRT Converter ViewModel
class SRTConverterViewModel: ObservableObject {
    // MARK: - Dependencies
    private let settingsManager = SettingsManager.shared
    private let defaults = UserDefaults.standard
    private var isInitializing = true

    private enum ConverterStorageKeys {
        static let selectedResolution = "srtConverterSelectedResolution"
        static let customWidth = "srtConverterCustomWidth"
        static let customHeight = "srtConverterCustomHeight"
        static let selectedFrameRate = "srtConverterSelectedFrameRate"
        static let customFps = "srtConverterCustomFps"
    }

    // MARK: - Published Properties
    @Published var srtFileURL: URL?
    @Published var fileName: String = ""
    @Published var projectName: String = ""
    @Published var outputFCPXMLFilePath = ""
    @Published var conversionComplete = false
    @Published var showConversionError = false
    @Published var conversionErrorMessage = ""

    // Resolution settings
    @Published var selectedResolution: VideoResolution = .fullHD1080p {
        didSet {
            updatePositionForResolution()
            saveConverterSettings()
        }
    }
    @Published var customWidth: String = "1920" {
        didSet {
            updatePositionForResolution()
            saveConverterSettings()
        }
    }
    @Published var customHeight: String = "1080" {
        didSet {
            updatePositionForResolution()
            saveConverterSettings()
        }
    }

    // Frame rate settings
    @Published var selectedFrameRate: FrameRate = .fps30 {
        didSet {
            saveConverterSettings()
        }
    }
    @Published var customFps: String = "30" {
        didSet {
            saveConverterSettings()
        }
    }

    // Title style settings (synced with SettingsManager)
    @Published var titleStyle: TitleStyleSettings = .default

    @Published var showTitleStyleSettings: Bool = false {
        didSet {
            // Save when dialog closes (outside of view update cycle)
            if !showTitleStyleSettings && oldValue {
                settingsManager.titleStyleSettings = titleStyle
            }
        }
    }

    // Cached font list (loaded asynchronously to avoid UI blocking)
    @Published private(set) var availableFonts: [String] = []

    // MARK: - Initialization
    init() {
        loadConverterSettings()

        // Load saved title style settings
        titleStyle = settingsManager.titleStyleSettings
        isInitializing = false
        updatePositionForResolution()

        // Load font list in background to avoid blocking UI
        loadFontsAsync()
    }

    private func loadConverterSettings() {
        if let resolutionRaw = defaults.string(forKey: ConverterStorageKeys.selectedResolution),
           let resolution = VideoResolution(rawValue: resolutionRaw) {
            selectedResolution = resolution
        }

        customWidth = defaults.string(forKey: ConverterStorageKeys.customWidth) ?? customWidth
        customHeight = defaults.string(forKey: ConverterStorageKeys.customHeight) ?? customHeight

        if let frameRateRaw = defaults.string(forKey: ConverterStorageKeys.selectedFrameRate),
           let frameRate = FrameRate(rawValue: frameRateRaw) {
            selectedFrameRate = frameRate
        } else if let savedFrameRate = FrameRate(rawValue: settingsManager.settings.selectedFrameRate) {
            selectedFrameRate = savedFrameRate
        }

        customFps = defaults.string(forKey: ConverterStorageKeys.customFps) ?? settingsManager.settings.customFps
    }

    private func saveConverterSettings() {
        guard !isInitializing else { return }

        defaults.set(selectedResolution.rawValue, forKey: ConverterStorageKeys.selectedResolution)
        defaults.set(customWidth, forKey: ConverterStorageKeys.customWidth)
        defaults.set(customHeight, forKey: ConverterStorageKeys.customHeight)
        defaults.set(selectedFrameRate.rawValue, forKey: ConverterStorageKeys.selectedFrameRate)
        defaults.set(customFps, forKey: ConverterStorageKeys.customFps)
    }

    /// Load system fonts asynchronously
    private func loadFontsAsync() {
        Task {
            let fonts = await Task.detached(priority: .userInitiated) {
                NSFontManager.shared.availableFontFamilies.sorted()
            }.value

            await MainActor.run { [weak self] in
                self?.availableFonts = fonts
            }
        }
    }
    
    // MARK: - Computed Properties
    var currentWidth: Int {
        if selectedResolution == .custom {
            return Int(customWidth) ?? 1920
        }
        return selectedResolution.width
    }
    
    var currentHeight: Int {
        if selectedResolution == .custom {
            return Int(customHeight) ?? 1080
        }
        return selectedResolution.height
    }
    
    var currentFps: Float {
        if selectedFrameRate == .custom {
            return Float(customFps) ?? 30.0
        }
        return selectedFrameRate.value
    }
    
    var isResolutionValid: Bool {
        let validation = VideoResolution.isValidResolution(width: currentWidth, height: currentHeight)
        return validation.valid
    }
    
    var resolutionWarning: String? {
        let validation = VideoResolution.isValidResolution(width: currentWidth, height: currentHeight)
        return validation.message
    }
    
    var isFpsValid: Bool {
        return FrameRate.isValidFrameRate(currentFps)
    }
    
    var canConvert: Bool {
        return srtFileURL != nil && !projectName.isEmpty && isResolutionValid && isFpsValid
    }

    // MARK: - Title Style Summary (for display in main view)

    /// Summary text for title style (e.g., "Helvetica, 45pt")
    var titleStyleSummary: String {
        return "\(titleStyle.fontName), \(Int(titleStyle.fontSize))pt"
    }

    /// Detail text for title style (e.g., "Bottom Center | Center | Regular")
    var titleStyleDetails: String {
        let position = titleStyle.positionPreset.displayName
        let alignment = titleStyle.alignment.displayName
        let weight = titleStyle.fontWeight.displayName
        return "\(position) | \(alignment) | \(weight)"
    }
    
    // MARK: - File Selection
    func selectFile(url: URL) {
        self.srtFileURL = url
        self.fileName = url.lastPathComponent
        self.projectName = url.deletingPathExtension().lastPathComponent
    }
    
    // MARK: - Conversion
    func convertSRTtoFCPXML() {
        guard let srtURL = srtFileURL else { return }

        let srtPath = srtURL.path
        guard SRTService.shared.isValidSRTFile(srtPath) else {
            conversionErrorMessage = String(localized: "The selected SRT file is empty or does not contain valid subtitle timestamps.", comment: "Invalid SRT conversion error")
            showConversionError = true
            return
        }

        outputFCPXMLFilePath = FCPXMLService.srtToFCPXML(
            srtPath: srtPath,
            fps: currentFps,
            projectName: projectName,
            width: currentWidth,
            height: currentHeight,
            titleStyle: titleStyle
        )

        if FCPXMLService.isValidFCPXMLFile(outputFCPXMLFilePath) {
            conversionComplete = true
        } else {
            conversionErrorMessage = String(localized: "Failed to create a valid FCPXML file. Please check the SRT content and try again.", comment: "FCPXML conversion failed error")
            showConversionError = true
        }
    }

    // MARK: - Reset
    func reset() {
        conversionComplete = false
        showConversionError = false
        conversionErrorMessage = ""
        outputFCPXMLFilePath = ""
        srtFileURL = nil
        fileName = ""
        projectName = ""
        // Don't reset titleStyle - keep user's preferred style settings
        showTitleStyleSettings = false
    }

    // MARK: - Title Style Helpers

    /// Update position based on current resolution when preset changes
    private func updatePositionForResolution() {
        guard titleStyle.positionPreset != .custom else { return }
        titleStyle.updatePositionFromPreset(height: currentHeight)
    }

    /// Calculate position values for a preset (for local state in View)
    func calculatePositionForPreset(_ preset: PositionPreset) -> (x: CGFloat, y: CGFloat) {
        return preset.position(for: currentHeight)
    }

}
