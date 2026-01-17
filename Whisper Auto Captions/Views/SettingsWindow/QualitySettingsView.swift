//
//  QualitySettingsView.swift
//  Whisper Auto Captions
//
//  Quality-related settings (accuracy parameters)
//

import SwiftUI
#if DEBUG
import Inject
#endif

struct QualitySettingsView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    @Binding var settings: WhisperSettings

    var body: some View {
        Form {
            Section {
                // Best-of
                HStack {
                    Text(String(localized: "Best-of:", comment: "Best-of setting label"))
                        .frame(width: 150, alignment: .trailing)
                    Stepper(value: $settings.bestOf, in: 1...10) {
                        Text("\(settings.bestOf)")
                            .frame(width: 40)
                    }
                    Text(String(localized: "Candidates to evaluate", comment: "Best-of description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                // Beam Size
                HStack {
                    Text(String(localized: "Beam Size:", comment: "Beam size setting label"))
                        .frame(width: 150, alignment: .trailing)
                    Stepper(value: $settings.beamSize, in: 1...10) {
                        Text("\(settings.beamSize)")
                            .frame(width: 40)
                    }
                    Text(String(localized: "Beam search width", comment: "Beam size description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                // Temperature
                HStack {
                    Text(String(localized: "Temperature:", comment: "Temperature setting label"))
                        .frame(width: 150, alignment: .trailing)
                    TextField("", value: $settings.temperature, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(String(localized: "0.0 = greedy, higher = random", comment: "Temperature description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } header: {
                Text(String(localized: "Decoding Parameters", comment: "Decoding section header"))
            }

            Section {
                // Entropy Threshold
                HStack {
                    Text(String(localized: "Entropy Threshold:", comment: "Entropy threshold label"))
                        .frame(width: 150, alignment: .trailing)
                    TextField("", value: $settings.entropyThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(String(localized: "Segment validation (default: 2.4)", comment: "Entropy description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                // Log Probability Threshold
                HStack {
                    Text(String(localized: "Log Prob Threshold:", comment: "Log prob threshold label"))
                        .frame(width: 150, alignment: .trailing)
                    TextField("", value: $settings.logProbThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(String(localized: "Segment validation (default: -1.0)", comment: "Log prob description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } header: {
                Text(String(localized: "Validation Thresholds", comment: "Validation section header"))
            }

            Section {
                Text(String(localized: "Higher values for best-of and beam-size improve accuracy but increase processing time.", comment: "Quality tips"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(String(localized: "Tips", comment: "Tips section header"))
            }
        }
        .formStyle(.grouped)
        #if DEBUG
        .enableInjection()
        #endif
    }
}
