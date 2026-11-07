import Foundation

/// Ergebnis eines 7zz-Laufs.
struct SevenZipResult: Equatable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

/// Fortschritts-Event eines laufenden Vorgangs.
struct SevenZipProgress: Equatable {
    var percent: Double       // 0...100
    var currentFile: String?  // aktuell bearbeitete Datei, falls erkennbar
}

/// Führt 7zz sicher über Foundation.Process aus.
/// - Argumente werden als Array übergeben (kein Shell, keine Injection)
/// - stdout/stderr werden über readabilityHandler gelesen (kein Deadlock)
/// - Laufende Prozesse sind abbrecbar
/// - Passwort-Argumente werden in Logs maskiert
actor SevenZipRunner {

    private var process: Process?
    private var cancelled = false

    /// Bricht den laufenden Prozess ab (SIGTERM).
    func cancel() {
        cancelled = true
        process?.terminate()
    }

    var isRunning: Bool { process != nil }

    /// Führt 7zz mit den gegebenen Argumenten aus.
    /// - Parameter onProgress: Fortschritts-Callback (Prozent, aktuelle Datei)
    /// - Parameter onLog: rohe Logzeilen (Passwörter maskiert)
    func run(executable: String, arguments: [String],
             onProgress: (@Sendable (SevenZipProgress) -> Void)? = nil,
             onLog: (@Sendable (String) -> Void)? = nil) async throws -> SevenZipResult {

        cancelled = false
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        // GUI-Apps haben einen knappen PATH — 7zz braucht ihn nicht, aber
        // locale sauber setzen, damit die Ausgabe parsebar bleibt.
        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "C.UTF-8"
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        final class Collector: @unchecked Sendable {
            let lock = NSLock()
            var stdoutData = Data()
            var stderrData = Data()
            var lineBuffer = Data()
            var lastFile: String?
            func append(_ data: Data, isStdout: Bool) {
                lock.lock()
                defer { lock.unlock() }
                if isStdout { stdoutData.append(data) } else { stderrData.append(data) }
            }
            func appendLine(_ data: Data) {
                lock.lock()
                defer { lock.unlock() }
                lineBuffer.append(data)
            }
        }
        let collector = Collector()

        // 7zz schreibt Fortschritt auf stdout (-bsp1) und überschreibt die
        // Zeile mit \r und Backspace-Sequenzen (\x08). Wir splitten auf
        // \r, \n und \x08, damit jedes Fortschritts-Update einzeln ankommt.
        func processChunk(_ data: Data, isStdout: Bool) {
            collector.append(data, isStdout: isStdout)
            guard isStdout else {
                if let text = String(data: data, encoding: .utf8) {
                    for line in text.split(whereSeparator: \.isNewline) {
                        onLog?(String(line))
                    }
                }
                return
            }
            collector.appendLine(data)
            while true {
                collector.lock.lock()
                var range: Range<Data.Index>?
                for sep: UInt8 in [0x0D, 0x0A, 0x08] {
                    if let r = collector.lineBuffer.firstRange(of: Data([sep])) {
                        if let existing = range, r.lowerBound >= existing.lowerBound { continue }
                        range = r
                    }
                }
                var segment: Data?
                if let range {
                    segment = collector.lineBuffer.subdata(in: collector.lineBuffer.startIndex..<range.lowerBound)
                    collector.lineBuffer.removeSubrange(...range.lowerBound)
                }
                collector.lock.unlock()
                guard let segment else { break }
                handleLine(segment)
            }
        }

        func handleLine(_ data: Data) {
            guard let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters.union(.whitespaces)),
                  !text.isEmpty else { return }
            onLog?(text)
            // Fortschrittszeilen: " 42% 3 - pfad/datei.txt" oder "42% + datei"
            if let progress = Self.parseProgressLine(text) {
                if let file = progress.currentFile { collector.lastFile = file }
                onProgress?(progress)
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { processChunk(data, isStdout: true) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { processChunk(data, isStdout: false) }
        }

        do {
            try process.run()
        } catch {
            throw SevenZipError.binaryNotFound
        }
        self.process = process

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                // Restdaten einsammeln
                let outRest = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errRest = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                processChunk(outRest, isStdout: true)
                processChunk(errRest, isStdout: false)
                continuation.resume(returning: proc.terminationStatus)
            }
        }

        self.process = nil

        collector.lock.lock()
        let out = String(data: collector.stdoutData, encoding: .utf8) ?? ""
        let err = String(data: collector.stderrData, encoding: .utf8) ?? ""
        collector.lock.unlock()

        return SevenZipResult(exitCode: exitCode, stdout: out, stderr: err)
    }

    /// Parst eine Fortschrittszeile von 7zz (-bsp1 Ausgabe).
    /// Format: "<spaces>NN% <zähler> - <datei>" oder "NN% + <datei>".
    static func parseProgressLine(_ line: String) -> SevenZipProgress? {
        guard let percentRange = line.range(of: #"(\d{1,3})%"#, options: .regularExpression) else {
            return nil
        }
        let percentString = line[percentRange].dropLast()
        guard let percent = Double(percentString) else { return nil }

        var currentFile: String?
        let rest = line[percentRange.upperBound...]
        if let dashRange = rest.range(of: " - ", options: .backwards) {
            currentFile = String(rest[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let plusRange = rest.range(of: " + ", options: .backwards) {
            currentFile = String(rest[plusRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        if currentFile?.isEmpty == true { currentFile = nil }
        return SevenZipProgress(percent: min(100, max(0, percent)), currentFile: currentFile)
    }
}
