import SwiftUI

/// Notifications + output-trigger settings (v1.2). All global for now — not per-profile.
struct AlertsPane: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsPane {
            Text(L("alerts.section.notifications")).font(Hum.Font.display(13, weight: .semibold))

            Toggle(L("alerts.notify_exit"), isOn: settings.bind(\.notifyProcessExit))
            if settings.notifyProcessExit {
                SettingRow(label: L("alerts.notify_exit_after")) {
                    Text(L("alerts.seconds", settings.notifyProcessExitThreshold))
                        .foregroundStyle(Hum.ink2).monospacedDigit()
                    Stepper("", value: settings.bind(\.notifyProcessExitThreshold), in: 1...3600, step: 5)
                        .labelsHidden()
                }
            }
            Toggle(L("alerts.notify_bell"), isOn: settings.bind(\.notifyOnBell))
            Toggle(L("alerts.notify_inactive_only"), isOn: settings.bind(\.notifyOnlyWhenInactive))

            VStack(alignment: .leading, spacing: 4) {
                Text(L("alerts.watch_strings")).foregroundStyle(Hum.ink)
                TextEditor(text: settings.bind(\.notifyWatchStrings))
                    .font(Hum.Font.mono(12))
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Hum.hairline))
            }

            Divider().padding(.vertical, Hum.Space.sm)

            Text(L("alerts.section.triggers")).font(Hum.Font.display(13, weight: .semibold))
            settingsHint(L("alerts.triggers.hint"))

            ForEach(settings.triggers) { trigger in
                triggerRow(trigger)
            }
            Button {
                var list = settings.triggers
                list.append(Trigger(pattern: "", action: TriggerAction(kind: .notify)))
                settings.triggers = list
            } label: {
                Label(L("alerts.triggers.add"), systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private func triggerRow(_ trigger: Trigger) -> some View {
        HStack(spacing: Hum.Space.sm) {
            Toggle("", isOn: binding(trigger, \.enabled))
                .labelsHidden()
                .accessibilityLabel(L("alerts.triggers.enabled"))
            TextField(L("alerts.triggers.pattern"), text: binding(trigger, \.pattern))
                .font(Hum.Font.mono(12))
                .frame(minWidth: 160)
                .accessibilityLabel(L("alerts.triggers.pattern"))
            Picker("", selection: binding(trigger, \.action.kind)) {
                Text(L("alerts.triggers.action.notify")).tag(TriggerAction.Kind.notify)
                Text(L("alerts.triggers.action.bell")).tag(TriggerAction.Kind.bell)
                Text(L("alerts.triggers.action.color")).tag(TriggerAction.Kind.color)
            }
            .labelsHidden().frame(width: 110)
            .accessibilityLabel(L("alerts.section.triggers"))
            if trigger.action.kind == .color {
                Stepper(value: binding(trigger, \.action.colorIndex), in: 0...(Hum.accents.count - 1)) {
                    HStack(spacing: 4) {
                        Circle().fill(Hum.accent(trigger.action.colorIndex).tint).frame(width: 12, height: 12)
                        Text(Hum.accentName(trigger.action.colorIndex)).font(Hum.Font.body(11))
                    }
                }
                .accessibilityLabel(Hum.accentName(trigger.action.colorIndex))
            }
            Button(role: .destructive) {
                settings.triggers.removeAll { $0.id == trigger.id }
            } label: {
                Image(systemName: "trash").frame(width: 26, height: 26).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("alerts.triggers.remove"))
            .accessibilityLabel(L("alerts.triggers.remove"))
        }
    }

    /// Binding into one trigger inside `settings.triggers`, keyed by id.
    private func binding<Value>(_ trigger: Trigger,
                                _ keyPath: WritableKeyPath<Trigger, Value>) -> Binding<Value> {
        Binding(
            get: {
                (settings.triggers.first { $0.id == trigger.id } ?? trigger)[keyPath: keyPath]
            },
            set: { newValue in
                var list = settings.triggers
                guard let i = list.firstIndex(where: { $0.id == trigger.id }) else { return }
                list[i][keyPath: keyPath] = newValue
                settings.triggers = list
            }
        )
    }
}
