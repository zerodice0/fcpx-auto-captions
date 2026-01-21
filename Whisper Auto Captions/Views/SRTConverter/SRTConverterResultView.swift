import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - SRT Converter Result View
struct SRTConverterResultView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    
    @ObservedObject var viewModel: SRTConverterViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.green)

            Text("Conversion Complete!")
                .font(.title)

            Text("Project: \(viewModel.projectName)")
                .font(.title2)

            // Action Buttons
            HStack(spacing: 16) {
                Button(action: {
                    FileUtility.saveFileWithDialog(filePath: viewModel.outputFCPXMLFilePath)
                }) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Download .fcpxml")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)

                OpenInFinalCutProButton(fcpxmlPath: viewModel.outputFCPXMLFilePath)
            }

            // Reset Button
            Button(action: {
                viewModel.reset()
            }) {
                Image(systemName: "arrow.counterclockwise")
                Text("Convert Another File")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        #if DEBUG
        .enableInjection()
        #endif
    }
}
