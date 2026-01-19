import SwiftUI
import UniformTypeIdentifiers
#if DEBUG
import Inject
#endif

// MARK: - SRT Converter Input View
struct SRTConverterInputView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    
    @ObservedObject var viewModel: SRTConverterViewModel

    var body: some View {
        VStack {
            Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 20) {
                // SRT File Selection
                GridRow {
                    Text(String(localized: "SRT File:", comment: "SRT file label"))
                        .gridColumnAlignment(.trailing)
                    HStack {
                        Button(action: selectFile) {
                            Text(String(localized: "Choose File", comment: "Choose file button"))
                        }

                        if viewModel.srtFileURL != nil {
                            Text(viewModel.fileName)
                        }
                    }
                    .gridColumnAlignment(.leading)
                }

                // Project Name
                GridRow {
                    Text(String(localized: "Project Name:", comment: "Project name label"))
                    TextField(String(localized: "Project name for FCPXML", comment: "Project name placeholder"), text: $viewModel.projectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }

                // Frame Rate Selection
                GridRow {
                    Text(String(localized: "Frame Rate:", comment: "Frame rate label"))
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(selection: $viewModel.selectedFrameRate, label: EmptyView()) {
                            ForEach(FrameRate.allCases) { frameRate in
                                Text(frameRate.displayName).tag(frameRate)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(alignment: .leading)

                        if viewModel.selectedFrameRate == .custom {
                            HStack(spacing: 8) {
                                TextField("fps", text: $viewModel.customFps)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                                Text("fps")
                            }

                            if !viewModel.isFpsValid {
                                Text(String(localized: "Frame rate must be between 0 and 120", comment: "Invalid frame rate warning"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                // Resolution Selection
                GridRow {
                    Text(String(localized: "Resolution:", comment: "Resolution label"))
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(selection: $viewModel.selectedResolution, label: EmptyView()) {
                            ForEach(VideoResolution.allCases) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(alignment: .leading)

                        if viewModel.selectedResolution == .custom {
                            HStack(spacing: 8) {
                                TextField(String(localized: "Width", comment: "Width placeholder"), text: $viewModel.customWidth)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                                Text("×")
                                TextField(String(localized: "Height", comment: "Height placeholder"), text: $viewModel.customHeight)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                            }

                            if let warning = viewModel.resolutionWarning {
                                Text(warning)
                                    .font(.caption)
                                    .foregroundColor(viewModel.isResolutionValid ? .orange : .red)
                            }
                        }
                    }
                }

                // Language Selection
                GridRow {
                    Text(String(localized: "Language:", comment: "Language label"))
                    Picker(selection: $viewModel.selectedLanguage, label: EmptyView()) {
                        ForEach(viewModel.languages, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(alignment: .leading)
                }

                // Title Style Settings
                GridRow {
                    TitleStyleSettingsView(
                        titleStyle: $viewModel.titleStyle,
                        isExpanded: $viewModel.showTitleStyleSettings,
                        availableFonts: viewModel.availableFonts,
                        currentHeight: viewModel.currentHeight
                    )
                }
                .gridCellColumns(2)

                // Convert Button
                GridRow {
                    Button(action: {
                        viewModel.convertSRTtoFCPXML()
                    }, label: {
                        Text(String(localized: "Convert to FCPXML", comment: "Convert button label"))
                    })
                    .buttonStyle(BorderedProminentButtonStyle())
                    .gridCellAnchor(.center)
                    .disabled(!viewModel.canConvert)
                }
                .gridCellColumns(2)
            }
            .padding()
        }
        #if DEBUG
        .enableInjection()
        #endif
    }
    
    // MARK: - Actions
    private func selectFile() {
        var allowedTypes: [UTType] = []
        if let srtType = UTType(filenameExtension: "srt") {
            allowedTypes.append(srtType)
        }
        
        FileUtility.selectFile(allowedTypes: allowedTypes, allowDirectories: false) { url in
            if let url = url {
                viewModel.selectFile(url: url)
            }
        }
    }
}
