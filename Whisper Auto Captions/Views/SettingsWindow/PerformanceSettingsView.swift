//
//  PerformanceSettingsView.swift
//  Whisper Auto Captions
//
//  Performance-related settings (speed parameters)
//

import SwiftUI
#if DEBUG
import Inject
#endif

struct PerformanceSettingsView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    @Binding var settings: WhisperSettings

    private var maxThreads: Int {
        ProcessInfo.processInfo.processorCount
    }

    var body: some View {
        Form {
            Section {
                // Threads
                HStack {
                    Text(String(localized: "Threads:", comment: "Threads setting label"))
                        .frame(width: 150, alignment: .trailing)
                    Stepper(value: $settings.threads, in: 1...maxThreads) {
                        Text("\(settings.threads)")
                            .frame(width: 40)
                    }
                    Text(String(localized: "Max: \(maxThreads)", comment: "Max threads description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                // Processors
                HStack {
                    Text(String(localized: "Processors:", comment: "Processors setting label"))
                        .frame(width: 150, alignment: .trailing)
                    Stepper(value: $settings.processors, in: 1...maxThreads) {
                        Text("\(settings.processors)")
                            .frame(width: 40)
                    }
                    Text(String(localized: "Parallel processing units", comment: "Processors description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } header: {
                Text(String(localized: "Threading", comment: "Threading section header"))
            }

            Section {
                // No GPU
                Toggle(isOn: $settings.noGPU) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Disable GPU Acceleration", comment: "No GPU toggle label"))
                        Text(String(localized: "Force CPU-only processing", comment: "No GPU description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Flash Attention
                Toggle(isOn: $settings.flashAttention) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Flash Attention", comment: "Flash attention toggle label"))
                        Text(String(localized: "Faster inference (may reduce accuracy)", comment: "Flash attention description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "GPU Settings", comment: "GPU section header"))
            }

            Section {
                Text(String(localized: "More threads generally improve speed, but using too many can cause diminishing returns. Flash Attention can significantly speed up processing on supported hardware.", comment: "Performance tips"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(String(localized: "Tips", comment: "Tips section header"))
            }
        }
        .formStyle(.grouped)

    }
}
