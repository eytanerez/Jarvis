import SwiftUI

public struct DictationStatusView: View {
    public var status: DictationStatus

    public init(status: DictationStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.message)
                    .font(.callout.weight(.medium))
                if !status.transcript.isEmpty {
                    Text(status.transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch status.phase {
        case .idle:
            "mic"
        case .recording:
            "mic.fill"
        case .transcribing, .formatting:
            "waveform"
        case .inserting:
            "text.cursor"
        case .inserted:
            "checkmark.circle.fill"
        case .canceled:
            "xmark.circle"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status.phase {
        case .recording, .transcribing, .formatting, .inserting:
            .blue
        case .inserted:
            .green
        case .canceled:
            .secondary
        case .error:
            .orange
        case .idle:
            .secondary
        }
    }
}
