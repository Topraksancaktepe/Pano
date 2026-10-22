import SwiftUI

struct ShortcutKeycaps: View {
    let shortcut: CaptureShortcut
    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(shortcut.keycaps.enumerated()), id: \.offset) { _, label in
                Text(label).font(.system(size: label.count > 3 ? 14 : 22, weight: .medium, design: .rounded))
                    .padding(.horizontal, 12).frame(minWidth: 44, minHeight: 44)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.10)))
                    .shadow(color: .black.opacity(0.04), radius: 0, y: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shortcut.display)
    }
}
