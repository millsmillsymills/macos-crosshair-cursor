import SwiftUI

/// The Preferences pane: color well, opacity slider, thickness stepper, a
/// read-only hotkey label, and the launch-at-login toggle. Every control edits
/// `SettingsModel`, which applies the change live and persists it.
struct PreferencesView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            ColorPicker("Color", selection: colorBinding, supportsOpacity: false)

            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity: \(Int(model.opacityPercent))%")
                Slider(value: $model.opacityPercent, in: 0...100, step: 1)
            }

            Stepper(
                "Thickness: \(Int(model.thicknessPoints)) pt",
                value: $model.thicknessPoints,
                in: 1...20,
                step: 1
            )

            LabeledContent("Toggle Hotkey", value: model.hotKeyLabel)

            Toggle("Launch at login", isOn: $model.launchAtLogin)

            if let note = model.launchAtLoginNote {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if model.saveFailed {
                Text("Couldn't save your settings — changes apply now but will be lost when Crosshair quits.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: model.color) },
            set: { model.color = NSColor($0) }
        )
    }
}
