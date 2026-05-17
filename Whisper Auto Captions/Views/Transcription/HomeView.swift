import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var customModelManager = CustomModelManager.shared
    @State private var showInvalidFileAlert = false
    @State private var invalidFileErrorMessage = ""

    var body: some View {
        VStack {
            Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 20) {
                // Video/Audio File Selection
                GridRow {
                    Text("Video/Audio File:")
                        .gridColumnAlignment(.trailing)
                    HStack {
                        Button(action: selectFile) {
                            Text("Choose File")
                        }

                        if viewModel.fileURL != nil {
                            Text(viewModel.fileName)
                        }
                    }
                    .gridColumnAlignment(.leading)
                }

                // Frame Rate Selection
                GridRow {
                    Text(String(localized: "Frame Rate:", comment: "Frame rate label"))
                    FrameRatePicker(
                        selectedFrameRate: $viewModel.selectedFrameRate,
                        customFps: $viewModel.customFps,
                        isFpsValid: viewModel.isFpsValid
                    )
                }

                // Model Selection
                GridRow {
                    Text(String(localized: "Model:", comment: "Model label"))
                    Picker(selection: $viewModel.selectedModel, label: EmptyView()) {
                        // Built-in models
                        ForEach(viewModel.models, id: \.self) { model in
                            Text(model).tag(model)
                        }

                        // Custom models (if any)
                        if !customModelManager.customModels.isEmpty {
                            Divider()

                            ForEach(customModelManager.customModels) { customModel in
                                HStack {
                                    Text(customModel.name)
                                    if !customModel.isDownloaded {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.caption)
                                    }
                                }
                                .tag(customModel.name)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 300, alignment: .leading)
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
                    .frame(maxWidth: 300, alignment: .leading)
                }

                // Settings Summary
                GridRow {
                    Text(String(localized: "Settings:", comment: "Settings label"))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(settingsManager.presetDisplayName)
                                .fontWeight(.medium)

                            Button(action: { viewModel.showSettings = true }) {
                                Image(systemName: "gear")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                            .help(String(localized: "Open settings", comment: "Settings button tooltip"))
                        }

                        Text(settingsManager.settingsSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Action Buttons
                GridRow {
                    VStack(spacing: 8) {
                        Button(action: viewModel.validateAndStartTranscription) {
                            Text(String(localized: "Create", comment: "Create button"))
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .disabled(!viewModel.canStartTranscription)

                        if let reason = viewModel.transcriptionBlockReason {
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .gridCellColumns(2)
                .gridCellAnchor(.center)
            }
            .padding()

            if viewModel.isDownloading {
                ProgressView(value: viewModel.downloadProgress)
                    .padding()
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Downloading \(viewModel.selectedModel) Model"),
                message: Text(String(format: "Progress: %.0f%%", viewModel.downloadProgress * 100)),
                primaryButton: .destructive(Text("Cancel"), action: {
                    viewModel.cancelDownload()
                }),
                secondaryButton: .default(Text(""), action: {})
            )
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsWindowView()
        }
        .alert("Invalid File", isPresented: $showInvalidFileAlert) {
            Button("OK", role: .cancel) {
                showInvalidFileAlert = false
            }
        } message: {
            Text(invalidFileErrorMessage)
        }
    }
    
    // MARK: - Actions
    private func selectFile() {
        FileUtility.selectFile(allowedTypes: [.audio, .movie], allowDirectories: false) { url in
            guard let url else { return }

            if FileUtility.isValidMediaFile(url: url, allowedTypes: [.audio, .movie]) {
                viewModel.selectFile(url: url)
            } else {
                invalidFileErrorMessage = FileUtility.mediaFileValidationMessage(
                    for: url,
                    allowedTypes: [.audio, .movie]
                )
                showInvalidFileAlert = true
            }
        }
    }
}
