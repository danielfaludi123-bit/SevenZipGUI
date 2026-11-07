import Foundation

/// Überschreibverhalten beim Extrahieren.
enum OverwritePolicy: String, CaseIterable, Identifiable {
    case autoRename = "Automatisch umbenennen"
    case overwrite = "Vorhandene überschreiben"
    case skip = "Vorhandene überspringen"

    var id: String { rawValue }

    /// 7zz -ao Flags
    var flag: String {
        switch self {
        case .autoRename: return "-aou"
        case .overwrite: return "-aoa"
        case .skip: return "-aos"
        }
    }
}

/// Konfiguration für das Erstellen eines Archivs.
struct CreateArchiveOptions {
    var format: ArchiveFormat = .sevenZ
    var compressionLevel: Int = 5          // -mx (0..9), 5 = normal
    var method: String? = nil              // -m0=
    var dictionarySize: String = "16 MB"   // :d=
    var solid: Bool = false                // -ms=on/off
    var multithreading: Bool = true        // -mmt=on/off
    var password: String? = nil            // -p
    var encryptHeaders: Bool = false       // -mhe=on
    var volumeSize: String = ""            // -v, z. B. "100m"
}

/// Baut 7zz-Kommandozeilen als Argument-Arrays (kein Shell-String,
/// keine Command Injection möglich). Alle Flags entsprechen der
/// dokumentierten 7-Zip-CLI (siehe docs/7zz-cli.md).
enum SevenZipArguments {

    /// Archiv erstellen: `7zz a [switches] <archiv> <dateien...>`
    static func create(archive: String, files: [String], options: CreateArchiveOptions) -> [String] {
        var args = ["a", "-t\(options.format.typeFlag)"]

        if options.format.supportsCompressionLevel {
            args.append("-mx=\(options.compressionLevel)")
        }
        if options.format.supportsMultithreading {
            args.append(options.multithreading ? "-mmt=on" : "-mmt=off")
        }
        if let method = options.method, options.format.methods.contains(method) {
            var methodSwitch = "-m0=\(method)"
            if options.format.supportsDictionary,
               (method == "LZMA" || method == "LZMA2") {
                methodSwitch += ":d=\(ArchiveFormat.dictionaryFlag(options.dictionarySize))"
            }
            args.append(methodSwitch)
        }
        if options.format.supportsSolid {
            args.append(options.solid ? "-ms=on" : "-ms=off")
        }
        if let password = options.password, !password.isEmpty,
           options.format.supportsEncryption {
            args.append("-p\(password)")
            if options.format == .zip {
                args.append("-mem=AES256")
            }
            if options.format.supportsHeaderEncryption && options.encryptHeaders {
                args.append("-mhe=on")
            }
        }
        let volume = options.volumeSize.trimmingCharacters(in: .whitespaces)
        if options.format.supportsVolumes, !volume.isEmpty {
            args.append("-v\(volume)")
        }
        // Fortschritt auf stdout für Echtzeit-Anzeige
        args.append(contentsOf: ["-bso1", "-bsp1"])
        args.append(archive)
        args.append(contentsOf: files)
        return args
    }

    /// Archivinhalt technisch auflisten: `7zz l -slt <archiv>`
    static func list(archive: String, password: String? = nil) -> [String] {
        var args = ["l", "-slt"]
        if let password, !password.isEmpty { args.append("-p\(password)") }
        args.append(archive)
        return args
    }

    /// Extrahieren: `7zz x <archiv> -o<ziel> [-p<pw>] [-ao*] [dateien...]`
    static func extract(archive: String, to destination: String, password: String? = nil,
                        overwrite: OverwritePolicy, entries: [String] = []) -> [String] {
        var args = ["x", archive, "-o\(destination)", overwrite.flag]
        if let password, !password.isEmpty { args.append("-p\(password)") }
        args.append(contentsOf: ["-bso1", "-bsp1"])
        args.append(contentsOf: entries)
        return args
    }

    /// Archiv testen: `7zz t <archiv>`
    static func test(archive: String, password: String? = nil) -> [String] {
        var args = ["t", archive]
        if let password, !password.isEmpty { args.append("-p\(password)") }
        args.append(contentsOf: ["-bso1", "-bsp1"])
        return args
    }

    /// Dateien zu bestehendem Archiv hinzufügen/aktualisieren: `7zz u <archiv> <dateien...>`
    static func add(archive: String, files: [String], password: String? = nil) -> [String] {
        var args = ["u", archive]
        if let password, !password.isEmpty { args.append("-p\(password)") }
        args.append(contentsOf: ["-bso1", "-bsp1"])
        args.append(contentsOf: files)
        return args
    }

    /// Dateien aus Archiv entfernen: `7zz d <archiv> <dateien...>`
    static func delete(archive: String, entries: [String], password: String? = nil) -> [String] {
        var args = ["d", archive]
        if let password, !password.isEmpty { args.append("-p\(password)") }
        args.append(contentsOf: ["-bso1", "-bsp1"])
        args.append(contentsOf: entries)
        return args
    }

    /// Eintrag im Archiv umbenennen: `7zz rn <archiv> <alt> <neu>`
    static func rename(archive: String, from oldPath: String, to newPath: String,
                       password: String? = nil) -> [String] {
        var args = ["rn", archive, oldPath, newPath]
        if let password, !password.isEmpty { args.append("-p\(password)") }
        return args
    }

    /// Ersetzt Passwort-Argumente für die Log-Anzeige — Passwörter
    /// erscheinen niemals im Log.
    static func redacted(_ args: [String]) -> [String] {
        args.map { $0.hasPrefix("-p") && $0.count > 2 ? "-p***" : $0 }
    }
}
