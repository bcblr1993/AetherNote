import AppKit
import SwiftUI

struct NativeGlass: NSViewRepresentable {
    var radius: CGFloat = 24
    var tint: Color? = nil
    func makeNSView(context: Context) -> NSView {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            let view = NSGlassEffectView()
            view.cornerRadius = radius
            view.style = .regular
            view.tintColor = tint.map { NSColor($0).withAlphaComponent(0.16) }
            return view
        }
        #endif
        let view = NSVisualEffectView()
        view.material = .popover; view.blendingMode = .behindWindow; view.state = .active
        view.wantsLayer = true; view.layer?.cornerRadius = radius
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), let glass = nsView as? NSGlassEffectView {
            glass.tintColor = tint.map { NSColor($0).withAlphaComponent(0.16) }
        }
        #endif
    }
}

struct NoteSurface: ViewModifier {
    var tint: Color? = nil
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var contrast
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content.background {
            ZStack {
                if model.preferences.material == .glass && !reduceTransparency {
                    NativeGlass(tint: tint)
                        .overlay(colorScheme == .dark ? Color.black.opacity(0.38) : Color.white.opacity(0.26))
                        .overlay(LinearGradient(colors: [.cyan.opacity(0.035), .clear, .indigo.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .ignoresSafeArea()
                } else {
                    RoundedRectangle(cornerRadius: 24).fill(model.preferences.material == .paper ? Color(red: 0.98, green: 0.96, blue: 0.90) : (model.preferences.material == .white ? Color(red: 0.98, green: 0.985, blue: 0.995) : Color(nsColor: .windowBackgroundColor))).ignoresSafeArea()
                }
                if let tint {
                    LinearGradient(colors: [tint.opacity(colorScheme == .dark ? 0.28 : 0.30), tint.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        }
        .foregroundStyle(model.preferences.material != .glass ? Color(red: 0.24, green: 0.22, blue: 0.18) : Color.primary)
        .environment(\.colorScheme, model.preferences.material != .glass ? .light : colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(contrast == .increased ? 0.65 : 0.10), lineWidth: contrast == .increased ? 2 : 0.5))
        .animation(model.reduceMotion ? nil : .easeInOut(duration: 0.22), value: tint)
    }
}

struct InsetSurface: ViewModifier {
    var selected = false
    var tint: Color? = nil
    @Environment(\.colorScheme) var scheme
    @Environment(\.colorSchemeContrast) var contrast
    func body(content: Content) -> some View {
        content.background(tint?.opacity(selected ? 0.18 : 0.09) ?? (selected ? Color.accentColor.opacity(0.09) : Color.primary.opacity(scheme == .dark ? 0.045 : 0.025)), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(contrast == .increased ? 0.5 : 0.07), lineWidth: contrast == .increased ? 1.5 : 0.7))
    }
}

struct GlassButton: ButtonStyle {
    var primary = false
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        GlassButtonBody(configuration: configuration, primary: primary, compact: compact)
    }
}
private struct GlassButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool
    let compact: Bool
    @State private var hovered = false
    @EnvironmentObject var model: AppModel
    @Environment(\.isEnabled) var enabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var contrast
    var body: some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Color.primary)
            .padding(.horizontal, compact ? 0 : 14).frame(minWidth: 32, minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: 10).fill(primary ? Color.accentColor : Color.primary.opacity(hovered ? 0.10 : 0.045))
                if primary { RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)) }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(contrast == .increased ? 0.5 : 0.07), lineWidth: 0.7))
            .brightness(configuration.isPressed ? -0.07 : 0)
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion && !model.reduceMotion ? 0.97 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onHover { hovered = $0 }
            .animation(reduceMotion || model.reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
    }
}
struct AccentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { GlassButtonBody(configuration: configuration, primary: true, compact: false) }
}

struct PanelHeading: View {
    let symbol: String
    let title: String
    let subtitle: String
    var tint: Color = .accentColor
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 21, weight: .medium)).foregroundStyle(tint)
                .frame(width: 48, height: 48).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 23, weight: .semibold, design: .rounded))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
struct StatusPill: View {
    let text: String
    var accent = false
    var body: some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(accent ? Color.accentColor : .secondary)
            .padding(.horizontal, 9).padding(.vertical, 5).background((accent ? Color.accentColor : .primary).opacity(0.075), in: Capsule())
    }
}

extension View {
    func noteSurface(tint: Color? = nil) -> some View { modifier(NoteSurface(tint: tint)) }
    func insetSurface(selected: Bool = false, tint: Color? = nil) -> some View { modifier(InsetSurface(selected: selected, tint: tint)) }
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
        Button(action: action) { Image(systemName: symbol).font(.system(size: 13, weight: .medium)).frame(width: 32, height: 32) }
            .buttonStyle(GlassButton(compact: true))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
            .help(title).accessibilityLabel(title)
    }
}

struct CurrentWeekButton: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Button { model.returnToCurrentWeek() } label: {
            Label(model.l("thisWeek"), systemImage: "arrow.uturn.backward")
                .fixedSize()
        }
        .buttonStyle(GlassButton())
        .accessibilityIdentifier("return-current-week")
        .help(model.l("thisWeek"))
    }
}
