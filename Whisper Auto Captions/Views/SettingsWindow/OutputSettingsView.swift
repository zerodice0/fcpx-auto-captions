//
//  OutputSettingsView.swift
//  Whisper Auto Captions
//
//  Output format settings
//

import SwiftUI

struct OutputSettingsView: View {
    @Binding var settings: WhisperSettings

    var body: some View {
        Form {
            Section {
                // Max Length
                HStack {
                    Text(String(localized: "Max Segment Length:", comment: "Max length label"))
                        .frame(width: 150, alignment: .trailing)
                    TextField("", value: $settings.maxLen, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(String(localized: "Characters (0 = no limit)", comment: "Max length description"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                // Split on Word
                Toggle(isOn: $settings.splitOnWord) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Split on Word Boundaries", comment: "Split on word toggle label"))
                        Text(String(localized: "Avoid breaking words when splitting segments", comment: "Split on word description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "Segment Length", comment: "Segment length section header"))
            }

            Section {
                // No Timestamps
                Toggle(isOn: $settings.noTimestamps) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Disable Timestamps", comment: "No timestamps toggle label"))
                        Text(String(localized: "Output text only without timing information", comment: "No timestamps description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "Timestamps", comment: "Timestamps section header"))
            }

            Section {
                // Translate
                Toggle(isOn: $settings.translate) {
                    VStack(alignment: .leading) {
                        Text(String(localized: "Translate to English", comment: "Translate toggle label"))
                        Text(String(localized: "Translate non-English audio to English", comment: "Translate description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(String(localized: "Translation", comment: "Translation section header"))
            }

            Section {
                Text(String(localized: "Setting a max segment length helps ensure subtitles fit on screen. Enable 'Split on Word' to prevent awkward mid-word breaks.", comment: "Output tips"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(String(localized: "Tips", comment: "Tips section header"))
            }
        }
        .formStyle(.grouped)
    }
}
