import Foundation

/// ViewModel für „Archiv erstellen".
@MainActor
final class CreateArchiveViewModel: ObservableObject {

    @Published var files: [URL] = []
    @Published var options = CreateArchiveOptions()
    @Published var destinationArchive: URL?
    @Published var password: String = ""
    @Published var passwordConfirm: String = ""
    @Published var volumeValue: String = ""
    @Published var volumeUnit: String = "MB"
    @Published var job = JobViewModel()

    /// Formatwechsel setzt ungültige Methoden zurück.
    func selectFormat(_ format: ArchiveFormat) {
        options.format = format
        if let method = options.method, !format.methods.contains(method) {
            options.method = format.defaultMethod
        }
        if options.method == nil { options.method = format.defaultMethod }
        if !format.supportsEncryption {
            password = ""
            passwordConfirm = ""
            options.encryptHeaders = false
        }
        updateSuggestedDestination()
    }

    var passwordsMatch: Bool {
        password.isEmpty || password == passwordConfirm
    }

    var canCreate: Bool {
        !files.isEmpty && destinationArchive != nil && passwordsMatch
            && !job.isRunning && isVolumeValid
    }

    var isVolumeValid: Bool {
        volumeValue.isEmpty || Int(volumeValue) != nil
    }

    func addFiles(_ urls: [URL]) {
        for url in urls where !files.contains(url) {
            files.append(url)
        }
        updateSuggestedDestination()
    }

    func removeFile(_ url: URL) {
        files.removeAll { $0 == url }
        updateSuggestedDestination()
    }

    /// Schlägt als Ziel den Ordner der ersten Datei vor.
    private func updateSuggestedDestination() {
        guard let first = files.first else { return }
        let name = first.deletingPathExtension().lastPathComponent
        let dir = first.deletingLastPathComponent()
        destinationArchive = dir.appendingPathComponent(name)
            .appendingPathExtension(options.format.fileExtension)
    }

    /// Baut das Volume-Flag aus Wert + Einheit (z. B. 100 + MB → "100m").
    var volumeFlag: String {
        guard !volumeValue.isEmpty else { return "" }
        let unit = volumeUnit == "GB" ? "g" : volumeUnit == "KB" ? "k" : "m"
        return volumeValue + unit
    }

    func create() {
        guard let archive = destinationArchive else { return }
        var opts = options
        opts.password = password.isEmpty ? nil : password
        opts.volumeSize = volumeFlag
        let filePaths = files.map(\.path)
        let archivePath = archive.path
        job.start { service in
            let args = SevenZipArguments.create(archive: archivePath, files: filePaths, options: opts)
            _ = try await service.execute(arguments: args, runner: self.job.runner,
                                          onProgress: self.job.progressHandler,
                                          onLog: self.job.logHandler)
        }
    }
}
