import AppKit
import SwiftUI

struct NativeGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let view = NSGlassEffectView()
            view.cornerRadius = 22
            view.style = .regular
            #if compiler(>=6.4)
            if #available(macOS 27.0, *) { view.effectIsInteractive = true }
            #endif
            return view
        }
        #endif
        let view = NSVisualEffectView()
        view.material = .popover; view.blendingMode = .behindWindow; view.state = .active
        view.wantsLayer = true; view.layer?.cornerRadius = 22
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct NoteSurface: ViewModifier {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var contrast
    func body(content: Content) -> some View {
        content.background {
            if model.preferences.material == .glass && !reduceTransparency {
                NativeGlass()
            } else {
                RoundedRectangle(cornerRadius: 22).fill(model.preferences.material == .paper ? Color(red: 0.98, green: 0.94, blue: 0.83) : Color(nsColor: .windowBackgroundColor))
            }
        }
        .foregroundStyle(model.preferences.material == .paper ? Color(red: 0.27, green: 0.23, blue: 0.17) : Color.primary)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(contrast == .increased ? 0.65 : 0.12), lineWidth: contrast == .increased ? 2 : 0.7))
    }
}
extension View {
    func noteSurface() -> some View { modifier(NoteSurface()) }
    func errors(_ model: AppModel) -> some View {
        alert(model.l("error"), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(model.l("ok")) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct IconButton: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13, weight: .medium)).frame(width: 30, height: 30).contentShape(Rectangle()) }
            .buttonStyle(.plain).background(selected ? Color.accentColor.opacity(0.16) : Color.clear, in: Circle())
            .help(title).accessibilityLabel(title)
    }
}
