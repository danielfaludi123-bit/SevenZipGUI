import SwiftUI
import UniformTypeIdentifiers

/// Bereich „Archiv öffnen": Inhaltstabelle, Testen, Aktualisieren,
/// Einträge löschen/umbenennen, extrahieren.
struct OpenArchiveView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var vm = OpenArchiveViewModel()
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.path)]
    @State private var showPasswordSheet = false
    @State private var passwordInput = ""
    @State private var showRenameEntry = false
    @State private var renameEntryInput = ""
    @State private var showRenameArchive = false
    @State private var renameArchiveInput = ""
    @State private var showDeleteConfirm = false
    @State private var renameError: String?

    var body: some View {
        VStack(spacing: 0) {
            if vm.archiveURL == nil {
                emptyState
            } else {
                toolbarRow
                archiveSummary
                contentTable
                JobProgressView(job: vm.job)
                    .padding([.horizontal, .bottom])
            }
        }
        .navigationTitle("Archiv öffnen")
        .onAppear {
            if let pending = appState.pendingOpenURL {
                vm.load(pending)
                appState.pendingOpenURL = nil
            }
        }
        .onChange(of: vm.needsPassword) { _, needs in
            if needs { showPasswordSheet = true }
        }
        .sheet(isPresented: $showPasswordSheet) { passwordSheet }
        .sheet(isPresented: $showRenameEntry) { renameEntrySheet }
        .sheet(isPresented: $showRenameArchive) { renameArchiveSheet }
        .confirmationDialog(
            "\(vm.selectedEntries.count) Einträge wirklich aus dem Archiv entfernen?",
            isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) { vm.deleteSelected() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: Leerzustand

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Kein Archiv geöffnet", systemImage: "archivebox")
        } description: {
            Text("Wähle ein Archiv oder ziehe es in dieses Fenster.")
        } actions: {
            Button("Archiv auswählen…") { pickArchive() }
                .buttonStyle(.borderedProminent)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            _ = providers.loadFileURLs { urls in
                if let first = urls.first { vm.load(first) }
            }
            return true
        }
    }

    private func pickArchive() {
        let panel = NSOpenPanel()
        panel.title = "Archiv auswählen"
        panel.allowedContentTypes = [.archive, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            vm.load(url)
        }
    }

    // MARK: Toolbar

    private var toolbarRow: some View {
        HStack(spacing: 12) {
            Button { pickArchive() } label: {
                Label("Anderes Archiv…", systemImage: "folder")
            }
            Button { Task { await vm.refresh() } } label: {
                Label("Neu laden", systemImage: "arrow.clockwise")
            }
            .disabled(vm.isLoading)
            Button { vm.testArchive() } label: {
                Label("Testen", systemImage: "checkmark.seal")
            }
            .disabled(vm.job.isRunning)
            Button { addFilesToArchive() } label: {
                Label("Dateien hinzufügen…", systemImage: "plus")
            }
            .disabled(vm.job.isRunning)

            Spacer()

            TextField("Suchen…", text: $vm.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
        .padding()
    }

    private func addFilesToArchive() {
        let panel = NSOpenPanel()
        panel.title = "Dateien zum Archiv hinzufügen"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            vm.addFiles(panel.urls)
        }
    }

    // MARK: Archiv-Zusammenfassung

    private var archiveSummary: some View {
        GroupBox {
            HStack(spacing: 20) {
                if let info = vm.info {
                    summaryItem("Format", info.type)
                    summaryItem("Dateien", "\(info.fileCount)")
                    summaryItem("Ordner", "\(info.folderCount)")
                    summaryItem("Größe", ByteCountFormatter.string(
                        fromByteCount: info.totalSize, countStyle: .file))
                    summaryItem("Komprimiert", ByteCountFormatter.string(
                        fromByteCount: info.packedSize, countStyle: .file))
                    if info.isEncrypted {
                        Label("Verschlüsselt", systemImage: "lock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                } else if vm.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Archiv wird analysiert…")
                        .foregroundStyle(.secondary)
                }
                if let error = vm.errorMessage, !vm.needsPassword {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                Spacer()
            }
            .padding(4)
        }
        .padding(.horizontal)
    }

    private func summaryItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
        }
    }

    // MARK: Inhaltstabelle

    private var contentTable: some View {
        Table(vm.filteredEntries, selection: $vm.selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.path) { entry in
                HStack(spacing: 6) {
                    Image(systemName: entry.isDirectory ? "folder" : "doc")
                        .foregroundStyle(entry.isDirectory ? Color.accentColor : Color.secondary)
                    Text(entry.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            TableColumn("Größe", value: \.size) { entry in
                Text(entry.formattedSize)
            }
            .width(min: 70, ideal: 90)
            TableColumn("Komprimiert", value: \.packedSize) { entry in
                Text(entry.formattedPackedSize)
            }
            .width(min: 80, ideal: 100)
            TableColumn("Ratio") { entry in
                Text(entry.formattedRatio)
            }
            .width(min: 50, ideal: 60)
            TableColumn("Geändert") { entry in
                Text(entry.formattedModified)
            }
            .width(min: 130, ideal: 160)
        }
        .onChange(of: sortOrder) { _, order in
            vm.entries.sort(using: order)
        }
        .contextMenu(forSelectionType: ArchiveEntry.ID.self) { ids in
            if !ids.isEmpty {
                Button {
                    extractSelection(ids)
                } label: {
                    Label("Auswahl extrahieren…", systemImage: "shippingbox.and.arrow.backward")
                }
                if ids.count == 1 {
                    Button {
                        if let entry = vm.selectedEntries.first {
                            renameEntryInput = entry.name
                            showRenameEntry = true
                        }
                    } label: {
                        Label("Umbenennen…", systemImage: "pencil")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Aus Archiv entfernen…", systemImage: "trash")
                }
            }
        } primaryAction: { ids in
            extractSelection(ids)
        }
        .toolbar {
            ToolbarItemGroup {
                if vm.archiveURL != nil {
                    Button {
                        extractSelection(vm.selection)
                    } label: {
                        Label("Auswahl extrahieren", systemImage: "shippingbox.and.arrow.backward")
                    }
                    .disabled(vm.selection.isEmpty)

                    Button {
                        if let url = vm.archiveURL {
                            appState.extractArchive(url)
                        }
                    } label: {
                        Label("Alles extrahieren", systemImage: "shippingbox")
                    }

                    Button {
                        renameArchiveInput = vm.archiveURL?.lastPathComponent ?? ""
                        showRenameArchive = true
                    } label: {
                        Label("Archiv umbenennen", systemImage: "pencil.line")
                    }
                }
            }
        }
    }

    private func extractSelection(_ ids: Set<ArchiveEntry.ID>) {
        guard let url = vm.archiveURL else { return }
        let entries = vm.entries.filter { ids.contains($0.id) }.map(\.path)
        appState.extractArchive(url, entries: entries)
    }

    // MARK: Sheets

    private var passwordSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Passwort erforderlich", systemImage: "lock.shield")
                .font(.headline)
            Text("Dieses Archiv ist verschlüsselt. Das Passwort wird nicht gespeichert.")
                .foregroundStyle(.secondary)
                .font(.callout)
            SecureField("Passwort", text: $passwordInput)
                .onSubmit { submitPassword() }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) {
                    passwordInput = ""
                    showPasswordSheet = false
                }
                Button("Öffnen") { submitPassword() }
                    .buttonStyle(.borderedProminent)
                    .disabled(passwordInput.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func submitPassword() {
        let pw = passwordInput
        passwordInput = ""
        showPasswordSheet = false
        Task { await vm.refresh(password: pw) }
    }

    private var renameEntrySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Eintrag umbenennen", systemImage: "pencil")
                .font(.headline)
            TextField("Neuer Name", text: $renameEntryInput)
                .onSubmit {
                    vm.renameSelected(to: renameEntryInput)
                    showRenameEntry = false
                }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { showRenameEntry = false }
                Button("Umbenennen") {
                    vm.renameSelected(to: renameEntryInput)
                    showRenameEntry = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameEntryInput.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var renameArchiveSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Archiv umbenennen", systemImage: "pencil.line")
                .font(.headline)
            Text("Benennt die Archivdatei im Dateisystem um.")
                .foregroundStyle(.secondary)
                .font(.callout)
            TextField("Neuer Dateiname", text: $renameArchiveInput)
            if let renameError {
                Label(renameError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) {
                    renameError = nil
                    showRenameArchive = false
                }
                Button("Umbenennen") {
                    do {
                        try vm.renameArchiveFile(to: renameArchiveInput)
                        renameError = nil
                        showRenameArchive = false
                    } catch {
                        renameError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameArchiveInput.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

import AppKit
