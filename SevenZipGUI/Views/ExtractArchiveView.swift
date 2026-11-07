import SwiftUI
import UniformTypeIdentifiers

/// Bereich „Extrahieren": Zielwahl, Überschreibverhalten, Passwort.
struct ExtractArchiveView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ExtractArchiveViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                archiveSection
                destinationSection
                optionsSection
                actionSection
                JobProgressView(job: vm.job)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Extrahieren")
        .onAppear {
            if let pending = appState.pendingExtract {
                vm.setArchive(pending.archive, entries: pending.entries)
                appState.pendingExtract = nil
            }
        }
    }

    private var archiveSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Archiv", systemImage: "archivebox")
                        .font(.headline)
                    Spacer()
                    Button("Wählen…") { pickArchive() }
                }
                if let url = vm.archiveURL {
                    Text(url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    if !vm.specificEntries.isEmpty {
                        Text("\(vm.specificEntries.count) ausgewählte Einträge werden extrahiert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    dropPlaceholder
                }
            }
            .padding(4)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            _ = providers.loadFileURLs { urls in
                if let first = urls.first { vm.setArchive(first) }
            }
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    private var dropPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Archiv hierher ziehen oder über „Wählen…“ auswählen")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.tertiary)
        )
    }

    private func pickArchive() {
        let panel = NSOpenPanel()
        panel.title = "Archiv auswählen"
        panel.allowedContentTypes = [.archive, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            vm.setArchive(url)
        }
    }

    private var destinationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Zielverzeichnis", systemImage: "folder")
                        .font(.headline)
                    Spacer()
                    Button("Wählen…") { pickDestination() }
                }
                Text(vm.effectiveDestination ?? "Kein Ziel gewählt")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(vm.destinationURL == nil ? .secondary : .primary)
                Toggle("Unterordner mit Archivnamen anlegen", isOn: $vm.createSubfolder)
            }
            .padding(4)
        }
    }

    private func pickDestination() {
        let panel = NSOpenPanel()
        panel.title = "Zielverzeichnis auswählen"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            vm.destinationURL = url
        }
    }

    private var optionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Optionen", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Picker("Bei vorhandenen Dateien", selection: $vm.overwrite) {
                    ForEach(OverwritePolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy)
                    }
                }
                .frame(maxWidth: 420)
                .help("Aus Sicherheitsgründen werden vorhandene Dateien standardmäßig nicht überschrieben.")

                SecureField("Passwort (falls verschlüsselt)", text: $vm.password)
                    .frame(maxWidth: 360)

                Label("Extrahierte Dateien werden niemals automatisch ausgeführt.",
                      systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button {
                vm.extract()
            } label: {
                Label("Extrahieren", systemImage: "shippingbox.and.arrow.backward")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!vm.canExtract)

            if vm.job.isRunning {
                Button(role: .cancel) {
                    vm.job.cancel()
                } label: {
                    Label("Abbrechen", systemImage: "xmark.circle")
                }
                .controlSize(.large)
            }

            if vm.job.state == .finished {
                Button {
                    vm.revealDestination()
                } label: {
                    Label("Im Finder zeigen", systemImage: "finder")
                }
            }
        }
    }
}

import AppKit
