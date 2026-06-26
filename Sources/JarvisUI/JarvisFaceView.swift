import JarvisCore
import SwiftUI

enum JarvisExpression: Equatable {
    case happy        // idle, content
    case curious      // listening
    case searching    // thinking / acting — eyes sweep
    case speaking     // talking, waveform mouth
    case delighted    // results — grin + cheer
    case careful      // confirming
    case sad          // error

    static func from(_ phase: AssistantPhase) -> JarvisExpression {
        switch phase {
        case .idle: .happy
        case .listening, .transcribing: .curious
        case .thinking, .acting: .searching
        case .speaking: .speaking
        case .results: .delighted
        case .confirming: .careful
        case .error: .sad
        }
    }
}

enum JarvisPalette {
    static func accent(for phase: AssistantPhase) -> Color {
        switch phase {
        case .error: Color(red: 1.0, green: 0.42, blue: 0.56)
        case .confirming: Color(red: 1.0, green: 0.80, blue: 0.42)
        case .results: Color(red: 0.49, green: 1.0, blue: 0.76)
        case .thinking, .acting: Color(red: 0.62, green: 0.69, blue: 1.0)
        default: Color(red: 0.39, green: 0.89, blue: 1.0)
        }
    }

    static func faceFill(for phase: AssistantPhase) -> Color {
        switch phase {
        case .error: Color(red: 0.13, green: 0.035, blue: 0.052)
        case .confirming: Color(red: 0.11, green: 0.085, blue: 0.035)
        default: Color(red: 0.027, green: 0.030, blue: 0.038)
        }
    }
}

public struct JarvisFaceView: View {
    let phase: AssistantPhase

    @State private var blink = false
    @State private var breathe = false
    @State private var scan = false
    @State private var idleLook: CGFloat = 0
    @State private var wave = false

    private var expression: JarvisExpression { .from(phase) }
    private var accent: Color { JarvisPalette.accent(for: phase) }

    public init(phase: AssistantPhase) {
        self.phase = phase
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(JarvisPalette.faceFill(for: phase))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: accent.opacity(isActive ? 0.30 : 0.12), radius: isActive ? 15 : 8)
                .frame(width: 86, height: 74)
                .scaleEffect(bob)

            JarvisHands(expression: expression, accent: accent, wave: wave, lift: breathe)

            HStack(spacing: eyeSpacing) {
                JarvisEye(expression: expression, side: .left, blink: blink, accent: accent)
                JarvisEye(expression: expression, side: .right, blink: blink, accent: accent)
            }
            .offset(x: eyesOffsetX, y: -10)
            .animation(eyesAnimation, value: eyesOffsetX)

            JarvisMouth(expression: expression, accent: accent, pulse: breathe)
                .offset(y: 16)
        }
        .frame(width: 92, height: 80)
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: expression)
        .onAppear {
            breathe = true
            startBlinking()
            startIdleLookAround()
            syncReactions(to: expression)
        }
        .onChange(of: expression) { _, newValue in
            syncReactions(to: newValue)
        }
    }

    private var isActive: Bool {
        switch phase {
        case .idle, .results, .confirming, .error: false
        default: true
        }
    }

    private var bob: CGFloat {
        guard isActive else { return 1.0 }
        return breathe ? 1.035 : 1.0
    }

    private var eyeSpacing: CGFloat {
        switch expression {
        case .delighted: 16
        case .searching: 20
        default: 19
        }
    }

    private var eyesOffsetX: CGFloat {
        if expression == .searching {
            return scan ? 7 : -7
        }
        return idleLook
    }

    private var eyesAnimation: Animation {
        if expression == .searching {
            return .easeInOut(duration: 0.62).repeatForever(autoreverses: true)
        }
        return .spring(response: 0.55, dampingFraction: 0.7)
    }

    private func syncReactions(to expression: JarvisExpression) {
        scan = (expression == .searching)
        wave = (expression == .delighted)
        idleLook = 0
    }

    private func startBlinking() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.4...4.4)))
                guard expression != .sad else { continue }
                withAnimation(.easeInOut(duration: 0.07)) { blink = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.12)) { blink = false }
            }
        }
    }

    private func startIdleLookAround() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 3.0...5.5)))
                guard expression == .happy else { continue }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    idleLook = [-5, -3, 3, 5].randomElement() ?? 0
                }
                try? await Task.sleep(for: .seconds(Double.random(in: 0.8...1.4)))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { idleLook = 0 }
            }
        }
    }
}

private enum FaceSide {
    case left
    case right
}

private struct JarvisEye: View {
    let expression: JarvisExpression
    let side: FaceSide
    let blink: Bool
    let accent: Color

    var body: some View {
        Group {
            if usesArch {
                ArchEye(downward: expression == .sad)
                    .stroke(accent.opacity(expression == .sad ? 0.92 : 1.0),
                            style: StrokeStyle(lineWidth: 4.4, lineCap: .round))
                    .frame(width: 15, height: blink ? 2 : archHeight)
            } else {
                Capsule()
                    .fill(accent)
                    .frame(width: openWidth, height: blink ? 2.5 : openHeight)
                    .shadow(color: accent.opacity(0.45), radius: 6)
            }
        }
        .rotationEffect(.degrees(rotation))
        .offset(y: yOffset)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: expression)
        .animation(.easeInOut(duration: 0.08), value: blink)
    }

    private var usesArch: Bool {
        switch expression {
        case .happy, .delighted, .sad: true
        default: false
        }
    }

    private var archHeight: CGFloat {
        expression == .delighted ? 9 : 7
    }

    private var openWidth: CGFloat {
        switch expression {
        case .curious: 11
        case .careful: 11
        default: 10
        }
    }

    private var openHeight: CGFloat {
        switch expression {
        case .curious: 17
        case .careful: 9
        case .speaking: 13
        default: 15
        }
    }

    private var rotation: Double {
        switch expression {
        case .delighted: side == .left ? 16 : -16
        case .careful: side == .left ? -10 : 0
        default: 0
        }
    }

    private var yOffset: CGFloat {
        switch expression {
        case .delighted: -2
        case .sad: 4
        case .careful: 2
        default: 0
        }
    }
}

private struct ArchEye: Shape {
    let downward: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if downward {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                              control: CGPoint(x: rect.midX, y: rect.maxY + 3))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                              control: CGPoint(x: rect.midX, y: rect.minY - 3))
        }
        return path
    }
}

private struct JarvisMouth: View {
    let expression: JarvisExpression
    let accent: Color
    let pulse: Bool

    var body: some View {
        switch expression {
        case .curious:
            Circle()
                .stroke(.white.opacity(0.80), lineWidth: 2.4)
                .frame(width: pulse ? 13 : 10, height: pulse ? 13 : 10)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: pulse)
        case .speaking:
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.80))
                        .frame(width: 3.5, height: pulse ? CGFloat(7 + index * 3) : 7)
                        .animation(.easeInOut(duration: 0.30).repeatForever().delay(Double(index) * 0.06), value: pulse)
                }
            }
        case .searching:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(accent.opacity(0.82))
                        .frame(width: 4.5, height: 4.5)
                        .offset(y: pulse ? -2 : 2)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.1), value: pulse)
                }
            }
        case .careful:
            Capsule()
                .fill(.white.opacity(0.66))
                .frame(width: 14, height: 2.6)
        case .sad:
            CurvedMouth(smiling: false)
                .stroke(.white.opacity(0.74), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 22, height: 11)
        default:
            CurvedMouth(smiling: true)
                .stroke(.white.opacity(0.82), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: expression == .delighted ? 28 : 23, height: expression == .delighted ? 15 : 12)
        }
    }
}

private struct CurvedMouth: Shape {
    let smiling: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if smiling {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - 2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY - 2),
                              control: CGPoint(x: rect.midX, y: rect.maxY + 3))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 2),
                              control: CGPoint(x: rect.midX, y: rect.minY))
        }
        return path
    }
}

/// Two little paws that peek from the sides of the face and act out the mood:
/// cupped to "listen", a paw to the chin while searching, both up to cheer on a
/// result, and a friendly wave on greet/finish.
private struct JarvisHands: View {
    let expression: JarvisExpression
    let accent: Color
    let wave: Bool
    let lift: Bool

    var body: some View {
        ZStack {
            Paw(accent: accent)
                .rotationEffect(.degrees(leftRotation + (wave ? (lift ? 14 : -14) : 0)))
                .offset(x: leftX, y: leftY)
                .animation(waveAnimation, value: lift)
            Paw(accent: accent)
                .rotationEffect(.degrees(rightRotation - (wave ? (lift ? 14 : -14) : 0)))
                .offset(x: rightX, y: rightY)
                .animation(waveAnimation, value: lift)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: expression)
    }

    private var waveAnimation: Animation {
        wave ? .easeInOut(duration: 0.34).repeatForever(autoreverses: true) : .spring(response: 0.32, dampingFraction: 0.7)
    }

    // Left paw
    private var leftX: CGFloat {
        switch expression {
        case .curious: -40   // cupped near the ear
        case .delighted: -34
        default: -42
        }
    }

    private var leftY: CGFloat {
        switch expression {
        case .curious: -12
        case .delighted: -6
        case .happy: 30
        case .sad: 34
        default: 22
        }
    }

    private var leftRotation: Double {
        switch expression {
        case .curious: -28
        case .delighted: -22
        case .sad: 20
        default: -8
        }
    }

    // Right paw
    private var rightX: CGFloat {
        switch expression {
        case .searching: 16   // paw to the chin, pondering
        case .delighted: 34
        default: 42
        }
    }

    private var rightY: CGFloat {
        switch expression {
        case .searching: 14
        case .delighted: -6
        case .happy: 30
        case .sad: 34
        default: 22
        }
    }

    private var rightRotation: Double {
        switch expression {
        case .searching: 26
        case .delighted: 22
        case .sad: -20
        default: 8
        }
    }
}

private struct Paw: View {
    let accent: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(accent.opacity(0.85))
                .frame(width: 17, height: 13)
            HStack(spacing: 1.6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(accent)
                        .frame(width: 4, height: 4)
                }
            }
            .offset(y: -6)
        }
        .shadow(color: accent.opacity(0.4), radius: 4)
    }
}
