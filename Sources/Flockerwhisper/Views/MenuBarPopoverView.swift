import FlockerwhisperCore
import SwiftUI

struct MenuBarPopoverView: View {
    let controller: AppController

    @State private var searchQuery = ""
    @State private var copiedItemID: UUID?
    @State private var hoveredItemID: UUID?
    @Environment(\.dismiss) private var dismiss

    private var filteredItems: [TranscriptItem] {
        controller.transcriptStore.filtered(query: searchQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            searchSection
            historyListSection
            Divider()
            footerSection
        }
        .frame(width: 370, height: 470)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Flockerwhisper")
                    .font(.system(size: 14.5, weight: .semibold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 7, height: 7)
                    Text(controller.modelStatus.shortLabel)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    controller.toggleFromHotKey()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: controller.phase.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 11.5))
                    Text(controller.phase.isRecording ? "Stop" : "Dictate")
                        .font(.system(size: 12, weight: .medium))
                    Text("⌥Space")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var statusDotColor: Color {
        switch controller.modelStatus {
        case .ready:
            return .green
        case .downloading, .loading:
            return .orange
        case .failed:
            return .red
        case .idle:
            return .secondary
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("Search past transcripts…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Transcript History List

    @ViewBuilder
    private var historyListSection: some View {
        if filteredItems.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: searchQuery.isEmpty ? "waveform" : "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.7))

                Text(searchQuery.isEmpty ? "No transcripts yet" : "No matching transcripts")
                    .font(.system(size: 13.5, weight: .medium))

                Text(
                    searchQuery.isEmpty
                        ? "Press ⌥ Space anywhere to dictate.\nYour text is copied to the clipboard automatically."
                        : "Try a different search term."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredItems) { item in
                        transcriptRow(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private func transcriptRow(_ item: TranscriptItem) -> some View {
        let isCopied = copiedItemID == item.id
        let isHovered = hoveredItemID == item.id

        return VStack(alignment: .leading, spacing: 8) {
            Text(item.text)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.disabled)

            HStack(spacing: 8) {
                Text(Self.relativeTimestamp(for: item.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))

                Text(String(format: "%.1fs", item.durationSeconds))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                if isHovered {
                    Button {
                        controller.transcriptStore.delete(id: item.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete transcript")
                }

                Button {
                    copyItem(item)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(isCopied ? Color.green : Color.primary.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isCopied ? Color.green.opacity(0.16) : Color.primary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.08 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.12 : 0.05), lineWidth: 0.75)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            copyItem(item)
        }
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : (hoveredItemID == item.id ? nil : hoveredItemID)
        }
    }

    private func copyItem(_ item: TranscriptItem) {
        controller.transcriptStore.copyToClipboard(item.text)
        copiedItemID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if copiedItemID == item.id {
                copiedItemID = nil
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 10) {
            Menu {
                Section("Local Whisper Model") {
                    ForEach(WhisperModelOption.allCases) { option in
                        Button {
                            controller.selectModel(option)
                        } label: {
                            HStack {
                                Text("\(option.displayName)")
                                if controller.selectedModel == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                Toggle("Launch at Login", isOn: Binding(
                    get: { controller.launchAtLogin },
                    set: { controller.setLaunchAtLogin($0) }
                ))

                if !controller.transcriptStore.items.isEmpty {
                    Divider()
                    Button("Clear History", role: .destructive) {
                        controller.transcriptStore.clearAll()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11.5))
                    Text(controller.selectedModel.displayName)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static func relativeTimestamp(for date: Date) -> String {
        let delta = Date().timeIntervalSince(date)
        if delta < 45 {
            return "Just now"
        }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
