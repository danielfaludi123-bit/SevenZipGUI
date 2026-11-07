import Foundation

/// Ein Eintrag (Datei oder Ordner) innerhalb eines Archivs.
struct ArchiveEntry: Identifiable, Equatable {
    let path: String
    let size: Int64
    let packedSize: Int64
    let modified: Date?
    let isDirectory: Bool
    let isEncrypted: Bool
    let crc: String?

    var id: String { path }

    var name: String {
        (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent
    }

    var compressionRatio: Double? {
        guard size > 0, packedSize > 0 else { return nil }
        return 1.0 - (Double(packedSize) / Double(size))
    }

    var formattedSize: String {
        isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedPackedSize: String {
        isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: packedSize, countStyle: .file)
    }

    var formattedRatio: String {
        guard let ratio = compressionRatio else { return "—" }
        return String(format: "%.0f %%", ratio * 100)
    }

    var formattedModified: String {
        guard let modified else { return "—" }
        return modified.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Metadaten des geöffneten Archivs.
struct ArchiveInfo: Equatable {
    var path: String
    var type: String
    var totalSize: Int64
    var packedSize: Int64
    var fileCount: Int
    var folderCount: Int
    var isEncrypted: Bool
    var isMultivolume: Bool
}
