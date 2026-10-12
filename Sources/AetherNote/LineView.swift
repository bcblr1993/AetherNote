import SwiftUI
import AetherNoteCore

struct LineView: View {
    @EnvironmentObject var model: AppModel
    var openDay: (Day) -> Void
    var review: () -> Void
    var settings: () -> Void
    var hide: () -> Void
    @State private var dragging: Day?
    @State private var translation = CGSize.zero
    @State private var ropePull = 0.0
    private var spring: Animation? { model.reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.58) }
    var body: some View {
        VStack(spacing: 0) {
            toolbar.padding(.horizontal, 16).padding(.vertical, 7).noteSurface().padding(.horizontal, 38)
            GeometryReader { geo in
                let days = model.visibleDays
                let gap: CGFloat = 18
                let cardWidth = min(148, (geo.size.width - 100 - gap * CGFloat(days.count - 1)) / CGFloat(days.count))
                let stride = cardWidth + gap
                let total = stride * CGFloat(days.count) - gap
                let start = (geo.size.width - total) / 2 + cardWidth / 2
                Path { p in
                    p.move(to: CGPoint(x: 18, y: 22))
                    p.addQuadCurve(to: CGPoint(x: geo.size.width - 18, y: 22), control: CGPoint(x: geo.size.width / 2, y: 53 + ropePull))
                }
                .stroke(Color(red: 0.58, green: 0.49, blue: 0.36), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 2)
                .padding(.top, 0)
                .contentShape(Rectangle().path(in: CGRect(x: 0, y: 8, width: geo.size.width, height: 52)))
                .onTapGesture(count: 2) { withAnimation(spring) { model.tidy() } }
                .gesture(DragGesture().onChanged { value in
                    if !model.reduceMotion { ropePull = min(45, max(-18, value.translation.height * 0.4)) }
                }.onEnded { _ in withAnimation(spring) { ropePull = 0 } })
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let isDragging = dragging == day
                    let offset = isDragging ? translation : .zero
                    let bend = sin(Double(index + 1) / Double(days.count + 1) * .pi)
                    DayCard(day: day, open: { openDay(day) })
                        .frame(width: cardWidth, height: 193)
                        .rotationEffect(.degrees(model.reduceMotion ? 0 : (isDragging ? Double(offset.width / 20) : (index % 2 == 0 ? -1.8 : 1.8))))
                        .scaleEffect(isDragging && !model.reduceMotion ? 1.04 : 1)
                        .position(x: start + CGFloat(index) * stride + offset.width, y: 119 + bend * 12 + offset.height * 0.45 + ropePull * bend * 0.4)
                        .zIndex(isDragging ? 10 : 1)
                        .gesture(DragGesture(minimumDistance: 7).onChanged { value in
                            dragging = day; translation = CGSize(width: value.translation.width, height: min(110, max(-30, value.translation.height)))
                        }.onEnded { value in
                            let destination = min(days.count - 1, max(0, index + Int((value.translation.width / stride).rounded())))
                            withAnimation(spring) {
                                model.reorder(day, to: days[destination]); dragging = nil; translation = .zero
                            }
                        })
                        .animation(spring, value: days)
                        .contextMenu {
                            Button(model.l("moveLeft")) { withAnimation(spring) { model.move(day, by: -1) } }
                            Button(model.l("moveRight")) { withAnimation(spring) { model.move(day, by: 1) } }
                            Divider()
                            Button(model.l("copy")) { model.copy(model.journal.records(on: day).map(\.text).joined(separator: "\n")) }
                        }
                }
            }.frame(height: 264)
            Text(model.toast ?? model.l("dragHint")).font(.system(size: 10)).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 5).background(.regularMaterial, in: Capsule())
        }.padding(.top, 8).padding(.bottom, 12).errors(model)
    }
    private var toolbar: some View {
        HStack(spacing: 7) {
            Text("AetherNote").font(.system(size: 13, weight: .semibold, design: .rounded))
            Divider().frame(height: 15)
            IconButton(symbol: "chevron.left", title: model.l("previous")) { model.navigateWeek(-1) }
            Button(model.weekLabel) { model.week = model.today.week().first! }.buttonStyle(.plain).font(.system(size: 12, design: .monospaced)).help(model.l("thisWeek"))
            IconButton(symbol: "chevron.right", title: model.l("next")) { model.navigateWeek(1) }
            Spacer(minLength: 4)
            Button { openDay(model.today) } label: { Label(model.l("add"), systemImage: "plus") }.buttonStyle(AccentButton())
            IconButton(symbol: "sparkles", title: model.l("tidy")) { withAnimation(spring) { model.tidy() } }
            IconButton(symbol: "book.closed", title: model.l("review"), action: review)
            IconButton(symbol: model.preferences.pinned ? "pin.fill" : "pin", title: model.l("pin"), selected: model.preferences.pinned) { model.preferences.pinned.toggle() }
            IconButton(symbol: "slider.horizontal.3", title: model.l("settings"), action: settings)
            IconButton(symbol: "xmark", title: model.l("hide"), action: hide)
        }
    }
}

struct DayCard: View {
    @EnvironmentObject var model: AppModel
    let day: Day
    let open: () -> Void
    @State private var hovered = false
    private var records: [Entry] { model.journal.records(on: day) }
    var body: some View {
        VStack(spacing: -5) {
            Capsule().fill(day == model.today ? Color.accentColor : Color(red: 0.7, green: 0.55, blue: 0.34)).frame(width: 9, height: 25).overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1)).zIndex(2)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.weekday(day)).font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(model.shortDate(day)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                if records.isEmpty {
                    Text(model.l(day == model.today ? "empty" : day < model.today ? "noEntries" : "future"))
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(3)
                    Spacer(minLength: 0)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(records.prefix(3)) { entry in
                            HStack(alignment: .top, spacing: 5) {
                                Circle().fill(Color.accentColor.opacity(0.65)).frame(width: 3, height: 3).padding(.top, 6)
                                Text(entry.text).font(.system(size: 11)).lineLimit(2)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    if day == model.today { Text(model.l("today")).foregroundStyle(Color.accentColor) }
                    else if day < model.today { Image(systemName: "lock.fill"); Text(model.l("sealed")) }
                    Spacer(minLength: 0)
                    if !records.isEmpty { Text("\(records.count)").monospacedDigit() }
                }.font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            }.padding(13).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .noteSurface().shadow(color: .black.opacity(hovered ? 0.18 : 0.1), radius: hovered ? 15 : 8, y: hovered ? 8 : 4)
        }
        .contentShape(Rectangle()).onTapGesture(perform: open).onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.rawValue), \(model.weekday(day)), \(records.count) \(model.l("entries")), \(model.l(day == model.today ? "today" : day < model.today ? "sealed" : "future"))")
        .accessibilityAddTraits(.isButton).accessibilityAction { open() }
        .accessibilityAction(named: Text(model.l("moveLeft"))) { model.move(day, by: -1) }
        .accessibilityAction(named: Text(model.l("moveRight"))) { model.move(day, by: 1) }
        .accessibilityIdentifier("day-\(day.rawValue)")
    }
}
