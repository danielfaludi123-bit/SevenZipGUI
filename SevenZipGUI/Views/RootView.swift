import SwiftUI

/// Hauptfenster: native macOS-Navigation mit Sidebar.
struct RootView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var service: SevenZipService

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $appState.selectedSection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch appState.selectedSection {
                case .home:
                    HomeView()
                case .create:
                    CreateArchiveView()
                case .open:
                    OpenArchiveView()
                case .extract:
                    ExtractArchiveView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("SevenZipGUI")
        .onOpenURL { url in
            // Doppelklick auf ein Archiv im Finder → Bereich „Öffnen"
            appState.openArchive(url)
        }
        .overlay(alignment: .bottom) {
            if service.executablePath == nil {
                ContentUnavailableView(
                    "7zz nicht gefunden",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Installiere 7-Zip mit „brew install sevenzip“ oder setze den Pfad in den Einstellungen.")
                )
                .background(.regularMaterial)
            }
        }
    }
}
