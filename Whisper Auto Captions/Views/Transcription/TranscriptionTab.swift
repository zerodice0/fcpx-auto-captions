import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - Transcription Tab
struct TranscriptionTab: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        Group {
            if viewModel.startCreatingAutoCaptions {
                ProcessView(viewModel: viewModel)
            } else {
                HomeView(viewModel: viewModel)
            }
        }
        #if DEBUG
        .enableInjection()
        #endif
    }
}
