import Foundation

/// ViewModel für „Extrahieren".
@MainActor
final class ExtractArchiveViewModel: ObservableObject {

    @Published var archiveURL: URL?
    @Published var destinationURL: URL?
    @Published var specificEntries: [String] = []
    @Published var overwrite: OverwritePolicy = .autoRename
    @Published var password: String = ""
    @Published var createSubfolder = true
    @Published var job = JobViewModel()

    var canExtract: Bool {
        archiveURL != nil && destinationURL != nil && !job.isRunning
    }

    func setArchive(_ url: URL, entries: [String] = []) {
        archiveURL = url
        specificEntries = entries
        // Standard-Ziel: gleicher Ordner wie das Archiv.
        if destinationURL == nil {
            destinationURL = url.deletingLastPathComponent()
        }
    }

    /// Tatsächlicher Zielpfad inkl. optionalem Unterordner nach Archivname.
    var effectiveDestination: String? {
        guard let destinationURL, let archiveURL else { return nil }
        if createSubfolder {
            let name = archiveURL.deletingPathExtension().lastPathComponent
            // Mehrteilige Archive: .7z.001 → Basisname ohne .001
            let clean = name.replacingOccurrences(of: #"\.\d{3}$"#, with: "", options: .regularExpression)
            return destinationURL.appendingPathComponent(clean).path
        }
        return destinationURL.path
    }

    func extract() {
        guard let archiveURL, let destination = effectiveDestination else { return }
        let path = archiveURL.path
        let pw = password.isEmpty ? nil : password
        let entries = specificEntries
        let policy = overwrite
        job.start { service in
            let args = SevenZipArguments.extract(archive: path, to: destination,
                                                 password: pw, overwrite: policy,
                                                 entries: entries)
            _ = try await service.execute(arguments: args, runner: self.job.runner,
                                          onProgress: self.job.progressHandler,
                                          onLog: self.job.logHandler)
        }
    }

    func revealDestination() {
        if let destination = effectiveDestination {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destination)
        }
    }
}

import AppKit
