import SwiftUI
import QuickSwitchCore

/// The Settings window content: sliders for the visual style, plus layout/behavior toggles.
struct SettingsView: View {
    @ObservedObject var prefs: PreferencesStore
    let loginItem: LoginItemControlling
    /// Pauses (true) / resumes (false) global hotkeys while the recorder is active.
    var onHotKeyRecording: (Bool) -> Void = { _ in }

    @State private var launchAtLogin = false

    /// Carbon masks offered for the digit direct-open keys. ⌘ alone is deliberately
    /// omitted — it would steal ⌘1-9 tab switching from browsers/editors system-wide.
    private static let digitModifierOptions = [
        2048,        // ⌥
        4096,        // ⌃
        4096 | 2048, // ⌃⌥
        256 | 2048,  // ⌘⌥
        4096 | 256,  // ⌃⌘
    ]

    var body: some View {
        Form {
            Section("布局") {
                Picker("方向", selection: $prefs.axis) {
                    Text("横向").tag(DockAxis.horizontal)
                    Text("竖向").tag(DockAxis.vertical)
                }
                .pickerStyle(.segmented)
                Toggle("显示 + 按钮", isOn: $prefs.showAddButton)
            }

            Section("尺寸与样式") {
                slider("图标大小", value: $prefs.iconSize,
                       range: PreferencesStore.Default.iconSizeRange, suffix: "")
                slider("圆角", value: $prefs.cornerRadius,
                       range: PreferencesStore.Default.cornerRadiusRange, suffix: "")
                slider("背景透明度", value: $prefs.backgroundOpacity,
                       range: PreferencesStore.Default.backgroundOpacityRange, percent: true)
                slider("图标间距", value: $prefs.spacing,
                       range: PreferencesStore.Default.spacingRange, suffix: "")
                slider("内边距", value: $prefs.padding,
                       range: PreferencesStore.Default.paddingRange, suffix: "")
            }

            Section("快捷键") {
                Toggle("全局唤出 / 收起", isOn: $prefs.summonHotKeyEnabled)
                HStack {
                    Text("组合键")
                    Spacer()
                    HotKeyRecorder(keyCode: $prefs.summonKeyCode,
                                   modifiers: $prefs.summonModifiers,
                                   onRecordingChanged: onHotKeyRecording)
                }
                .disabled(!prefs.summonHotKeyEnabled)
                Toggle("数字键直达前 9 个条目", isOn: $prefs.digitHotKeysEnabled)
                Picker("直达修饰键", selection: $prefs.digitModifiers) {
                    ForEach(Self.digitModifierOptions, id: \.self) { mask in
                        Text(KeyCombo.modifierSymbols(mask) + "1–9").tag(mask)
                    }
                }
                .disabled(!prefs.digitHotKeysEnabled)
            }

            Section("行为") {
                Toggle("窗口置顶", isOn: $prefs.alwaysOnTop)
                Toggle("菜单栏图标", isOn: $prefs.showMenuBarIcon)
                Toggle("点击前台应用时隐藏它", isOn: $prefs.clickFrontmostHides)
                Toggle("开机自启", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        try? loginItem.setEnabled(newValue)
                        launchAtLogin = loginItem.isEnabled
                    }
            }

            Section {
                Button("恢复默认样式") { prefs.resetStyle() }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { launchAtLogin = loginItem.isEnabled }
    }

    @ViewBuilder
    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, suffix: String = "", percent: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(title).frame(width: 72, alignment: .leading)
            Slider(value: value, in: range)
            Text(percent ? "\(Int((value.wrappedValue * 100).rounded()))%"
                         : "\(Int(value.wrappedValue.rounded()))\(suffix)")
                .frame(width: 44, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
