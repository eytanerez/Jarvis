/*
 * Jarvis home panel for the Atoll notch.
 */

import JarvisCore
import JarvisUI
import SwiftUI

struct JarvisHomeFaceView: View {
    @ObservedObject private var bridge = JarvisAssistantBridge.shared
    @ObservedObject private var model = JarvisAssistantBridge.shared.model
    @ObservedObject private var calendarManager = CalendarManager.shared

    var body: some View {
        Button {
            bridge.activateConversation()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                faceStack

                VStack(alignment: .leading, spacing: 8) {
                    header
                    Text(detailText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(detailIsAlert ? Color.red.opacity(0.96) : Color.white.opacity(0.68))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    scheduleStrip
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Talk to Jarvis")
        .animation(.smooth(duration: 0.22), value: model.phase)
        .animation(.smooth(duration: 0.22), value: calendarManager.events)
    }

    private var faceStack: some View {
        VStack(spacing: 7) {
            JarvisHomePresenceView(phase: model.phase)
                .frame(width: 84, height: 70)
                .accessibilityHidden(true)

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(model.phase.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(width: 92, height: 96)
        .layoutPriority(1)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("Jarvis")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(modelBadge)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.08), in: Capsule())
        }
    }

    @ViewBuilder
    private var scheduleStrip: some View {
        let items = scheduleItems
        if items.isEmpty {
            Text("Ask about your day, this page, or what to do next.")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.prefix(2)) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(item.tint)
                            .frame(width: 13)
                        Text(item.title)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 4)
                        Text(item.timeText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
            }
        }
    }

    private var scheduleItems: [HomeScheduleItem] {
        let now = Date()
        return calendarManager.events
            .filter { event in
                if case .reminder(let completed) = event.type, completed { return false }
                return event.end >= now || event.start >= now
            }
            .sorted { $0.start < $1.start }
            .prefix(4)
            .map(HomeScheduleItem.init(event:))
    }

    private var detailText: String {
        switch model.phase {
        case .idle:
            model.statusLine
        case .listening:
            model.lastTranscript.isEmpty ? "Listening..." : model.lastTranscript
        case .transcribing(let text):
            text
        case .thinking:
            "Thinking through that."
        case .acting(let action):
            action.isEmpty ? "Working on it." : action
        case .speaking(let answer):
            answer
        case .results(let response):
            response.answer
        case .confirming(let request):
            request.description
        case .error(let message):
            message
        }
    }

    private var detailIsAlert: Bool {
        if case .error = model.phase { return true }
        return false
    }

    private var modelBadge: String {
        model.brainReady ? model.modelBadgeText : "Local"
    }

    private var statusColor: Color {
        switch model.phase {
        case .error:
            Color.red
        case .listening, .transcribing:
            Color(red: 0.36, green: 0.85, blue: 1.0)
        case .thinking, .acting:
            Color(red: 0.72, green: 0.74, blue: 1.0)
        case .speaking:
            Color.green
        default:
            model.brainReady ? Color.green : Color.orange
        }
    }

}

private struct JarvisHomePresenceView: View {
    let phase: AssistantPhase

    @State private var animate = false

    private var accent: Color {
        switch phase {
        case .error: Color(red: 1.0, green: 0.42, blue: 0.56)
        case .confirming: Color(red: 1.0, green: 0.80, blue: 0.42)
        case .results: Color(red: 0.49, green: 1.0, blue: 0.76)
        case .thinking, .acting: Color(red: 0.62, green: 0.69, blue: 1.0)
        default: Color(red: 0.39, green: 0.89, blue: 1.0)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.028, green: 0.032, blue: 0.040))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.34), lineWidth: 1)
                )
                .shadow(color: accent.opacity(isActive ? 0.26 : 0.12), radius: isActive ? 14 : 8)

            VStack(spacing: 9) {
                HStack(spacing: 13) {
                    eye(width: leftEyeWidth, height: eyeHeight)
                    eye(width: rightEyeWidth, height: eyeHeight)
                }
                .offset(x: eyeOffset, y: -1)

                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(accent.opacity(index == 2 ? 1.0 : 0.72))
                            .frame(width: 4, height: waveformHeight(for: index))
                    }
                }
                .frame(height: 18)
            }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .padding(4)
        }
        .scaleEffect(isActive && animate ? 1.025 : 1.0)
        .animation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true), value: animate)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: phase)
        .onAppear { animate = true }
    }

    private func eye(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(accent)
            .frame(width: width, height: height)
            .shadow(color: accent.opacity(0.42), radius: 5)
    }

    private var isActive: Bool {
        switch phase {
        case .listening, .transcribing, .thinking, .acting, .speaking:
            true
        default:
            false
        }
    }

    private var eyeOffset: CGFloat {
        switch phase {
        case .thinking, .acting:
            animate ? 5 : -5
        default:
            0
        }
    }

    private var eyeHeight: CGFloat {
        switch phase {
        case .confirming:
            7
        case .error:
            4
        default:
            12
        }
    }

    private var leftEyeWidth: CGFloat {
        switch phase {
        case .listening, .transcribing:
            10
        default:
            12
        }
    }

    private var rightEyeWidth: CGFloat {
        switch phase {
        case .listening, .transcribing:
            15
        default:
            12
        }
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let base: [CGFloat] = [6, 10, 14, 10, 6]
        guard isActive else { return base[index] }
        let animated: [CGFloat] = animate ? [12, 6, 16, 8, 13] : [6, 14, 8, 15, 7]
        return animated[index]
    }
}

private struct HomeScheduleItem: Identifiable {
    let id: String
    let title: String
    let timeText: String
    let icon: String
    let tint: Color

    init(event: EventModel) {
        id = event.id
        title = event.title.isEmpty ? "Untitled" : event.title
        icon = event.type.isReminder ? "checklist" : "calendar"
        tint = event.type.isReminder ? Color(red: 1.0, green: 0.72, blue: 0.32) : Color(red: 0.42, green: 0.86, blue: 1.0)

        if event.isAllDay {
            timeText = "All day"
        } else {
            timeText = event.start.formatted(date: .omitted, time: .shortened)
        }
    }
}
