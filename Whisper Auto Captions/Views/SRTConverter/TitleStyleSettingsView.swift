import SwiftUI
#if DEBUG
import Inject
#endif

// MARK: - Title Style Settings View (Popup)
struct TitleStyleSettingsView: View {
    #if DEBUG
    @ObserveInjection var inject
    #endif

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SRTConverterViewModel
    let availableFonts: [String]

    // 로컬 편집용 상태 (View 업데이트 중 publishing 방지)
    @State private var localTitleStyle: TitleStyleSettings

    private let labelWidth: CGFloat = 70

    init(viewModel: SRTConverterViewModel, availableFonts: [String]) {
        self.viewModel = viewModel
        self.availableFonts = availableFonts
        // 초기값으로 ViewModel의 현재 값 복사
        _localTitleStyle = State(initialValue: viewModel.titleStyle)
    }

    // MARK: - Position Preset Binding (delegates to ViewModel)
    private var positionPresetBinding: Binding<PositionPreset> {
        Binding(
            get: { localTitleStyle.positionPreset },
            set: { newPreset in
                localTitleStyle.positionPreset = newPreset
                // Position 값 업데이트 (ViewModel의 로직 활용)
                let (x, y) = viewModel.calculatePositionForPreset(newPreset)
                localTitleStyle.positionX = x
                localTitleStyle.positionY = y
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "Title Style", comment: "Title style popup header"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    positionSection
                    Divider()
                    fontSection
                    Divider()
                    colorSection
                    Divider()
                    alignmentSection
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(String(localized: "Done", comment: "Done button")) {
                    saveAndDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 500)
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
                    Picker(selection: positionPresetBinding, label: EmptyView()) {
                        ForEach(PositionPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 200)
                }

                if localTitleStyle.positionPreset == .custom {
                    GridRow {
                        Text(String(localized: "Offset:", comment: "Position offset label"))
                            .frame(width: labelWidth, alignment: .trailing)
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("X:")
                                TextField("0", value: $localTitleStyle.positionX, formatter: NumberFormatter())
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 70)
                            }
                            HStack(spacing: 4) {
                                Text("Y:")
                                TextField("0", value: $localTitleStyle.positionY, formatter: NumberFormatter())
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
                        Picker(selection: $localTitleStyle.fontName, label: EmptyView()) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: 180)

                        HStack(spacing: 4) {
                            Text(String(localized: "Size:", comment: "Font size label"))
                            TextField("45", value: $localTitleStyle.fontSize, formatter: NumberFormatter())
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
                    Picker(selection: $localTitleStyle.fontWeight, label: EmptyView()) {
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
                        Toggle("", isOn: $localTitleStyle.strokeEnabled)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        if localTitleStyle.strokeEnabled {
                            ColorPicker("", selection: strokeColorBinding)
                                .labelsHidden()
                            HStack(spacing: 4) {
                                TextField("2", value: $localTitleStyle.strokeWidth, formatter: NumberFormatter())
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
                            TextField("4", value: $localTitleStyle.shadowOffsetX, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 40)
                        }
                        HStack(spacing: 4) {
                            Text("Y:")
                            TextField("315", value: $localTitleStyle.shadowOffsetY, formatter: NumberFormatter())
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

            Picker(selection: $localTitleStyle.alignment, label: EmptyView()) {
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
            get: { localTitleStyle.textColor.color },
            set: { localTitleStyle.textColor = CodableColor(color: NSColor($0)) }
        )
    }

    private var strokeColorBinding: Binding<Color> {
        Binding(
            get: { localTitleStyle.strokeColor.color },
            set: { localTitleStyle.strokeColor = CodableColor(color: NSColor($0)) }
        )
    }

    private var shadowColorBinding: Binding<Color> {
        Binding(
            get: { localTitleStyle.shadowColor.color },
            set: { localTitleStyle.shadowColor = CodableColor(color: NSColor($0)) }
        )
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        viewModel.titleStyle = localTitleStyle
        dismiss()
    }
}
