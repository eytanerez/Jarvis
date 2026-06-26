import JarvisCore
import SwiftUI

public struct NotchRootView: View {
    @ObservedObject var model: JarvisAppModel
    private let onHeight: (CGFloat) -> Void

    public init(model: JarvisAppModel, onHeight: @escaping (CGFloat) -> Void = { _ in }) {
        self.model = model
        self.onHeight = onHeight
    }

    public var body: some View {
        VStack(spacing: 10) {
            Text(model.modelBadgeText)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(.white.opacity(0.07), in: Capsule())

            JarvisFaceView(phase: model.phase)
                .frame(width: 92, height: 80)

            if showLoader {
                ThreeLineLoader(phase: model.phase, accent: accentColor)
                    .frame(width: 248)
                    .transition(.opacity)
            }

            if !detailText.isEmpty {
                Text(detailText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(detailTextIsAlert ? 0.90 : 0.62))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 352)
                    .textSelection(.enabled)
            }

            lowerContent

            if let controlIcon {
                Button {
                    model.toggleFromHotkey()
                } label: {
                    Label(controlHelp, systemImage: controlIcon)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.10), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(controlHelp)
            }
        }
        .padding(.top, 38)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(width: 420)
        .background(notchBackground)
        .background(heightReader)
        .foregroundStyle(.white)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: model.phase)
    }

    private var notchBackground: some View {
        AtollNotchShape(topCornerRadius: 6, bottomCornerRadius: 30)
            .fill(Color.black)
            .overlay(
                AtollNotchShape(topCornerRadius: 6, bottomCornerRadius: 30)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.56), radius: 22, y: 12)
    }

    private var heightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: NotchHeightKey.self, value: proxy.size.height)
        }
        .onPreferenceChange(NotchHeightKey.self) { height in
            onHeight(height)
        }
    }

    @ViewBuilder
    private var lowerContent: some View {
        switch model.phase {
        case .results(let response):
            if !response.results.isEmpty {
                ResultStripView(response: response)
                    .frame(height: 40)
            }
        case .confirming(let request):
            ConfirmationStripView(model: model, request: request)
        default:
            EmptyView()
        }
    }

    private var showLoader: Bool {
        switch model.phase {
        case .listening, .transcribing, .thinking, .acting, .speaking:
            true
        default:
            false
        }
    }

    private var detailText: String {
        switch model.phase {
        case .idle:
            model.statusLine
        case .listening:
            model.lastTranscript.isEmpty ? "Listening…" : model.lastTranscript
        case .transcribing(let text):
            text
        case .thinking:
            "Putting it together…"
        case .acting(let action):
            action.isEmpty ? "Working…" : action
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

    private var detailTextIsAlert: Bool {
        if case .error = model.phase { return true }
        return false
    }

    private var controlIcon: String? {
        switch model.phase {
        case .listening, .transcribing, .confirming:
            nil
        case .speaking:
            "arrow.uturn.left"
        case .thinking, .acting:
            "xmark"
        default:
            "waveform"
        }
    }

    private var controlHelp: String {
        switch model.phase {
        case .speaking:
            "Reply"
        case .thinking, .acting:
            "Cancel"
        default:
            "Talk"
        }
    }

    private var accentColor: Color {
        JarvisPalette.accent(for: model.phase)
    }
}

private struct NotchHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ThreeLineLoader: View {
    let phase: AssistantPhase
    let accent: Color
    @State private var animate = false

    private let widths: [CGFloat] = [224, 176, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                line(index: index, width: widths[index])
            }
        }
        .frame(height: 34, alignment: .center)
        .onAppear { animate = true }
    }

    private func line(index: Int, width: CGFloat) -> some View {
        Capsule()
            .fill(.white.opacity(baseOpacity(index)))
            .frame(width: width, height: 6)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, accent.opacity(0.95), .white.opacity(0.82), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 54, height: 6)
                    .offset(x: animate ? width + 64 : -64)
                    .opacity(isAnimating ? 1 : 0)
            }
            .clipShape(Capsule())
            .animation(
                isAnimating
                    ? .linear(duration: 1.05).repeatForever(autoreverses: false).delay(Double(index) * 0.10)
                    : .easeOut(duration: 0.16),
                value: animate
            )
    }

    private var isAnimating: Bool {
        switch phase {
        case .listening, .transcribing, .thinking, .acting, .speaking:
            true
        default:
            false
        }
    }

    private func baseOpacity(_ index: Int) -> Double {
        let base = isAnimating ? 0.16 : 0.10
        return base + Double(2 - index) * 0.025
    }
}

private struct ResultStripView: View {
    let response: StructuredResponse

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(response.results.prefix(5)) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(result.rank ?? 0). \(result.name)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.90))
                            .lineLimit(1)
                        Text(result.reason ?? result.url?.host ?? "")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }
                    .frame(width: 116, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct ConfirmationStripView: View {
    @ObservedObject var model: JarvisAppModel
    let request: ConfirmationRequest
    @State private var typed = ""

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                Text(request.requiresTypedConfirmation ? "Type confirm to continue." : request.description)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if request.requiresTypedConfirmation {
                TextField("confirm", text: $typed)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(width: 86)
            }
            Button {
                model.cancelConfirmation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.58))
            .help("Cancel")

            Button {
                model.confirm(request)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.92))
            .background(.white.opacity(0.12), in: Circle())
            .disabled(request.requiresTypedConfirmation && typed.lowercased() != "confirm")
            .keyboardShortcut(.defaultAction)
            .help("Confirm")
        }
        .padding(.horizontal, 2)
    }
}
