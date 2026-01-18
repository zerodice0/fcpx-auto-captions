import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - Main Content View with Tabs
struct ContentView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TranscriptionTab()
                .tabItem {
                    Label("Transcription", systemImage: "waveform")
                }
                .tag(0)

            SRTConverterView()
                .tabItem {
                    Label("SRT Converter", systemImage: "doc.text")
                }
                .tag(1)
        }
        .frame(minWidth: 600, minHeight: 600)
        #if DEBUG
        .enableInjection()
        #endif
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
