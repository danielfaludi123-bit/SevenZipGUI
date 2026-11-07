import SwiftUI

@main
struct SevenZipGUIApp: App {

    @StateObject private var appState = AppState()
    @StateObject private var service = SevenZipService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(service)
                .frame(minWidth: 780, minHeight: 520)
        }
        .defaultSize(width: 1020, height: 660)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .sidebar) {
                ForEach(AppSection.allCases) { section in
                    Button(section.title) {
                        appState.selectedSection = section
                    }
                    .keyboardShortcut(section.keyboardShortcut, modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(service)
                .frame(width: 520, height: 320)
        }
    }
}
