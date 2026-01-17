//
//  OutputSettingsView.swift
//  Whisper Auto Captions
//
//  Output format settings
//

import SwiftUI
#if DEBUG
import Inject
#endif

struct OutputSettingsView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
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
                    Spacer()
                    InfoButton(
                        title: "info.maxlen.title",
                        description: "info.maxlen.description",
                        recommendation: "info.maxlen.recommendation"
                    )
                }

                // Split on Word
                HStack {
                    Toggle(isOn: $settings.splitOnWord) {
                        Text(String(localized: "Split on Word Boundaries", comment: "Split on word toggle label"))
                    }
                    InfoButton(
                        title: "info.splitonword.title",
                        description: "info.splitonword.description",
                        recommendation: "info.splitonword.recommendation"
                    )
                }
            } header: {
                Text(String(localized: "Segment Length", comment: "Segment length section header"))
            }

            Section {
                // No Timestamps
                HStack {
                    Toggle(isOn: $settings.noTimestamps) {
                        Text(String(localized: "Disable Timestamps", comment: "No timestamps toggle label"))
                    }
                    InfoButton(
                        title: "info.notimestamps.title",
                        description: "info.notimestamps.description",
                        recommendation: "info.notimestamps.recommendation"
                    )
                }
            } header: {
                Text(String(localized: "Timestamps", comment: "Timestamps section header"))
            }

            Section {
                // Translate
                HStack {
                    Toggle(isOn: $settings.translate) {
                        Text(String(localized: "Translate to English", comment: "Translate toggle label"))
                    }
                    InfoButton(
                        title: "info.translate.title",
                        description: "info.translate.description",
                        recommendation: "info.translate.recommendation"
                    )
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
