import FlockerwhisperCore
import SwiftUI

struct OverlayHUDView: View {
    let controller: AppController

    @State private var isHoveringCollapse = false

    var body: some View {
        Group {
            if controller.isCompactHUD {
                compactHUD
            } else {
                standardHUD
            }
        }
        .padding(24) // Room for floating shadow inside transparent NSPanel
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: controller.isCompactHUD)
        .animation(.easeInOut(duration: 0.16), value: controller.phase)
    }

    // MARK: - Standard HUD (matches design reference)

    private var standardHUD: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Upper display area: live waveform dots, progress bar, copied state, or error
                upperContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 12)

                // Recessed bottom control pill
                bottomControlBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }

            // Top-right collapse icon
            Button {
                controller.toggleCompactHUD()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(isHoveringCollapse ? 0.78 : 0.34))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHoveringCollapse = $0 }
            .help("Compact view")
            .padding(.top, 10)
            .padding(.trailing, 12)
        }
        .frame(width: 560, height: 172)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 23 / 255, green: 23 / 255, blue: 24 / 255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 22, x: 0, y: 12)
    }

    // MARK: - Compact Pill Mode

    private var compactHUD: some View {
        HStack(spacing: 12) {
            leadingStatusIcon

            switch controller.phase {
            case .recording:
                WaveformDotsView(levels: Array(controller.waveformLevels.suffix(24)), maxHeight: 24)
                    .frame(width: 150)
            case .downloadingModel(let progress, _), .transcribing(let progress, _):
                progressTrack(progress: progress)
                    .frame(width: 150)
            case .copied:
                Text("Copied to clipboard")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 150, alignment: .leading)
            case .error(let message, _):
                Text(message)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            case .hidden:
                EmptyView()
            }

            if controller.phase.isRecording {
                Button {
                    controller.stopAndTranscribe()
                } label: {
                    HStack(spacing: 5) {
                        KeycapView(label: "⌥")
                        KeycapView(label: "Space")
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                controller.cancelCurrentSession()
            } label: {
                KeycapView(label: "esc")
            }
            .buttonStyle(.plain)

            Button {
                controller.toggleCompactHUD()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Expand view")
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 20 / 255, green: 20 / 255, blue: 21 / 255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 18, x: 0, y: 10)
    }

    // MARK: - Upper Content States

    @ViewBuilder
    private var upperContent: some View {
        switch controller.phase {
        case .recording:
            WaveformDotsView(levels: controller.waveformLevels, maxHeight: 46)

        case .downloadingModel(let progress, let statusText),
             .transcribing(let progress, let statusText):
            VStack(spacing: 12) {
                HStack {
                    Text(statusText)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.76))
                    Spacer()
                    Text("\(Int((max(0, min(1, progress)) * 100).rounded()))%")
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.56))
                }

                progressTrack(progress: progress)
            }

        case .copied(let preview):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.32, green: 0.85, blue: 0.52))
                    Text("Copied to clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Spacer()
                }

                if !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                progressTrack(progress: 1.0, tint: Color(red: 0.32, green: 0.85, blue: 0.52))
            }

        case .error(let message, let showMicrophoneSettings):
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.orange.opacity(0.9))

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showMicrophoneSettings {
                    Button("Open Settings") {
                        controller.openMicrophonePrivacySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

        case .hidden:
            EmptyView()
        }
    }

    private func progressTrack(progress: Double, tint: Color = .white) -> some View {
        let clamped = max(0.03, min(1.0, progress))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.11))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.75), tint.opacity(0.98)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(12, geo.size.width * clamped))
                    .animation(.easeOut(duration: 0.18), value: clamped)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Bottom Recessed Pill Bar

    private var bottomControlBar: some View {
        HStack(spacing: 12) {
            // Left: Microphone icon + "Voice to text"
            HStack(spacing: 10) {
                leadingStatusIcon

                Text(statusTitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            Spacer()

            // Right: Action hints with macOS keycaps
            HStack(spacing: 14) {
                if controller.phase.isRecording {
                    Button {
                        controller.stopAndTranscribe()
                    } label: {
                        HStack(spacing: 7) {
                            Text("Stop")
                                .font(.system(size: 14.5, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.56))
                            KeycapView(label: "⌥")
                            KeycapView(label: "Space")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    controller.cancelCurrentSession()
                } label: {
                    HStack(spacing: 7) {
                        Text(cancelTitle)
                            .font(.system(size: 14.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.56))
                        KeycapView(label: "esc")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 15 / 255, green: 15 / 255, blue: 16 / 255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.75)
        )
    }

    @ViewBuilder
    private var leadingStatusIcon: some View {
        switch controller.phase {
        case .recording:
            Image(systemName: "mic")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.54))
        case .downloadingModel, .transcribing:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
                .tint(.white.opacity(0.7))
        case .copied:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.32, green: 0.85, blue: 0.52))
        case .error:
            Image(systemName: "mic.slash")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.orange.opacity(0.85))
        case .hidden:
            Image(systemName: "mic")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.54))
        }
    }

    private var statusTitle: String {
        switch controller.phase {
        case .recording:
            return "Voice to text"
        case .downloadingModel:
            return "Downloading model"
        case .transcribing:
            return "Converting speech"
        case .copied:
            return "Voice to text"
        case .error:
            return "Voice to text"
        case .hidden:
            return "Voice to text"
        }
    }

    private var cancelTitle: String {
        if case .error = controller.phase {
            return "Close"
        }
        return "Cancel"
    }
}
