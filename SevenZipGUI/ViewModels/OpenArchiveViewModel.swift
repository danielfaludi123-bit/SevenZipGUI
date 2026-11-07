import Foundation

/// ViewModel für „Archiv öffnen": Inhalt laden, testen, aktualisieren,
/// Einträge löschen/umbenennen, Archivdatei umbenennen.
@MainActor
final class OpenArchiveViewModel: ObservableObject {

    @Published var archiveURL: URL?
    @Published var info: ArchiveInfo?
    @Published var entries: [ArchiveEntry] = []
    @Published var selection: Set<ArchiveEntry.ID> = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsPassword = false
    @Published var job = JobViewModel()

    /// Wird nach erfolgreicher Passworteingabe gesetzt; nie persistent gespeichert.
    var password: String?

    var filteredEntries: [ArchiveEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
    }

    var selectedEntries: [ArchiveEntry] {
        entries.filter { selection.contains($0.id) }
    }

    func load(_ url: URL) {
        archiveURL = url
        Task { await refresh() }
    }

    func refresh(password: String? = nil) async {
        guard let archiveURL else { return }
        if let password { self.password = password }
        isLoading = true
        errorMessage = nil
        do {
            let (info, entries) = try await ArchiveInspector.list(
                runner: job.runner,
                executable: requireExecutable(),
                archive: archiveURL.path,
                password: self.password)
            self.info = info
            self.entries = entries
            self.needsPassword = false
        } catch SevenZipError.wrongPassword {
            needsPassword = true
            errorMessage = SevenZipError.wrongPassword.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func requireExecutable() throws -> String {
        guard let path = SevenZipService.shared.executablePath else {
            throw SevenZipError.binaryNotFound
        }
        return path
    }

    // MARK: - Operationen

    func testArchive() {
        guard let archiveURL else { return }
        let path = archiveURL.path
        let pw = password
        job.start { service in
            let args = SevenZipArguments.test(archive: path, password: pw)
            _ = try await service.execute(arguments: args, runner: self.job.runner,
                                          onProgress: self.job.progressHandler,
                                          onLog: self.job.logHandler)
        }
    }

    func addFiles(_ urls: [URL]) {
        guard let archiveURL else { return }
        let path = archiveURL.path
        let pw = password
        let files = urls.map(\.path)
        job.start { service in
            let args = SevenZipArguments.add(archive: path, files: files, password: pw)
            _ = try await service.execute(arguments: args, runner: self.job.runner,
                                          onProgress: self.job.progressHandler,
                                          onLog: self.job.logHandler)
            await self.refresh()
        }
    }

    func deleteSelected() {
        guard let archiveURL, !selectedEntries.isEmpty else { return }
        let path = archiveURL.path
        let pw = password
        let paths = selectedEntries.map(\.path)
        job.start { service in
            let args = SevenZipArguments.delete(archive: path, entries: paths, password: pw)
            _ = try await service.execute(arguments: args, runner: self.job.runner,
                                          onProgress: self.job.progressHandler,
                                          onLog: self.job.logHandler)
            await self.refresh()
        }
    }

    /// Eintrag im Archiv umbenennen (7zz rn).
    func renameSelected(to newName: String) {
        guard let archiveURL, selectedEntries.count == 1,
              let entry = selectedEntries.first else { return }
        let path = archiveURL.path
        let pw = password
        let oldPath = entry.path
        let newPath = ((oldPath as NSString).deletingLastPathComponent as NSString)
            .appendingPathComponent(newName)
        job.start { service in
            let args = SevenZipArguments.rename(archive: path, from: oldPath,
                                                to: newPath, password: pw)
            _ = try await service.execute(arguments: args, runner: self.job.runner,
                                          onProgress: self.job.progressHandler,
                                          onLog: self.job.logHandler)
            await self.refresh()
        }
    }

    /// Archivdatei selbst im Dateisystem umbenennen (FileManager, kein 7zz).
    func renameArchiveFile(to newName: String) throws {
        guard let archiveURL else { return }
        let target = archiveURL.deletingLastPathComponent()
            .appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw SevenZipError.fatal("Eine Datei mit diesem Namen existiert bereits.")
        }
        try FileManager.default.moveItem(at: archiveURL, to: target)
        self.archiveURL = target
    }
}
