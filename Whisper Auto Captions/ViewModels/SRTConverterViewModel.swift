import Foundation
import SwiftUI
import Combine

// MARK: - SRT Converter ViewModel
class SRTConverterViewModel: ObservableObject {
    // MARK: - Dependencies
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties
    @Published var srtFileURL: URL?
    @Published var fileName: String = ""
    @Published var projectName: String = ""
    @Published var selectedLanguage = "English" {
        didSet {
            updateFontForLanguage()
        }
    }
    @Published var outputFCPXMLFilePath = ""
    @Published var conversionComplete = false

    // Resolution settings
    @Published var selectedResolution: VideoResolution = .fullHD1080p {
        didSet {
            updatePositionForResolution()
        }
    }
    @Published var customWidth: String = "1920" {
        didSet {
            updatePositionForResolution()
        }
    }
    @Published var customHeight: String = "1080" {
        didSet {
            updatePositionForResolution()
        }
    }

    // Frame rate settings
    @Published var selectedFrameRate: FrameRate = .fps30
    @Published var customFps: String = "30"

    // Title style settings (synced with SettingsManager)
    @Published var titleStyle: TitleStyleSettings = .default {
        didSet {
            // When preset changes, update position based on resolution
            if oldValue.positionPreset != titleStyle.positionPreset {
                titleStyle.updatePositionFromPreset(height: currentHeight)
            }
            // Persist to SettingsManager
            settingsManager.titleStyleSettings = titleStyle
        }
    }
    @Published var showTitleStyleSettings: Bool = false

    // MARK: - Initialization
    init() {
        // Load saved title style settings
        titleStyle = settingsManager.titleStyleSettings
    }
    
    // MARK: - Languages
    // Use centralized language data (excludes "Auto" for SRT converter)
    let languages = LanguageData.languages.filter { $0 != "Auto" }
    
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
        outputFCPXMLFilePath = FCPXMLService.srtToFCPXML(
            srtPath: srtPath,
            fps: currentFps,
            projectName: projectName,
            language: selectedLanguage,
            width: currentWidth,
            height: currentHeight,
            titleStyle: titleStyle
        )

        if outputFCPXMLFilePath != "Error" {
            conversionComplete = true
        }
    }

    // MARK: - Reset
    func reset() {
        conversionComplete = false
        outputFCPXMLFilePath = ""
        srtFileURL = nil
        fileName = ""
        projectName = ""
        selectedLanguage = "English"
        // Don't reset titleStyle - keep user's preferred style settings
        showTitleStyleSettings = false
    }

    // MARK: - Title Style Helpers

    /// Update position based on current resolution when preset changes
    private func updatePositionForResolution() {
        guard titleStyle.positionPreset != .custom else { return }
        titleStyle.updatePositionFromPreset(height: currentHeight)
    }

    /// Update font settings based on selected language
    private func updateFontForLanguage() {
        if selectedLanguage == "Chinese" {
            titleStyle.fontName = "PingFang SC"
            titleStyle.fontSize = 50
            titleStyle.fontWeight = .semibold
        }
    }

    /// Get available system fonts
    var availableFonts: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }
}
