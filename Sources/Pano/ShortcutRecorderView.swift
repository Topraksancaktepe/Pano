import SwiftUI

struct ShortcutRecorderView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: model.conflictReport == nil ? "keyboard" : "exclamationmark.triangle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(model.conflictReport == nil ? Color.primary : .orange)
            Text(model.conflictReport == nil ? "Customize Shortcut"
                 : (model.conflictReport?.tasks.isEmpty == true ? "Shortcut Check Incomplete" : "Shortcut Already in Use"))
                .font(.system(size: 21, weight: .semibold, design: .rounded))

            if let candidate = model.candidate {
                ShortcutKeycaps(shortcut: candidate)
            } else {
                Text("Press your shortcut…").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary).frame(height: 44)
            }

            if let report = model.conflictReport {
                if !report.tasks.isEmpty {
                    Text("This shortcut is used for:").font(.system(size: 13))
                    Group {
                        if report.usageDescription.count > 500 {
                            ScrollView { usageText(report.usageDescription) }.frame(height: 160)
                        } else {
                            usageText(report.usageDescription)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
                Text(report.tasks.isEmpty
                     ? "Some shortcuts could not be checked. Use this shortcut anyway?"
                     : "Continue anyway? While Pano is ready, this shortcut will only capture an area for Pano.")
                    .font(.system(size: 13)).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                if report.incomplete && !report.tasks.isEmpty {
                    Text("Some apps could not be checked.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack {
                    Button("No", action: model.cancelRecorder).keyboardShortcut(.cancelAction)
                    Button("Yes, Use Shortcut", action: model.saveRecordedShortcut)
                        .buttonStyle(.borderedProminent).tint(.green)
                }
            } else if model.checkingConflict {
                ProgressView().controlSize(.small)
                Text("Checking existing shortcuts…").font(.system(size: 12)).foregroundStyle(.secondary)
                Button("Cancel", action: model.cancelRecorder)
            } else {
                if let message = model.recorderMessage {
                    Text(message).font(.system(size: 12)).foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.isRecording {
                    Label("Recording", systemImage: "record.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.red)
                    Text("Press the keys together, release them, then click Stop Recording with your mouse.")
                        .font(.system(size: 13)).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Checks macOS shortcuts and open app menus. Other app shortcuts may not be detected.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Cancel", action: model.cancelRecorder)
                    if model.isRecording {
                        Button("Stop Recording", action: model.stopRecording)
                            .buttonStyle(.borderedProminent).tint(.green)
                    } else {
                        Button("Record Again", action: model.beginRecording)
                            .buttonStyle(.borderedProminent).tint(.green)
                    }
                }
            }
        }
        .padding(30).frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .interactiveDismissDisabled()
    }
    private func usageText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

}
