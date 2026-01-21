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

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Header
                HStack {
                    Text("Project: \(viewModel.projectName)").font(.title2)
                    Spacer()
                    Button(action: {
                        viewModel.reset()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .disabled(!isProcessingComplete)
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
                    Text("Download files: ").font(.title2)
                    
                    Button(action: {
                        FileUtility.saveFileWithDialog(filePath: viewModel.outputSRTFilePath)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download .srt file")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                    .disabled(!isProcessingComplete)

                    Button(action: {
                        FileUtility.saveFileWithDialog(filePath: viewModel.outputFCPXMLFilePath)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download .fcpxml file")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                    .disabled(!isProcessingComplete)

                    Button(action: {
                        FileUtility.saveFileWithDialog(filePath: viewModel.outputSRTFilePath)
                        FileUtility.saveFileWithDialog(filePath: viewModel.outputFCPXMLFilePath)
                    }) {
                        Image(systemName: "folder.badge.plus")
                        Text("Download All")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.green)
                    .disabled(!isProcessingComplete || viewModel.currentBatch == viewModel.totalBatch - 1)
                }
                .padding()
                .padding(.bottom, -20)
                .frame(width: geometry.size.width, alignment: .leading)
                
                // Open in Final Cut Pro
                HStack {
                    Text("Open in Final Cut Pro: ")
                        .font(.title2)
                    OpenInFinalCutProButton(
                        fcpxmlPath: viewModel.outputFCPXMLFilePath,
                        label: "Click here to check auto captions in Final Cut Pro X"
                    )
                    .disabled(!isProcessingComplete)
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
        #if DEBUG
        .enableInjection()
        #endif
    }
    
    // MARK: - Computed Properties
    private var isProcessingComplete: Bool {
        viewModel.currentBatch == viewModel.totalBatch && viewModel.progressPercentage >= 100
    }
    
    private var batchDisplayText: String {
        let current = viewModel.currentBatch == -100000 ? "···" : String(viewModel.currentBatch)
        let total = viewModel.totalBatch == 100000 ? "···" : String(viewModel.totalBatch)
        return "\(current) / \(total)"
    }
}
