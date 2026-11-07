import Foundation

/// Ein von 7zz erstellbares Archivformat inkl. der tatsächlich
/// von 7-Zip 26.05 unterstützten Fähigkeiten.
enum ArchiveFormat: String, CaseIterable, Identifiable {
    case sevenZ = "7z"
    case zip = "zip"
    case tar = "tar"
    case gzip = "gzip"
    case bzip2 = "bzip2"
    case xz = "xz"
    case wim = "wim"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sevenZ: return "7z"
        case .zip: return "ZIP"
        case .tar: return "TAR"
        case .gzip: return "GZIP"
        case .bzip2: return "BZIP2"
        case .xz: return "XZ"
        case .wim: return "WIM"
        }
    }

    var fileExtension: String {
        switch self {
        case .sevenZ: return "7z"
        case .zip: return "zip"
        case .tar: return "tar"
        case .gzip: return "gz"
        case .bzip2: return "bz2"
        case .xz: return "xz"
        case .wim: return "wim"
        }
    }

    /// 7zz -t Flag
    var typeFlag: String { rawValue }

    /// Kompressionsmethoden, die 7zz für dieses Format anbietet.
    var methods: [String] {
        switch self {
        case .sevenZ: return ["LZMA2", "LZMA", "PPMd", "BZip2", "Deflate", "Copy"]
        case .zip: return ["Deflate", "Deflate64", "BZip2", "LZMA", "PPMd"]
        case .gzip, .bzip2, .xz, .tar: return []
        case .wim: return ["LZX", "LZMS", "XPRESS"]
        }
    }

    var defaultMethod: String? { methods.first }

    var supportsCompressionLevel: Bool {
        switch self {
        case .tar: return false
        default: return true
        }
    }

    /// Passwortschutz / Verschlüsselung (7z & ZIP per AES).
    var supportsEncryption: Bool {
        self == .sevenZ || self == .zip
    }

    /// Dateinamen verschlüsseln (-mhe=on) — nur 7z.
    var supportsHeaderEncryption: Bool { self == .sevenZ }

    /// Solid Compression (-ms) — nur 7z.
    var supportsSolid: Bool { self == .sevenZ }

    /// Wörterbuchgröße (nur bei LZMA/LZMA2 sinnvoll).
    var supportsDictionary: Bool {
        self == .sevenZ || self == .zip
    }

    /// Multithreading (-mmt) — von den meisten Formaten unterstützt.
    var supportsMultithreading: Bool { self != .tar }

    /// Mehrteilige Archive (-v) — prinzipiell von allen Erstellungsformaten.
    var supportsVolumes: Bool { true }

    /// Verfügbare Wörterbuchgrößen.
    static let dictionarySizes = ["256 KB", "1 MB", "4 MB", "16 MB", "24 MB", "32 MB", "64 MB", "128 MB", "256 MB"]

    /// Wandelt UI-Angabe ("24 MB") in 7zz-Syntax um ("24m").
    static func dictionaryFlag(_ ui: String) -> String {
        let digits = ui.filter(\.isNumber)
        if ui.contains("KB") { return digits + "k" }
        return digits + "m"
    }
}
