import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - Process View
struct ProcessView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    
    @ObservedObject var viewModel: HomeViewModel
    @State private var showOperationError = false
    @State private var operationErrorMessage = ""

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Header
                HStack {
                    Text("Project: \(viewModel.projectName)").font(.title2)
                    Spacer()
                    if viewModel.isProcessingRunning {
                        Button(action: {
                            viewModel.cancelTranscription()
                        }) {
                            Image(systemName: "xmark.circle")
                            Text(String(localized: "Cancel", comment: "Cancel transcription button"))
                        }
                    }
                    Button(action: {
                        viewModel.reset()
                    }) {
                        Image(systemName: "checkmark.circle")
                        Text(String(localized: "Back to Home", comment: "Return to home after processing button"))
                    }
                    .disabled(!viewModel.isProcessingFinished)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, -28)
                .padding(.top, -20)
                
                // Status
                Text("Current Status: \(viewModel.status)").font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, -28)
                
                // Output Preview
                ScrollView {
                    Text(viewModel.outputCaptions)
                        .font(.title3)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, -2)
                        .padding(.vertical, -26)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.orange, .red, .pink, .purple, .blue, .cyan, .green, .yellow]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .padding()
                .padding(.bottom, -20)
                .shadow(color: Color.gray.opacity(0.5), radius: 4, x: 0, y: 2)
                
                // Download Buttons
                HStack {
                    Button(action: {
                        saveFile(viewModel.outputSRTFilePath)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                        Text(String(localized: "Save .srt", comment: "Save SRT output button"))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                    .disabled(!viewModel.isProcessingComplete)

                    Button(action: {
                        saveFile(viewModel.outputFCPXMLFilePath)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                        Text(String(localized: "Save .fcpxml", comment: "Save FCPXML output button"))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                    .disabled(!viewModel.isProcessingComplete)
                }
                .padding()
                .padding(.bottom, -20)
                .frame(width: geometry.size.width, alignment: .leading)
                
                // Open in Final Cut Pro
                HStack {
                    OpenInFinalCutProButton(
                        fcpxmlPath: viewModel.outputFCPXMLFilePath,
                        label: String(localized: "Open .fcpxml in Final Cut Pro", comment: "Open FCPXML in Final Cut Pro button"),
                        onFailure: presentOperationError
                    )
                    .disabled(!viewModel.isProcessingComplete)
                }
                .padding()
                .padding(.bottom, -20)
                .frame(width: geometry.size.width, alignment: .leading)
                
                // Progress Bar
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .red, .pink, .purple, .blue, .cyan, .green, .yellow]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 6)
                            .frame(width: geometry.size.width * CGFloat(viewModel.progress), height: geometry.size.height)
                    }
                )
                .frame(height: 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .orange.opacity(0.3), .red.opacity(0.3), .pink.opacity(0.3),
                                    .purple.opacity(0.3), .blue.opacity(0.3), .cyan.opacity(0.3),
                                    .green.opacity(0.3), .yellow.opacity(0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .padding()
                .padding(.bottom, -16)
                
                // Progress Text
                Text("Batch (\(batchDisplayText)): \(viewModel.progressPercentage)% completed - \(viewModel.remainingTime) remaining")
            }
        }
        .padding()
        .alert(String(localized: "Action Failed", comment: "Operation failure alert title"), isPresented: $showOperationError) {
            Button(String(localized: "OK", comment: "OK button")) { }
        } message: {
            Text(operationErrorMessage)
        }
        #if DEBUG
        .enableInjection()
        #endif
    }
    
    // MARK: - Computed Properties
    private var batchDisplayText: String {
        let current = viewModel.currentBatch == -100000 ? "···" : String(viewModel.currentBatch)
        let total = viewModel.totalBatch == 100000 ? "···" : String(viewModel.totalBatch)
        return "\(current) / \(total)"
    }

    private func saveFile(_ path: String) {
        FileUtility.saveFileWithDialog(filePath: path) { result in
            if case .failure(let error) = result {
                presentOperationError(error.localizedDescription)
            }
        }
    }

    private func presentOperationError(_ message: String) {
        operationErrorMessage = message
        showOperationError = true
    }
}
