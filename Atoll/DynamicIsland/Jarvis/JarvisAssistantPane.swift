/*
 * Jarvis assistant pane for the Atoll notch shell.
 */

import JarvisCore
import JarvisUI
import SwiftUI

struct JarvisAssistantPane: View {
    @ObservedObject private var bridge = JarvisAssistantBridge.shared
    @ObservedObject private var model = JarvisAssistantBridge.shared.model

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                JarvisFaceView(phase: model.phase)
                    .frame(width: 104, height: 90)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Jarvis")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        statusPill
                    }

                    Text(detailText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(detailIsAlert ? .red.opacity(0.95) : .white.opacity(0.70))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)

                    if showActivityLines {
                        JarvisActivityLines(accent: accentColor)
                            .frame(width: 236, height: 26)
                            .transition(.opacity)
                    }
                }

                Spacer(minLength: 10)

                Button {
                    bridge.activateConversation()
                } label: {
                    Image(systemName: primaryControlIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.10), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.92))
                .help(primaryControlHelp)
                .disabled(disablePrimaryControl)
            }

            lowerContent
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.24), value: model.phase)
    }

    @ViewBuilder
    private var lowerContent: some View {
        switch model.phase {
        case .results(let response):
            if !response.results.isEmpty {
                JarvisResultStrip(response: response)
                    .frame(height: 48)
            }
        case .confirming(let request):
            JarvisConfirmationBar(model: model, request: request)
        default:
            EmptyView()
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(model.brainReady ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(model.phase.title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.08), in: Capsule())
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
            "Putting it together..."
        case .acting(let action):
            action.isEmpty ? "Working..." : action
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

    private var showActivityLines: Bool {
        switch model.phase {
        case .listening, .transcribing, .thinking, .acting, .speaking:
            true
        default:
            false
        }
    }

    private var primaryControlIcon: String {
        switch model.phase {
        case .thinking, .acting:
            "xmark"
        case .speaking:
            "arrow.uturn.left"
        default:
            "waveform"
        }
    }

    private var primaryControlHelp: String {
        switch model.phase {
        case .thinking, .acting:
            "Cancel"
        case .speaking:
            "Reply"
        default:
            "Talk"
        }
    }

    private var disablePrimaryControl: Bool {
        if case .confirming = model.phase { return true }
        return false
    }

    private var accentColor: Color {
        switch model.phase {
        case .error:
            Color(red: 1.0, green: 0.42, blue: 0.56)
        case .confirming:
            Color(red: 1.0, green: 0.80, blue: 0.42)
        case .results:
            Color(red: 0.49, green: 1.0, blue: 0.76)
        case .thinking, .acting:
            Color(red: 0.62, green: 0.69, blue: 1.0)
        default:
            Color(red: 0.39, green: 0.89, blue: 1.0)
        }
    }
}

private struct JarvisActivityLines: View {
    let accent: Color
    @State private var animate = false
    private let widths: [CGFloat] = [230, 174, 118]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.14))
                    .frame(width: widths[index], height: 5)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, accent.opacity(0.95), .white.opacity(0.82), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 52, height: 5)
                            .offset(x: animate ? widths[index] + 56 : -56)
                    }
                    .clipShape(Capsule())
            }
        }
        .onAppear { animate = true }
        .animation(.linear(duration: 1.05).repeatForever(autoreverses: false), value: animate)
    }
}

private struct JarvisResultStrip: View {
    let response: StructuredResponse

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(response.results.prefix(5)) { result in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.rank.map { "\($0). \(result.name)" } ?? result.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.90))
                            .lineLimit(1)
                        Text(result.reason ?? result.url?.host ?? "")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.50))
                            .lineLimit(1)
                    }
                    .frame(width: 132, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct JarvisConfirmationBar: View {
    @ObservedObject var model: JarvisAppModel
    let request: ConfirmationRequest
    @State private var typed = ""

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(request.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)
                Text(request.requiresTypedConfirmation ? "Type confirm to continue." : request.description)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if request.requiresTypedConfirmation {
                TextField("confirm", text: $typed)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(width: 92)
            }

            Button {
                model.cancelConfirmation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.62))
            .help("Cancel")

            Button {
                model.confirm(request)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.94))
            .disabled(request.requiresTypedConfirmation && typed.lowercased() != "confirm")
            .keyboardShortcut(.defaultAction)
            .help("Confirm")
        }
        .padding(.horizontal, 4)
    }
}
