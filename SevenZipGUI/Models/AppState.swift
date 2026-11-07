import SwiftUI

/// Bereiche der App (Sidebar).
enum AppSection: String, CaseIterable, Identifiable {
    case home, create, open, extract, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .create: return "Archiv erstellen"
        case .open: return "Archiv öffnen"
        case .extract: return "Extrahieren"
        case .settings: return "Einstellungen"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .create: return "plus.square.on.square"
        case .open: return "archivebox"
        case .extract: return "shippingbox.and.arrow.backward"
        case .settings: return "gear"
        }
    }

    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .home: return "1"
        case .create: return "2"
        case .open: return "3"
        case .extract: return "4"
        case .settings: return ","
        }
    }
}

/// App-weiter Zustand: Navigation + Übergabe von Archiven zwischen Bereichen.
@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: AppSection = .home

    /// Archiv, das im Bereich „Öffnen" geladen werden soll (z. B. per onOpenURL aus dem Finder).
    @Published var pendingOpenURL: URL?

    /// Archiv + Dateien, die direkt zum Extrahieren übergeben werden.
    @Published var pendingExtract: (archive: URL, entries: [String])?

    /// Dateien, die zum Bereich „Erstellen" übergeben werden (Drag & Drop auf Home).
    @Published var pendingCreateFiles: [URL]?

    func openArchive(_ url: URL) {
        pendingOpenURL = url
        selectedSection = .open
    }

    func extractArchive(_ url: URL, entries: [String] = []) {
        pendingExtract = (url, entries)
        selectedSection = .extract
    }

    func createWith(files: [URL]) {
        pendingCreateFiles = files
        selectedSection = .create
    }
}
