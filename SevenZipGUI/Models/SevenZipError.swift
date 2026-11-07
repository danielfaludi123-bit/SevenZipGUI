import Foundation

/// Verständliche Fehler der App, gemappt aus 7zz-Exit-Codes und stderr.
enum SevenZipError: LocalizedError, Equatable {
    case binaryNotFound
    case wrongPassword
    case corruptArchive
    case archiveNotFound(String)
    case notAnArchive
    case outOfMemory
    case cancelled
    case warning(String)
    case fatal(String)

    /// 7zz Exit-Codes: 0 OK, 1 Warnung, 2 Fatal, 7 CLI-Fehler, 8 Speicher, 255 Abbruch.
    static func map(exitCode: Int32, stderr: String, stdout: String) -> SevenZipError? {
        let combined = (stderr + "\n" + stdout).lowercased()
        switch exitCode {
        case 0:
            return nil
        case 1:
            return .warning("7-Zip meldet eine Warnung: \(stderr.isEmpty ? stdout : stderr)")
        case 7:
            return .fatal("Ungültige Kommandozeilen-Parameter für 7zz.")
        case 8:
            return .outOfMemory
        case 255:
            return .cancelled
        default:
            if combined.contains("wrong password") || combined.contains("can not open encrypted archive")
                || combined.contains("password is incorrect") {
                return .wrongPassword
            }
            if combined.contains("is not archive") || combined.contains("cannot open the file as archive")
                || combined.contains("can't open as archive") {
                return .notAnArchive
            }
            if combined.contains("headers error") || combined.contains("data error")
                || combined.contains("crc failed") || combined.contains("unexpected end of data") {
                return .corruptArchive
            }
            if combined.contains("no such file") || combined.contains("cannot find") {
                return .archiveNotFound(stderr)
            }
            return .fatal(stderr.isEmpty ? "7zz beendet mit Code \(exitCode)." : stderr)
        }
    }

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "7zz wurde nicht gefunden. Installiere es mit „brew install sevenzip“ oder setze den Pfad in den Einstellungen."
        case .wrongPassword:
            return "Falsches Passwort oder das Archiv kann mit diesem Passwort nicht geöffnet werden."
        case .corruptArchive:
            return "Das Archiv ist beschädigt oder unvollständig (Header-/Daten- oder CRC-Fehler)."
        case .archiveNotFound(let detail):
            return "Archivdatei nicht gefunden. \(detail)"
        case .notAnArchive:
            return "Die Datei ist kein unterstütztes Archiv."
        case .outOfMemory:
            return "7-Zip meldet: nicht genügend Arbeitsspeicher."
        case .cancelled:
            return "Der Vorgang wurde abgebrochen."
        case .warning(let msg):
            return msg
        case .fatal(let msg):
            return msg
        }
    }
}
