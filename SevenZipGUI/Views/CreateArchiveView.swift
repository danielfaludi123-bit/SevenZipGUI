import SwiftUI
import UniformTypeIdentifiers

/// Bereich „Archiv erstellen": vollständige 7zz-Konfiguration.
struct CreateArchiveView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var vm = CreateArchiveViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                fileSection
                formatSection
                compressionSection
                encryptionSection
                volumeSection
                destinationSection
                actionSection
                JobProgressView(job: vm.job)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Archiv erstellen")
        .onAppear {
            if let pending = appState.pendingCreateFiles {
                vm.addFiles(pending)
                appState.pendingCreateFiles = nil
            }
        }
    }

    // MARK: Dateien

    private var fileSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Dateien & Ordner", systemImage: "doc.on.doc")
                        .font(.headline)
                    Spacer()
                    Button("Hinzufügen…") { pickFiles() }
                }

                if vm.files.isEmpty {
                    dropPlaceholder
                } else {
                    List {
                        ForEach(vm.files, id: \.self) { url in
                            HStack {
                                Image(systemName: url.hasDirectoryPath ? "folder" : "doc")
                                Text(url.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(role: .destructive) {
                                    vm.removeFile(url)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .frame(minHeight: 100, maxHeight: 180)
                }
            }
            .padding(4)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            _ = providers.loadFileURLs { urls in vm.addFiles(urls) }
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
            Image(systemName: "arrow.down.doc")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Dateien hierher ziehen oder über „Hinzufügen…“ auswählen")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.tertiary)
        )
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.title = "Dateien auswählen"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            vm.addFiles(panel.urls)
        }
    }

    // MARK: Format

    private var formatSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Archivformat", systemImage: "doc.zipper")
                    .font(.headline)
                Picker("Format", selection: Binding(
                    get: { vm.options.format },
                    set: { vm.selectFormat($0) }
                )) {
                    ForEach(ArchiveFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(4)
        }
    }

    // MARK: Kompression

    private var compressionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Kompression", systemImage: "slider.horizontal.3")
                    .font(.headline)

                if vm.options.format.supportsCompressionLevel {
                    HStack {
                        Text("Kompressionsstufe")
                        Slider(value: Binding(
                            get: { Double(vm.options.compressionLevel) },
                            set: { vm.options.compressionLevel = Int($0) }
                        ), in: 0...9, step: 1)
                        Text("\(vm.options.compressionLevel) (\(levelName(vm.options.compressionLevel)))")
                            .monospacedDigit()
                            .frame(width: 110, alignment: .trailing)
                    }
                } else {
                    Text("TAR speichert ohne Kompression.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                if !vm.options.format.methods.isEmpty {
                    Picker("Methode", selection: Binding(
                        get: { vm.options.method ?? vm.options.format.defaultMethod ?? "" },
                        set: { vm.options.method = $0 }
                    )) {
                        ForEach(vm.options.format.methods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .frame(maxWidth: 320)
                }

                if vm.options.format.supportsDictionary,
                   vm.options.method == "LZMA" || vm.options.method == "LZMA2" {
                    Picker("Wörterbuchgröße", selection: $vm.options.dictionarySize) {
                        ForEach(ArchiveFormat.dictionarySizes, id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .frame(maxWidth: 320)
                }

                if vm.options.format.supportsSolid {
                    Toggle("Solid Compression (bessere Ratio bei vielen kleinen Dateien)",
                           isOn: $vm.options.solid)
                }

                if vm.options.format.supportsMultithreading {
                    Toggle("Multithreading verwenden", isOn: $vm.options.multithreading)
                }
            }
            .padding(4)
        }
    }

    private func levelName(_ level: Int) -> String {
        switch level {
        case 0: return "Speichern"
        case 1...2: return "Schnell"
        case 3...4: return "Normal-"
        case 5: return "Normal"
        case 6...7: return "Hoch"
        default: return "Ultra"
        }
    }

    // MARK: Verschlüsselung

    private var encryptionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Verschlüsselung", systemImage: "lock.shield")
                    .font(.headline)

                if vm.options.format.supportsEncryption {
                    SecureField("Passwort (leer = keine Verschlüsselung)", text: $vm.password)
                        .frame(maxWidth: 360)
                    if !vm.password.isEmpty {
                        SecureField("Passwort bestätigen", text: $vm.passwordConfirm)
                            .frame(maxWidth: 360)
                        if !vm.passwordsMatch {
                            Label("Die Passwörter stimmen nicht überein.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.callout)
                        }
                        Text(vm.options.format == .zip
                             ? "AES-256-Verschlüsselung (ZIP)."
                             : "AES-256-Verschlüsselung.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if vm.options.format.supportsHeaderEncryption && !vm.password.isEmpty {
                        Toggle("Dateinamen verschlüsseln (-mhe=on)",
                               isOn: $vm.options.encryptHeaders)
                    }
                } else {
                    Text("\(vm.options.format.displayName) unterstützt keine Verschlüsselung.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .padding(4)
        }
    }

    // MARK: Volumes

    private var volumeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Archiv aufteilen", systemImage: "square.split.2x1")
                    .font(.headline)
                HStack {
                    Text("Teilgröße (leer = nicht aufteilen)")
                        .foregroundStyle(.secondary)
                    TextField("z. B. 100", text: $vm.volumeValue)
                        .frame(width: 80)
                    Picker("", selection: $vm.volumeUnit) {
                        Text("MB").tag("MB")
                        Text("GB").tag("GB")
                        Text("KB").tag("KB")
                    }
                    .labelsHidden()
                    .frame(width: 80)
                    if !vm.isVolumeValid {
                        Label("Nur ganze Zahlen", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: Ziel

    private var destinationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Zieldatei", systemImage: "externaldrive")
                    .font(.headline)
                HStack {
                    Text(vm.destinationArchive?.path ?? "Kein Ziel gewählt")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(vm.destinationArchive == nil ? .secondary : .primary)
                    Spacer()
                    Button("Wählen…") { pickDestination() }
                }
            }
            .padding(4)
        }
    }

    private func pickDestination() {
        let panel = NSSavePanel()
        panel.title = "Archiv speichern unter"
        panel.allowedContentTypes = [.archive, .data]
        panel.nameFieldStringValue = vm.destinationArchive?.lastPathComponent
            ?? "Archiv.\(vm.options.format.fileExtension)"
        panel.directoryURL = vm.destinationArchive?.deletingLastPathComponent()
        if panel.runModal() == .OK {
            vm.destinationArchive = panel.url
        }
    }

    // MARK: Aktion

    private var actionSection: some View {
        HStack {
            Button {
                vm.create()
            } label: {
                Label("Archiv erstellen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!vm.canCreate)

            if vm.job.isRunning {
                Button(role: .cancel) {
                    vm.job.cancel()
                } label: {
                    Label("Abbrechen", systemImage: "xmark.circle")
                }
                .controlSize(.large)
            }
        }
    }
}

import AppKit
