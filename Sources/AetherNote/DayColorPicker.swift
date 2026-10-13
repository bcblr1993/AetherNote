import SwiftUI
import AppKit
import AetherNoteCore

extension DayColor {
    var tint: Color { Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255) }
    var nameKey: String { Self.palette.firstIndex(of: rgb).map { Self.names[$0] } ?? "customColor" }
    static func rgb(from color: Color) -> UInt32? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func channel(_ value: CGFloat) -> UInt32 { UInt32((min(1, max(0, value)) * 255).rounded()) }
        return channel(rgb.redComponent) << 16 | channel(rgb.greenComponent) << 8 | channel(rgb.blueComponent)
    }
}

struct DayColorButton: View {
    @EnvironmentObject var model: AppModel
    let day: Day
    @State private var presented = false
    var body: some View {
        Button { presented.toggle() } label: {
            HStack(spacing: 6) {
                Circle().fill(model.dayColor(day).tint.gradient).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                Text(model.l("dayColor"))
            }
        }.buttonStyle(GlassButton()).help(model.l("dayColor"))
            .accessibilityLabel(model.l("dayColor"))
            .accessibilityValue(model.l(model.dayColor(day).nameKey))
            .popover(isPresented: $presented, attachmentAnchor: .point(.bottomLeading), arrowEdge: .bottom) { DayColorPicker(day: day).environmentObject(model) }
    }
}

struct DayColorPicker: View {
    @EnvironmentObject var model: AppModel
    let day: Day
    @State private var hex = ""
    private var selected: DayColor { model.dayColor(day) }
    private var pendingRGB: UInt32? { DayColor(hex: hex)?.rgb }
    private var custom: Binding<Color> {
        Binding(get: { preview }, set: { if let rgb = DayColor.rgb(from: $0) { hex = DayColor(rgb: rgb).hex } })
    }
    private var hasPendingColor: Bool { pendingRGB != selected.rgb }
    private var preview: Color { pendingRGB.map { DayColor(rgb: $0).tint } ?? selected.tint }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.l("dayColor")).font(.system(size: 16, weight: .semibold))
                    Text("\(model.weekday(day)) · \(model.shortDate(day))").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: model.l(selected.isCustom ? "colorPersonal" : "colorAutomatic"))
            }
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 3).fill(preview.gradient).frame(width: 5, height: 38)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.l("colorPreview")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    Text(model.journal.records(on: day).first?.text ?? model.l("welcome"))
                        .font(.system(size: 13, weight: .medium)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(14).background(LinearGradient(colors: [preview.opacity(0.24), preview.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                ForEach(Array(DayColor.palette.enumerated()), id: \.element) { index, rgb in
                    Button {
                        model.setColor(rgb, day: day)
                        resetPreview()
                    } label: {
                        VStack(spacing: 6) {
                            Circle().fill(DayColor(rgb: rgb).tint.gradient).frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                                .overlay { if selected.rgb == rgb { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.black.opacity(0.75)) } }
                                .padding(4).overlay(Circle().strokeBorder(selected.rgb == rgb ? Color.primary.opacity(0.55) : .clear, lineWidth: 1))
                            Text(model.l(DayColor.names[index])).font(.system(size: 10)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(model.l(DayColor.names[index]))
                        .accessibilityAddTraits(selected.rgb == rgb ? .isSelected : [])
                }
            }
            VStack(spacing: 10) {
                HStack {
                    ColorPicker(model.l("customColor"), selection: custom, supportsOpacity: false).font(.system(size: 12))
                    Button(model.l("applyColor")) { if let rgb = pendingRGB { model.setColor(rgb, day: day) } }
                        .buttonStyle(GlassButton()).disabled(pendingRGB == nil || pendingRGB == selected.rgb)
                }
                HStack(spacing: 8) {
                    Text("HEX").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    TextField("#709DB9", text: $hex).textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 9).frame(height: 28).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityLabel(model.l("colorHex"))
                        .onSubmit { if let rgb = pendingRGB { model.setColor(rgb, day: day) } }
                    if pendingRGB == nil { Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary).help(model.l("colorHexHint")) }
                }
            }.padding(12).insetSurface()
            HStack {
                Button { model.randomizeColor(day) } label: { Label(model.l("randomColor"), systemImage: "shuffle") }.buttonStyle(GlassButton())
                Spacer()
                Text(model.l(hasPendingColor ? "colorPending" : "colorSaved")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text(model.l("colorHint")).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(width: 304)
            .foregroundStyle(.primary)
            .background(.background)
            .preferredColorScheme(model.preferences.material == .glass ? nil : .light)
            .onAppear { resetPreview() }
            .onChange(of: selected) { _, _ in resetPreview() }
    }
    private func resetPreview() {
        hex = selected.hex
    }
}
