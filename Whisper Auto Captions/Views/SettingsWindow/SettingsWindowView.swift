//
//  SettingsWindowView.swift
//  Whisper Auto Captions
//
//  Main settings window with sidebar navigation
//

import SwiftUI
#if DEBUG
import Inject
#endif

enum SettingsSection: String, CaseIterable, Identifiable {
    case quality = "Quality"
    case performance = "Performance"
    case output = "Output"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .quality: return "star.fill"
        case .performance: return "bolt.fill"
        case .output: return "doc.text.fill"
        case .advanced: return "gearshape.2.fill"
        }
    }

    var localizedName: String {
        switch self {
        case .quality:
            return String(localized: "Quality", comment: "Quality settings section")
        case .performance:
            return String(localized: "Performance", comment: "Performance settings section")
        case .output:
            return String(localized: "Output", comment: "Output settings section")
        case .advanced:
            return String(localized: "Advanced", comment: "Advanced settings section")
        }
    }
}

struct SettingsWindowView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var selectedSection: SettingsSection = .quality

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.localizedName, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150)
        } detail: {
            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(selectedSection.localizedName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()

                Divider()

                // Settings Content
                ScrollView {
                    settingsContent
                        .padding()
                }

                Divider()

                // Footer
                footerButtons
            }
            .frame(minWidth: 400, minHeight: 400)
        }
        .frame(minWidth: 600, minHeight: 500)

    }

    // MARK: - Settings Content
    @ViewBuilder
    private var settingsContent: some View {
        switch selectedSection {
        case .quality:
            QualitySettingsView(settings: $settingsManager.settings)
        case .performance:
            PerformanceSettingsView(settings: $settingsManager.settings)
        case .output:
            OutputSettingsView(settings: $settingsManager.settings)
        case .advanced:
            AdvancedSettingsView(settings: $settingsManager.settings)
        }
    }

    // MARK: - Footer Buttons
    private var footerButtons: some View {
        HStack {
            Button(String(localized: "Reset to Defaults", comment: "Reset button")) {
                settingsManager.resetToDefaults()
            }

            Spacer()

            Button(String(localized: "Done", comment: "Done button")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Preview
struct SettingsWindowView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWindowView()
    }
}

// MARK: - InfoButton Component
/// A small info button that shows a tooltip on hover
struct InfoButton: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let recommendation: LocalizedStringKey?

    @State private var isHovering = false
    @State private var showPopover = false

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        recommendation: LocalizedStringKey? = nil
    ) {
        self.title = title
        self.description = description
        self.recommendation = recommendation
    }

    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    // Delay before showing popover
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if isHovering {
                            showPopover = true
                        }
                    }
                } else {
                    showPopover = false
                }
            }
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                InfoTooltipContent(
                    title: title,
                    description: description,
                    recommendation: recommendation
                )
            }
            .accessibilityLabel(title)
            .accessibilityHint(description)
    }
}

/// Content view for the info tooltip popover
private struct InfoTooltipContent: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let recommendation: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recommendation = recommendation {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(recommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
    }
}
