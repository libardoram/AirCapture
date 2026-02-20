import SwiftUI

@main
struct AirCaptureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About AirCapture") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "AirPlay Screen Mirroring Receiver & Recording Application",
                                attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11)]
                            ),
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0.0"
                        ]
                    )
                }
            }
            
            CommandGroup(after: .appInfo) {
                Button("Licenses...") {
                    openAboutWindow()
                }
                .keyboardShortcut("l", modifiers: [.command])
            }
            
            CommandGroup(replacing: .help) {
                Button("AirCapture Help") {
                    openHelpWindow(document: .userGuide)
                }
                .keyboardShortcut("?", modifiers: [.command])
                
                Divider()
                
                Button("Quick Start Guide") {
                    openHelpWindow(document: .quickStart)
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
                
                Button("User Guide") {
                    openHelpWindow(document: .userGuide)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                
                Button("Settings Reference") {
                    openHelpWindow(document: .settingsReference)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("About AirCapture") {
                    openHelpWindow(document: .readme)
                }
            }
        }
    }
    
    private func openAboutWindow() {
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.center()
        aboutWindow.title = "About AirCapture"
        aboutWindow.contentView = NSHostingView(rootView: AboutView())
        aboutWindow.makeKeyAndOrderFront(nil)
        aboutWindow.isReleasedWhenClosed = false
    }
    
    private func openHelpWindow(document: HelpDocument) {
        let helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        helpWindow.center()
        helpWindow.title = "AirCapture Help"
        helpWindow.contentView = NSHostingView(rootView: HelpView(document: document))
        helpWindow.makeKeyAndOrderFront(nil)
        helpWindow.isReleasedWhenClosed = false
        helpWindow.minSize = NSSize(width: 700, height: 500)
    }
}
