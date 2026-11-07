import Foundation

/// Liest Archivinhalte über `7zz l -slt` aus und parst das
/// technische Listing in ArchiveEntry-Modelle.
struct ArchiveInspector {

    /// Listet den Inhalt eines Archivs.
    static func list(runner: SevenZipRunner, executable: String,
                     archive: String, password: String? = nil) async throws -> (ArchiveInfo, [ArchiveEntry]) {
        let args = SevenZipArguments.list(archive: archive, password: password)
        let result = try await runner.run(executable: executable, arguments: args)
        if let error = SevenZipError.map(exitCode: result.exitCode,
                                         stderr: result.stderr, stdout: result.stdout) {
            throw error
        }
        let entries = parseListing(result.stdout)
        var info = parseArchiveInfo(result.stdout)
        info.path = archive
        info.fileCount = entries.filter { !$0.isDirectory }.count
        info.folderCount = entries.filter(\.isDirectory).count
        info.totalSize = entries.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
        info.packedSize = entries.reduce(0) { $0 + $1.packedSize }
        info.isEncrypted = entries.contains(where: \.isEncrypted)
        return (info, entries)
    }

    /// Parst `7zz l -slt` Ausgabe: Schlüssel-Wert-Blöcke, getrennt durch Leerzeilen,
    /// Dateiblöcke folgen nach der "----------" Trennlinie.
    static func parseListing(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var inFilesSection = false
        var block: [String: String] = [:]

        func flushBlock() {
            guard let path = block["Path"], !path.isEmpty else {
                block = [:]
                return
            }
            let size = Int64(block["Size"] ?? "") ?? 0
            let packed = Int64(block["Packed Size"] ?? "") ?? 0
            let folder = block["Folder"] == "+" || block["Attributes"]?.hasPrefix("D") == true
            let encrypted = block["Encrypted"] == "+"
            let crc = block["CRC"]
            let modified = parseDate(block["Modified"])
            entries.append(ArchiveEntry(path: path, size: size, packedSize: packed,
                                        modified: modified, isDirectory: folder,
                                        isEncrypted: encrypted, crc: crc))
            block = [:]
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("----------") {
                inFilesSection = true
                block = [:]
                continue
            }
            guard inFilesSection else { continue }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushBlock()
                continue
            }
            // Format: "Key = Value"
            if let eqRange = line.range(of: " = ") {
                let key = String(line[line.startIndex..<eqRange.lowerBound])
                let value = String(line[eqRange.upperBound...])
                block[key] = value
            }
        }
        flushBlock()
        return entries
    }

    /// Parst die Archiv-Metadaten aus dem Kopf des Listings.
    static func parseArchiveInfo(_ output: String) -> ArchiveInfo {
        var type = "Unbekannt"
        var multivolume = false
        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine)
            if line.hasPrefix("----------") { break }
            if let eqRange = line.range(of: " = ") {
                let key = String(line[line.startIndex..<eqRange.lowerBound])
                let value = String(line[eqRange.upperBound...])
                if key == "Type" { type = value }
                if key == "Multivolume" && value == "+" { multivolume = true }
            }
        }
        return ArchiveInfo(path: "", type: type, totalSize: 0, packedSize: 0,
                           fileCount: 0, folderCount: 0,
                           isEncrypted: false, isMultivolume: multivolume)
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string)
    }
}
