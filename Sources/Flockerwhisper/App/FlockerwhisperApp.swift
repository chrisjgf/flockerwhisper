import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure Flockerwhisper runs strictly as a menu bar utility (no Dock icon).
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct FlockerwhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView(controller: controller)
        } label: {
            Image(systemName: controller.menuBarIconName)
                .symbolRenderingMode(.monochrome)
                .help("Flockerwhisper — Press ⌥ Space to dictate")
        }
        .menuBarExtraStyle(.window)
    }
}
