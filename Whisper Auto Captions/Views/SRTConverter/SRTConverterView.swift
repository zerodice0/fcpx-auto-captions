import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - SRT Converter View
struct SRTConverterView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    
    @StateObject private var viewModel = SRTConverterViewModel()

    var body: some View {
        Group {
            if viewModel.conversionComplete {
                SRTConverterResultView(viewModel: viewModel)
            } else {
                SRTConverterInputView(viewModel: viewModel)
            }
        }
        #if DEBUG
        .enableInjection()
        #endif
    }
}
