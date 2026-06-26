import AppKit
import JarvisMac
import JarvisUI
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background "agent" app, like AltTab: no Dock icon, no app-switcher
        // entry, never shows as a foreground window owner.
        NSApp.setActivationPolicy(.accessory)
        LoginItemManager().enableOnFirstRunIfNeeded()
        JarvisAppModel.shared.start()
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        JarvisAppModel.shared.shutdown()
    }
}

@main
struct JarvisNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = JarvisAppModel.shared

    var body: some Scene {
        MenuBarExtra {
            JarvisMenuView(model: model)
        } label: {
            Image(nsImage: JarvisMenuBarIcon.image)
        }

        Window("Jarvis Debug", id: "debug") {
            DebugView(model: model)
        }
        .defaultSize(width: 680, height: 460)

        Settings {
            JarvisSettingsView(model: model)
        }
    }
}
