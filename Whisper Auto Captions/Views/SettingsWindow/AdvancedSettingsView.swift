//
//  AdvancedSettingsView.swift
//  Whisper Auto Captions
//
//  Advanced settings for specialized features
//

import SwiftUI
#if DEBUG
import Inject
#endif

struct AdvancedSettingsView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    @Binding var settings: WhisperSettings

    var body: some View {
        Form {
            Section {
                // Prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Initial Prompt:", comment: "Prompt label"))
                    TextEditor(text: $settings.prompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Text(String(localized: "Guide transcription with context or vocabulary hints", comment: "Prompt description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(String(localized: "Prompt", comment: "Prompt section header"))
            }

            Section {
                // No Speech Threshold
                HStack {
                    Text(String(localized: "No Speech Threshold:", comment: "No speech threshold label"))
                        .frame(width: 150, alignment: .trailing)
                    TextField("", value: $settings.noSpeechThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(String(localized: "Default: 0.6", comment: "No speech default"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                // Word Threshold
                HStack {
                    Text(String(localized: "Word Threshold:", comment: "Word threshold label"))
                        .frame(width: 150, alignment: .trailing)
                    TextField("", value: $settings.wordThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(String(localized: "Default: 0.01", comment: "Word threshold default"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } header: {
                Text(String(localized: "Detection Thresholds", comment: "Detection section header"))
            }

            Section {
                // Diarize
                Toggle(isOn: $settings.diarize) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Speaker Diarization", comment: "Diarize toggle label"))
                        Text(String(localized: "Identify and label different speakers", comment: "Diarize description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Tiny Diarize
                Toggle(isOn: $settings.tinyDiarize) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Tiny Diarization (Experimental)", comment: "Tiny diarize toggle label"))
                        Text(String(localized: "Lightweight speaker diarization for smaller models", comment: "Tiny diarize description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!settings.diarize)
            } header: {
                Text(String(localized: "Speaker Diarization", comment: "Diarization section header"))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Use the prompt to provide context about the audio content or include specific vocabulary that should be recognized.", comment: "Prompt tip"))

                    Text(String(localized: "Speaker diarization helps distinguish between multiple speakers but may increase processing time.", comment: "Diarization tip"))
                }
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
