import AppKit
import SwiftUI

struct ControlView: View {
    @ObservedObject var controller: PanoController

    var body: some View {
        VStack(spacing: 21) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill((controller.isRunning ? Color.green : Color.secondary).opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: controller.isRunning ? "viewfinder" : "power")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(controller.isRunning ? Color.green : .secondary)
            }

            VStack(spacing: 8) {
                Text(controller.isRunning ? "Pano is On" : "Pano is Off")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(controller.isRunning
                     ? "Your screenshot shortcut copies the selected area to the clipboard."
                     : "Turn on Pano to use your screenshot shortcut.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: controller.toggle) {
                Label(controller.isChanging ? "Updating…"
                      : (controller.isRunning ? "Turn Off Pano" : "Turn On Pano"),
                      systemImage: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .tint(controller.isRunning ? .gray : .green)
            .disabled(controller.isChanging)

            Button("Open Pano Settings", action: controller.openSettings)
                .buttonStyle(.link).disabled(controller.isChanging || !controller.isRunning)
                .help(controller.isRunning ? "Show Pano Settings" : "Turn on Pano to open settings.")

            if let error = controller.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Text("Closing this window keeps Pano running.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 400)
        .onAppear { controller.refresh() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
            controller.refresh()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            controller.refresh()
        }
    }
}
