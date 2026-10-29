import PeekabooCore
import SwiftUI

/// The whole notch: one black shape that springs between sizes, with content that fades in on top.
struct NotchRootView: View {
    @ObservedObject var model: NotchModel

    /// Apple-style motion: a spring with gentle bounce on the way out, critically damped on the way in.
    private var morph: Animation {
        if model.reduceMotion { return .easeInOut(duration: 0.2) }
        return model.presentation.isExpanded
            ? .spring(response: 0.42, dampingFraction: 0.78)
            : .spring(response: 0.36, dampingFraction: 1)
    }

    var body: some View {
        let p = model.presentation
        let size = model.bodySize(p)
        let flare = model.flare
        let bottom: CGFloat = p.isExpanded ? 28 : (p == .wings ? 12 : 10)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(topRadius: flare, bottomRadius: bottom)
                    .fill(Color.black)

                content(p)
                    .padding(.horizontal, flare)
                    .id(contentKey(p))
                    .transition(model.reduceMotion ? .opacity : .blurFade)
            }
            .frame(width: size.width + flare * 2, height: size.height)
            .clipShape(NotchShape(topRadius: flare, bottomRadius: bottom))
            .shadow(color: .black.opacity(p.isExpanded ? 0.35 : 0), radius: 18, y: 8)
            .opacity(p == .hidden ? 0 : 1)
            .contentShape(NotchShape(topRadius: flare, bottomRadius: bottom))
            .onTapGesture { tap(p) }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(morph, value: p)
        .animation(morph, value: model.geometry)
        .environment(\.colorScheme, .dark)
    }

    private func contentKey(_ p: Presentation) -> String {
        switch p {
        case .hidden: "hidden"
        case .closed: "closed"
        case .wings: "wings"
        case .card(let id): "card-\(id)-\(model.record(id)?.state.rawValue ?? "")"
        case .list: "list"
        }
    }

    private func tap(_ p: Presentation) {
        switch p {
        case .card(let id):
            if let r = model.record(id) { model.open(r) }
        case .wings:
            if let r = model.sorted.first, model.active.count == 1 { model.open(r) }
        default:
            break
        }
    }

    @ViewBuilder
    private func content(_ p: Presentation) -> some View {
        switch p {
        case .hidden, .closed:
            Color.clear
        case .wings:
            WingsView(model: model)
        case .card(let id):
            if let r = model.record(id) {
                CardView(model: model, record: r)
            }
        case .list:
            ListView(model: model)
        }
    }
}

// MARK: - Wings (collapsed live activity)

private struct WingsView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        let active = model.active
        let lead = model.sorted.first { r in active.contains { $0.id == r.id } }
        let needs = active.filter { $0.state == .needs }.count
        let done = active.filter { $0.state == .done }.count
        HStack(spacing: 0) {
            if let lead {
                BuddyView(buddy: model.buddy, mood: model.mood(for: lead), tint: model.buddy.tint(for: lead.id))
                    .frame(width: model.geometry.height * 0.72, height: model.geometry.height * 0.72)
                    .padding(.leading, 12)
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                if needs > 0 {
                    PulseDot(color: .needsAmber)
                } else if done > 0 {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.doneGreen)
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    Spinner(color: .workBlue).frame(width: 12, height: 12)
                }
                Text("\(active.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .padding(.trailing, 14)
        }
        .frame(height: model.geometry.height)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Card (one session)

private struct CardView: View {
    @ObservedObject var model: NotchModel
    let record: SessionRecord
    @State private var appeared = false

    var body: some View {
        let buddy = model.buddy
        let mood = model.mood(for: record)
        let needs = record.state == .needs && mood == .alert
        VStack(spacing: 0) {
            Color.clear.frame(height: model.geometry.height)
            HStack(alignment: .center, spacing: 14) {
                BuddyView(buddy: buddy, mood: mood, tint: model.buddy.tint(for: record.id))
                    .frame(width: 52, height: 52)
                    .modifier(PeekUp(active: !appeared))
                    .onAppear {
                        // The buddy pops up out of the notch just after the panel opens.
                        if model.reduceMotion {
                            appeared = true
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.12)) { appeared = true }
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(heading(buddy, mood))
                        .font(buddy.font(15, .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if needs, let message = record.message {
                        Text(message)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.09)))
                            .padding(.top, 3)
                    } else if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !record.id.hasPrefix("peekaboo.welcome") {
                    Text(needs ? "Answer" : "Open")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(needs ? Color.needsAmber : Color.doneGreen))
                }
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)
            .padding(.bottom, 6)
        }
    }

    private func heading(_ buddy: Buddy, _ mood: Mood) -> String {
        if record.id == NotchModel.welcomeId { return "Hi, I'm \(buddy.name)!" }
        switch mood {
        case .alert: return buddy.needsHeading
        case .happy: return buddy.doneHeading
        case .working: return "Working…"
        case .idle: return record.state == .done ? "Finished" : "Waiting for you"
        }
    }

    private var subtitle: String {
        if record.id == NotchModel.welcomeId { return record.title ?? "" }
        let title = record.title ?? "Claude session"
        return "\(title) · \(record.project)"
    }

    private var detail: String? {
        if record.id == NotchModel.welcomeId { return "Hover me any time to see all sessions" }
        let app = Jumper.appName(for: record)
        switch record.state {
        case .done:
            let took = Format.duration(record.updatedAt.timeIntervalSince(record.startedAt))
            return ["Finished in \(took)", app].compactMap { $0 }.joined(separator: " · ")
        case .working:
            return ["Running for \(Format.duration(model.now.timeIntervalSince(record.startedAt)))", app].compactMap { $0 }.joined(separator: " · ")
        default:
            return app
        }
    }
}

// MARK: - List (several sessions)

private struct ListView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        let rows = Array(model.sorted.prefix(5))
        let needs = model.active.filter { $0.state == .needs }.count
        VStack(spacing: 0) {
            Color.clear.frame(height: model.geometry.height)
            HStack {
                Text("\(model.sessions.count) Claudes")
                Spacer()
                if needs > 0 {
                    Text("\(needs) need\(needs == 1 ? "s" : "") you").foregroundStyle(Color.needsAmber)
                }
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 14)
            .frame(height: 26)
            VStack(spacing: 2) {
                ForEach(rows) { r in
                    SessionRow(model: model, record: r)
                }
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
    }
}

private struct SessionRow: View {
    @ObservedObject var model: NotchModel
    let record: SessionRecord
    @State private var hover = false

    var body: some View {
        Button {
            model.open(record)
        } label: {
            HStack(spacing: 11) {
                BuddyView(buddy: model.buddy, mood: model.mood(for: record), tint: model.buddy.tint(for: record.id))
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(record.title ?? "Claude session")
                        .font(model.buddy.font(13, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text([record.project, Jumper.appName(for: record), age].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                StatePill(state: record.state, quiet: model.mood(for: record) == .idle)
            }
            .padding(.horizontal, 8)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(hover ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { hover = h }
        }
    }

    private var age: String? {
        switch record.state {
        case .working: Format.duration(model.now.timeIntervalSince(record.startedAt))
        case .done: Format.duration(record.updatedAt.timeIntervalSince(record.startedAt))
        default: nil
        }
    }
}

private struct StatePill: View {
    let state: SessionState
    let quiet: Bool

    var body: some View {
        let (label, color): (String, Color) = {
            if quiet { return ("idle", .white.opacity(0.5)) }
            switch state {
            case .needs: return ("needs you", .needsAmber)
            case .done: return ("done", .doneGreen)
            case .working: return ("working", .workBlue)
            case .waiting: return ("idle", .white.opacity(0.5))
            }
        }()
        Text(label)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

// MARK: - Small pieces

private struct Spinner: View {
    let color: Color
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spin = true }
            }
    }
}

private struct PulseDot: View {
    let color: Color
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .background(Circle().fill(color.opacity(0.35)).scaleEffect(on ? 2.2 : 1).opacity(on ? 0 : 1))
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { on = true }
            }
    }
}

enum Format {
    static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
}

// MARK: - Transitions

private struct BlurFade: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 8 : 0)
            .opacity(active ? 0 : 1)
            .scaleEffect(active ? 0.94 : 1, anchor: .top)
    }
}

private struct PeekUp: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .offset(y: active ? -18 : 0)
            .scaleEffect(active ? 0.6 : 1)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    /// Content blurs in slightly after the shape starts growing, and blurs out quickly.
    static var blurFade: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
                .animation(.spring(response: 0.38, dampingFraction: 0.85).delay(0.08)),
            removal: .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
                .animation(.easeOut(duration: 0.12))
        )
    }

}
