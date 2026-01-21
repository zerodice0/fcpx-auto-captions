import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - Title Style Settings View
struct TitleStyleSettingsView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif

    @Binding var titleStyle: TitleStyleSettings
    @Binding var isExpanded: Bool
    let availableFonts: [String]
    let currentHeight: Int

    private let labelWidth: CGFloat = 60

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    positionSection
                    Divider()
                    fontSection
                    Divider()
                    colorSection
                    Divider()
                    alignmentSection
                }
                .padding(.top, 8)
            },
            label: {
                Text(String(localized: "Title Style", comment: "Title style section header"))
                    .font(.headline)
            }
        )
        #if DEBUG
        .enableInjection()
        #endif
    }

    // MARK: - Position Section
    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Position", comment: "Position label"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text(String(localized: "Preset:", comment: "Position preset label"))
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker(selection: $titleStyle.positionPreset, label: EmptyView()) {
                        ForEach(PositionPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 200)
                    .onChange(of: titleStyle.positionPreset) { newPreset in
                        if newPreset != .custom {
                            titleStyle.updatePositionFromPreset(height: currentHeight)
                        }
                    }
                }

                if titleStyle.positionPreset == .custom {
                    GridRow {
                        Text(String(localized: "Offset:", comment: "Position offset label"))
                            .frame(width: labelWidth, alignment: .trailing)
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("X:")
                                TextField("0", value: $titleStyle.positionX, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                            }
                            HStack(spacing: 4) {
                                Text("Y:")
                                TextField("0", value: $titleStyle.positionY, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Font Section
    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Font", comment: "Font label"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                // Font Family and Size
                GridRow {
                    Text(String(localized: "Family:", comment: "Font family label"))
                        .frame(width: labelWidth, alignment: .trailing)
                    HStack(spacing: 16) {
                        Picker(selection: $titleStyle.fontName, label: EmptyView()) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 180)

                        HStack(spacing: 4) {
                            Text(String(localized: "Size:", comment: "Font size label"))
                            TextField("45", value: $titleStyle.fontSize, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 50)
                            Text("pt")
                        }
                    }
                }

                // Font Weight
                GridRow {
                    Text(String(localized: "Weight:", comment: "Font weight label"))
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker(selection: $titleStyle.fontWeight, label: EmptyView()) {
                        ForEach(TitleFontWeight.allCases) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 120)
                }
            }
        }
    }

    // MARK: - Color Section
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Colors", comment: "Colors label"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                // Text Color
                GridRow {
                    Text(String(localized: "Text:", comment: "Text color label"))
                        .frame(width: labelWidth, alignment: .trailing)
                    ColorPicker("", selection: textColorBinding)
                        .labelsHidden()
                }

                // Stroke
                GridRow {
                    Text(String(localized: "Stroke:", comment: "Stroke label"))
                        .frame(width: labelWidth, alignment: .trailing)
                    HStack(spacing: 8) {
                        Toggle("", isOn: $titleStyle.strokeEnabled)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        if titleStyle.strokeEnabled {
                            ColorPicker("", selection: strokeColorBinding)
                                .labelsHidden()
                            HStack(spacing: 4) {
                                TextField("2", value: $titleStyle.strokeWidth, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                Text("pt")
                            }
                        }
                    }
                }

                // Shadow
                GridRow {
                    Text(String(localized: "Shadow:", comment: "Shadow label"))
                        .frame(width: labelWidth, alignment: .trailing)
                    HStack(spacing: 8) {
                        ColorPicker("", selection: shadowColorBinding)
                            .labelsHidden()
                        HStack(spacing: 4) {
                            Text("X:")
                            TextField("4", value: $titleStyle.shadowOffsetX, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 40)
                        }
                        HStack(spacing: 4) {
                            Text("Y:")
                            TextField("315", value: $titleStyle.shadowOffsetY, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 40)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Alignment Section
    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Alignment", comment: "Alignment label"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker(selection: $titleStyle.alignment, label: EmptyView()) {
                ForEach(TitleTextAlignment.allCases) { alignment in
                    Text(alignment.displayName).tag(alignment)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 200)
        }
    }

    // MARK: - Color Bindings

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { titleStyle.textColor.color },
            set: { titleStyle.textColor = CodableColor(color: NSColor($0)) }
        )
    }

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { titleStyle.strokeColor.color },
            set: { titleStyle.strokeColor = CodableColor(color: NSColor($0)) }
        )
    }

    private var shadowColorBinding: Binding<Color> {
        Binding(
            get: { titleStyle.shadowColor.color },
            set: { titleStyle.shadowColor = CodableColor(color: NSColor($0)) }
        )
    }
}
