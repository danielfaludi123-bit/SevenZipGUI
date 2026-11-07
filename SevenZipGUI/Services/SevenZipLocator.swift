import Foundation

/// Findet das offizielle 7-Zip CLI (`7zz`) auf dem System.
/// Berücksichtigt Apple Silicon (/opt/homebrew), Intel (/usr/local),
/// MacPorts und den PATH — auch wenn Homebrew nicht im GUI-PATH liegt.
struct SevenZipLocator {

    static let candidatePaths = [
        "/opt/homebrew/bin/7zz",   // Homebrew Apple Silicon
        "/usr/local/bin/7zz",      // Homebrew Intel
        "/opt/local/bin/7zz",      // MacPorts
        "/usr/bin/7zz"
    ]

    /// Ermittelt den 7zz-Pfad. Ein manuell in den Einstellungen gesetzter
    /// Pfad hat Vorrang, danach Kandidaten, danach PATH-Suche.
    static func locate(customPath: String? = nil) -> String? {
        if let customPath, !customPath.isEmpty, isExecutable7zz(customPath) {
            return customPath
        }
        for path in candidatePaths where isExecutable7zz(path) {
            return path
        }
        return searchPATH()
    }

    /// Version des gefundenen Binaries, z. B. "26.05".
    static func version(of path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = []
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            // Erste Zeile: "7-Zip (z) 26.05 (arm64) : ..."
            if let range = text.range(of: #"7-Zip \(z\) ([0-9.]+)"#, options: .regularExpression) {
                let line = String(text[range])
                return line.components(separatedBy: " ").dropFirst(2).first
            }
            return nil
        } catch {
            return nil
        }
    }

    private static func isExecutable7zz(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    /// Sucht 7zz über eine Login-Shell im PATH (funktioniert auch ohne GUI-PATH).
    private static func searchPATH() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v 7zz"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let path, !path.isEmpty, isExecutable7zz(path) { return path }
            return nil
        } catch {
            return nil
        }
    }
}
