import AppKit
import Foundation
import JarvisCore
import JarvisMac
import SwiftUI

/// Version + update + install dashboard. Surfaced in the Debug window and
/// usable from Settings → About. Shows exactly what is running and warns when
/// Jarvis is launched from a development or temporary location.
public struct JarvisVersionPanel: View {
    private let runtimeStatus: RuntimeStatusReport?
    private let onCheckForUpdates: (() -> Void)?
    private let onRefresh: (() -> Void)?

    @State private var channel: UpdateChannel = UpdateChannelStore().current
    @State private var actionMessage: String?
    @State private var instances: [DuplicateInstanceDetector.Instance] = []

    private let info = AppVersionInfo.current
    private let location = InstallLocation.current
    private let channelStore = UpdateChannelStore()

    public init(
        runtimeStatus: RuntimeStatusReport? = nil,
        onCheckForUpdates: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.runtimeStatus = runtimeStatus
        self.onCheckForUpdates = onCheckForUpdates
        self.onRefresh = onRefresh
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let warning = location.warningMessage {
                warningBox(warning, accent: location.blocksUpdates ? .red : .orange) {
                    Button("Move to Applications") { moveToApplications() }
                }
            }
            if location.kind == .repoBuild || location.kind == .derivedData {
                Label("Developer Mode: unsigned/local build", systemImage: "hammer.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if instances.count > 1 {
                warningBox(
                    "\(instances.count) copies of Jarvis are running. Old builds cause version confusion.",
                    accent: .orange
                ) {
                    Button("Quit Other Instances") {
                        let quit = DuplicateInstanceDetector.quitOtherInstances()
                        actionMessage = "Quit \(quit) other instance\(quit == 1 ? "" : "s")."
                        instances = DuplicateInstanceDetector.runningInstances()
                    }
                }
            }
            versionGrid
            brainSection
            updateSection
            if let actionMessage {
                Text(actionMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onAppear { instances = DuplicateInstanceDetector.runningInstances() }
    }

    private var header: some View {
        HStack {
            Label("Version & Updates", systemImage: "shippingbox.fill")
                .font(.title3.weight(.semibold))
            Spacer()
            if let onRefresh {
                Button { onRefresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var versionGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            row("Jarvis Version", info.appVersion)
            row("Build Number", info.buildNumber)
            row("Git Commit", info.gitCommit)
            row("Brain Version", runtimeStatus?.version.brainVersion ?? info.brainVersion)
            row("Update Channel", channel.displayName)
            row("Build Date", info.buildDate.isEmpty ? "Unknown" : info.buildDate)
            row("Running Path", location.path, mono: true, accent: location.isProperlyInstalled ? nil : .orange)
        }
    }

    @ViewBuilder private var brainSection: some View {
        if let status = runtimeStatus {
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                row("Brain Mode", status.brain.brainMode, accent: status.brain.isDeveloperBrain ? .orange : nil)
                row("Brain Path", status.brain.brainPath, mono: true)
                row("Brain Commit", status.brain.brainGitCommit)
                row(
                    "App/Brain Match",
                    status.brain.matchesAppVersion.map { $0 ? "Matched" : "Mismatch" } ?? "Unknown",
                    accent: status.hasVersionMismatch ? .red : nil
                )
            }
            ForEach(status.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("Update Channel").foregroundStyle(.secondary)
                Picker("", selection: $channel) {
                    ForEach(UpdateChannel.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: channel) { _, newValue in
                    channelStore.current = newValue
                    actionMessage = "Update channel set to \(newValue.displayName). Feed: \(newValue.appcastURLString)"
                }
            }
            Text("Feed: \(channel.appcastURLString)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let onCheckForUpdates {
                Button("Check for Updates…") { onCheckForUpdates() }
            }
        }
    }

    private func warningBox(_ text: String, accent: Color, @ViewBuilder action: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.callout).foregroundStyle(accent)
            action()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, _ value: String, mono: Bool = false, accent: Color? = nil) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .body.monospaced() : .body)
                .foregroundStyle(accent ?? .primary)
                .textSelection(.enabled)
        }
    }

    private func moveToApplications() {
        do {
            try InstallLocationMover.moveToApplicationsAndRelaunch()
        } catch {
            actionMessage = "\(error)"
        }
    }
}
