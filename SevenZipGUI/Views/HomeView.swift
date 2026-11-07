import SwiftUI
import UniformTypeIdentifiers

/// Home: Übersicht, Schnellaktionen und Drop-Zone.
struct HomeView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var service: SevenZipService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                quickActions
                statusCard
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("SevenZipGUI", systemImage: "archivebox.fill")
                .font(.largeTitle.bold())
            Text("Native macOS-Oberfläche für das offizielle 7-Zip CLI")
                .foregroundStyle(.secondary)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schnellaktionen")
                .font(.headline)
            HStack(spacing: 16) {
                QuickActionCard(
                    title: "Archiv erstellen",
                    subtitle: "Dateien komprimieren",
                    symbol: "plus.square.on.square",
                    dropHint: "Dateien hier ablegen"
                ) {
                    appState.selectedSection = .create
                } onDrop: { urls in
                    appState.createWith(files: urls)
                }

                QuickActionCard(
                    title: "Archiv öffnen",
                    subtitle: "Inhalt anzeigen & verwalten",
                    symbol: "archivebox",
                    dropHint: "Archiv hier ablegen"
                ) {
                    pickArchive { url in appState.openArchive(url) }
                } onDrop: { urls in
                    if let first = urls.first { appState.openArchive(first) }
                }

                QuickActionCard(
                    title: "Extrahieren",
                    subtitle: "Archive entpacken",
                    symbol: "shippingbox.and.arrow.backward",
                    dropHint: "Archiv hier ablegen"
                ) {
                    pickArchive { url in appState.extractArchive(url) }
                } onDrop: { urls in
                    if let first = urls.first { appState.extractArchive(first) }
                }
            }
        }
    }

    private var statusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("7-Zip-Backend", systemImage: "terminal")
                    .font(.headline)
                if let path = service.executablePath {
                    LabeledContent("7zz-Pfad", value: path)
                    LabeledContent("Version", value: service.detectedVersion ?? "unbekannt")
                    Label("Bereit", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("7zz wurde nicht gefunden. Installiere es mit „brew install sevenzip“.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .padding(4)
        }
    }

    private func pickArchive(_ completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Archiv auswählen"
        panel.allowedContentTypes = [.archive, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }
}

/// Karte für Schnellaktionen mit Drag & Drop.
struct QuickActionCard: View {

    let title: String
    let subtitle: String
    let symbol: String
    let dropHint: String
    let action: () -> Void
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dropHint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                                  style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [6]))
            )
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            _ = providers.loadFileURLs { urls in
                onDrop(urls)
            }
            return true
        }
    }
}

import AppKit

/// Lädt file URLs aus Drop-Providern.
extension Array where Element == NSItemProvider {
    @discardableResult
    func loadFileURLs(completion: @escaping @MainActor @Sendable ([URL]) -> Void) -> Int {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in self where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            Task { @MainActor in completion(urls) }
        }
        return self.count
    }
}
