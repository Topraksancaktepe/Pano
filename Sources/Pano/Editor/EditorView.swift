import SwiftUI
import PanoCore

enum EditorTheme {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.38, green: 0.84, blue: 0.63, alpha: 1)
            : NSColor(srgbRed: 0.10, green: 0.46, blue: 0.32, alpha: 1)
    })
}

struct PixelateGlyph: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3) { column in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.primary.opacity([0.3, 0.8, 0.5, 1, 0.45, 0.7, 0.65, 0.3, 0.9][row * 3 + column]))
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}

struct EditorView: View {
    @ObservedObject var model: EditorModel
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            options
            Divider()
            canvas
            Divider()
            footer
        }
        .tint(EditorTheme.accent)
        .frame(minWidth: 700, minHeight: 440)
        .alert("Could not finish", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "Please try again.") }
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 14) {
                Button(action: model.undo) { Image(systemName: "arrow.uturn.backward") }
                    .help("Undo (⌘Z)").accessibilityLabel("Undo")
                    .disabled(!model.history.canUndo || model.isRendering)
                Button(action: model.redo) { Image(systemName: "arrow.uturn.forward") }
                    .help("Redo (⇧⌘Z)").accessibilityLabel("Redo")
                    .disabled(!model.history.canRedo || model.isRendering)
            }
            .frame(width: 176, alignment: .leading)
            Spacer(minLength: 0)
            toolGroups
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button(action: onSave) { Label("Save", systemImage: "square.and.arrow.down") }
                    .help("Save Image (⌘S)").disabled(model.isRendering)
                Button(action: model.copy) { Label("Copy", systemImage: "doc.on.doc").padding(.horizontal, 4) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .help("Copy Image (⌘C)").disabled(model.isRendering)
            }
            .frame(width: 176, alignment: .trailing)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.bar)
    }

    private var toolGroups: some View {
        HStack(spacing: 6) {
            ForEach(EditorGroup.allCases, id: \.self) { group in
                Button { model.group = group } label: {
                    HStack(spacing: 7) {
                        if group == .redact { PixelateGlyph() }
                        else { Image(systemName: group == .markup ? "pencil.tip" : "list.number").frame(width: 16) }
                        Text(group.rawValue).font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12).frame(height: 34)
                    .foregroundStyle(model.group == group ? EditorTheme.accent : .primary)
                    .background(model.group == group ? EditorTheme.accent.opacity(0.13) : .clear,
                                in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).accessibilityLabel(group.rawValue)
            }
        }
        .fixedSize()
    }

    private var options: some View {
        HStack(spacing: 12) {
            switch model.group {
            case .markup:
                toolButton("Arrow", symbol: "arrow.up.right", tool: .arrow)
                toolButton("Pen", symbol: "pencil.tip", tool: .pen)
                toolButton("Highlight", symbol: "highlighter", tool: .highlight)
                optionsDivider
                palette
                optionsDivider
                sizePicker
            case .redact:
                toolButton("Smooth Blur", symbol: "drop.halffull", tool: .smoothBlur)
                toolButton("Pixelate", symbol: nil, tool: .pixelate)
                optionsDivider
                Text("Strength").font(.system(size: 11)).foregroundStyle(.secondary)
                Slider(value: $model.strength, in: 8...40, step: 1).frame(width: 110)
                    .accessibilityLabel("Blur strength")
            case .steps:
                Text("\(model.history.nextStep)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(nsColor: model.color.textColor)).frame(width: 27, height: 27)
                    .background(Color(nsColor: model.color.nsColor), in: Circle())
                Text("Click to number each step").font(.system(size: 12)).foregroundStyle(.secondary)
                optionsDivider
                palette
                optionsDivider
                sizePicker
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20).frame(height: 54)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var optionsDivider: some View { Divider().frame(height: 18).padding(.horizontal, 2) }

    private func toolButton(_ title: String, symbol: String?, tool: AnnotationTool) -> some View {
        Button {
            if tool.isRedaction { model.redactTool = tool }
            else { model.markupTool = tool }
        } label: {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol) } else { PixelateGlyph() }
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 9).frame(height: 28)
            .foregroundStyle(model.tool == tool ? EditorTheme.accent : .secondary)
            .background(model.tool == tool ? EditorTheme.accent.opacity(0.11) : .clear,
                        in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).accessibilityLabel(title)
    }

    private var palette: some View {
        HStack(spacing: 7) {
            ForEach(AnnotationColor.allCases) { color in
                Button { model.color = color } label: {
                    Circle().fill(Color(nsColor: color.nsColor))
                        .frame(width: 15, height: 15)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.13), lineWidth: 0.7))
                        .padding(3)
                        .overlay(Circle().strokeBorder(model.color == color ? EditorTheme.accent : .clear, lineWidth: 1.5))
                }.buttonStyle(.plain).help(color.rawValue.capitalized)
                    .accessibilityLabel("\(color.rawValue.capitalized) color")
                    .accessibilityAddTraits(model.color == color ? [.isSelected] : [])
            }
            ColorPicker("Custom Color", selection: Binding(
                get: { Color(nsColor: model.color.nsColor) },
                set: { color in
                    guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                    model.color = .custom(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
                }), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 26, height: 26)
                .help("Choose a custom color")
                .accessibilityLabel("Custom color palette")
        }
    }

    private var sizePicker: some View {
        Menu {
            Button("Small") { model.strokeWidth = 2.5 }
            Button("Medium") { model.strokeWidth = 4 }
            Button("Large") { model.strokeWidth = 7 }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(.primary).frame(width: model.strokeWidth + 2, height: model.strokeWidth + 2)
                Text(model.strokeWidth < 4 ? "Small" : model.strokeWidth > 4 ? "Large" : "Medium")
                    .font(.system(size: 11))
            }
        }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Stroke size")
    }

    private var canvas: some View {
        GeometryReader { geometry in
            let available = CGSize(width: max(1, geometry.size.width - 64), height: max(1, geometry.size.height - 64))
            let fit = min(1, min(available.width / model.original.size.width, available.height / model.original.size.height))
            let scale = fit * model.zoom
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(model: model)
                    .frame(width: model.original.size.width * scale, height: model.original.size.height * scale)
                    .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 6)
                    .padding(32)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
            .background(Color(nsColor: .windowBackgroundColor).gradient)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: model.message.isEmpty ? "viewfinder" : "checkmark.circle.fill")
                .foregroundStyle(EditorTheme.accent)
            Text(model.message.isEmpty ? "\(model.image.width) × \(model.image.height)" : model.message)
                .monospacedDigit()
            Spacer()
            if model.isRendering { ProgressView().controlSize(.mini) }
            Text(model.isRendering ? "Applying…" : model.hint).foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button { model.zoom = max(0.5, model.zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .accessibilityLabel("Zoom out")
            Button { model.zoom = 1 } label: { Text(model.zoom == 1 ? "Fit" : "\(Int(model.zoom * 100))%")
                    .frame(width: 38) }
                .help("Fit image to window").accessibilityLabel("Fit image")
            Button { model.zoom = min(8, model.zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .accessibilityLabel("Zoom in")
        }
        .font(.system(size: 11)).buttonStyle(.borderless)
        .padding(.horizontal, 18).frame(height: 38).background(.bar)
    }
}
