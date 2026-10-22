import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    private let green = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.38, green: 0.84, blue: 0.63, alpha: 1)
            : NSColor(srgbRed: 0.10, green: 0.46, blue: 0.32, alpha: 1)
    })

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 7) {
                Image(systemName: "viewfinder").font(.system(size: 15, weight: .bold)).foregroundStyle(green)
                Text("PANO").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(2)
                Spacer()
                Label(model.ready ? "Ready" : "Finish Setup",
                      systemImage: model.ready ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(model.ready ? green : .secondary)
            }

            VStack(spacing: 17) {
                ZStack {
                    RoundedRectangle(cornerRadius: 19).fill(green.opacity(0.09)).frame(width: 76, height: 76)
                    Image(systemName: "viewfinder").font(.system(size: 35, weight: .medium)).foregroundStyle(green)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 18)).foregroundStyle(green)
                        .padding(6).background(.background, in: RoundedRectangle(cornerRadius: 9))
                        .offset(x: 24, y: 25)
                }.padding(.bottom, 4)
                Text("Select And Paste.")
                    .font(.system(size: 28, weight: .semibold, design: .rounded)).tracking(-0.8)
            }

            VStack(spacing: 14) {
                ShortcutKeycaps(shortcut: model.shortcut)
                Button("Customize Shortcut", action: model.beginRecording)
                    .buttonStyle(.link).font(.system(size: 12, weight: .medium))
                    .disabled(!model.accessibility || !model.shortcutActive || model.busy)
            }

            VStack(spacing: 0) {
                permissionRow(title: "Accessibility", subtitle: "Use your shortcut anywhere on your Mac.",
                              allowed: model.accessibility, action: model.requestAccessibility)
                Divider().padding(.leading, 48)
                permissionRow(title: "Screen Recording", subtitle: "Capture the area you select.",
                              allowed: model.screenAccess, action: model.requestScreenAccess)
            }
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { model.loginEnabled }, set: model.setLoginEnabled)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at Login").font(.system(size: 13, weight: .medium))
                        Text("Ready in the menu bar when you need it.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }.toggleStyle(.switch).tint(green)
                if model.loginNeedsApproval {
                    Button("Allow Launch at Login in System Settings", action: model.openLoginSettings)
                        .font(.system(size: 11))
                }
            }

            if let error = model.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if model.accessibility && !model.shortcutActive {
                Text("Could not activate the shortcut. Quit and reopen Pano.")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }

            Button(action: model.capture) {
                Label(model.busy ? "Selecting…" : "Select and Copy", systemImage: "viewfinder")
                    .font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).tint(green).disabled(!model.ready || model.busy)
        }
        .padding(30)
        .frame(width: 470)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $model.recorderPresented, onDismiss: model.cancelRecorder) {
            ShortcutRecorderView(model: model)
        }
    }

    private func permissionRow(title: String, subtitle: String, allowed: Bool,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(allowed ? green : Color.secondary.opacity(0.5)).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if allowed {
                Text("Allowed").font(.system(size: 11, weight: .medium)).foregroundStyle(green)
            } else {
                Button("Allow", action: action).controlSize(.small)
            }
        }.padding(15)
    }
}
