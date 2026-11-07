import SwiftUI

/// Einstellungen: 7zz-Pfad, Standardwerte, Verhalten.
struct SettingsView: View {

    @EnvironmentObject var service: SevenZipService

    @AppStorage("customSevenZipPath") private var customPath: String = ""
    @AppStorage("defaultFormat") private var defaultFormat: String = ArchiveFormat.sevenZ.rawValue
    @AppStorage("defaultCompressionLevel") private var defaultLevel: Int = 5
    @AppStorage("showVerboseLogByDefault") private var showVerboseLog: Bool = false

    @State private var pathTestResult: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Erkannter Pfad") {
                    Text(service.executablePath ?? "Nicht gefunden")
                        .foregroundStyle(service.executablePath == nil ? .red : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                LabeledContent("Version") {
                    Text(service.detectedVersion ?? "—")
                }
                HStack {
                    TextField("Eigener 7zz-Pfad (optional)", text: $customPath)
                    Button("Prüfen…") { testCustomPath() }
                }
                if let pathTestResult {
                    Text(pathTestResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Erneut suchen") {
                        service.refresh()
                    }
                    Button("Homebrew: sevenzip installieren…") {
                        if let url = URL(string: "https://formulae.brew.sh/formula/sevenzip") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } header: {
                Label("7-Zip-Backend", systemImage: "terminal")
            } footer: {
                Text("Gesucht wird in /opt/homebrew/bin, /usr/local/bin (Intel) und im PATH — auch wenn Homebrew nicht im GUI-PATH liegt.")
            }

            Section {
                Picker("Standardformat", selection: $defaultFormat) {
                    ForEach(ArchiveFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }
                Picker("Standard-Kompressionsstufe", selection: $defaultLevel) {
                    ForEach(0...9, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
                Toggle("CLI-Ausgabe standardmäßig anzeigen", isOn: $showVerboseLog)
            } header: {
                Label("Standards", systemImage: "slider.horizontal.3")
            }

            Section {
                LabeledContent("Netzwerk", value: "Keine Verbindungen, keine Telemetrie")
                LabeledContent("Passwörter", value: "Werden niemals gespeichert")
            } header: {
                Label("Datenschutz & Sicherheit", systemImage: "lock.shield")
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Einstellungen")
        .onChange(of: customPath) { _, _ in
            service.refresh()
        }
    }

    private func testCustomPath() {
        guard !customPath.isEmpty else {
            pathTestResult = nil
            return
        }
        if let version = SevenZipLocator.version(of: customPath) {
            pathTestResult = "OK — 7-Zip Version \(version) gefunden."
        } else {
            pathTestResult = "Der Pfad ist nicht ausführbar oder kein 7zz-Binary."
        }
    }
}

import AppKit
