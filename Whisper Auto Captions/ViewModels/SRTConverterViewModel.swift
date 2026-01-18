import Foundation

// MARK: - SRT Converter ViewModel
class SRTConverterViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var srtFileURL: URL?
    @Published var fileName: String = ""
    @Published var projectName: String = ""
    @Published var selectedLanguage = "English"
    @Published var outputFCPXMLFilePath = ""
    @Published var conversionComplete = false
    
    // Resolution settings
    @Published var selectedResolution: VideoResolution = .fullHD1080p
    @Published var customWidth: String = "1920"
    @Published var customHeight: String = "1080"
    
    // Frame rate settings
    @Published var selectedFrameRate: FrameRate = .fps30
    @Published var customFps: String = "30"
    
    // MARK: - Languages
    let languages = ["Arabic", "Azerbaijani", "Armenian", "Albanian", "Afrikaans", "Amharic", "Assamese", "Bulgarian", "Bengali", "Breton", "Basque", "Bosnian", "Belarusian", "Bashkir", "Chinese Simplified", "Chinese Traditional", "Catalan", "Czech", "Croatian", "Dutch", "Danish", "English", "Estonian", "French", "Finnish", "Faroese", "German", "Greek", "Galician", "Georgian", "Gujarati", "Hindi", "Hebrew", "Hungarian", "Haitian creole", "Hawaiian", "Hausa", "Italian", "Indonesian", "Icelandic", "Japanese", "Javanese", "Korean", "Kannada", "Kazakh", "Khmer", "Lithuanian", "Latin", "Latvian", "Lao", "Luxembourgish", "Lingala", "Malay", "Maori", "Malayalam", "Macedonian", "Mongolian", "Marathi", "Maltese", "Myanmar", "Malagasy", "Norwegian", "Nepali", "Nynorsk", "Occitan", "Portuguese", "Polish", "Persian", "Punjabi", "Pashto", "Russian", "Romanian", "Spanish", "Swedish", "Slovak", "Serbian", "Slovenian", "Swahili", "Sinhala", "Shona", "Somali", "Sindhi", "Sanskrit", "Sundanese", "Turkish", "Tamil", "Thai", "Telugu", "Tajik", "Turkmen", "Tibetan", "Tagalog", "Tatar", "Ukrainian", "Urdu", "Uzbek", "Vietnamese", "Welsh", "Yoruba", "Yiddish"]
    
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
            height: currentHeight
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
    }
}
