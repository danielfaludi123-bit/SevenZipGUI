import Foundation

/// Zentrale Fassade für alle 7zz-Operationen der App.
@MainActor
final class SevenZipService: ObservableObject {

    static let shared = SevenZipService()

    /// Gefundener 7zz-Pfad (nil = nicht installiert / nicht gefunden).
    @Published private(set) var executablePath: String?
    @Published private(set) var detectedVersion: String?

    private init() {
        refresh()
    }

    /// Sucht 7zz erneut (z. B. nach Änderung des Custom-Pfads in den Einstellungen).
    func refresh() {
        let custom = UserDefaults.standard.string(forKey: "customSevenZipPath")
        executablePath = SevenZipLocator.locate(customPath: custom)
        detectedVersion = executablePath.flatMap { SevenZipLocator.version(of: $0) }
    }

    /// Führt einen 7zz-Befehl aus und mappt Fehler auf SevenZipError.
    /// - Throws: SevenZipError.binaryNotFound wenn kein Binary, sonst gemappter Fehler.
    @discardableResult
    func execute(arguments: [String],
                 runner: SevenZipRunner,
                 onProgress: (@Sendable (SevenZipProgress) -> Void)? = nil,
                 onLog: (@Sendable (String) -> Void)? = nil) async throws -> SevenZipResult {
        guard let executablePath else { throw SevenZipError.binaryNotFound }
        onLog?("$ 7zz " + SevenZipArguments.redacted(arguments).joined(separator: " "))
        let result = try await runner.run(executable: executablePath,
                                          arguments: arguments,
                                          onProgress: onProgress,
                                          onLog: onLog)
        if let error = SevenZipError.map(exitCode: result.exitCode,
                                         stderr: result.stderr, stdout: result.stdout) {
            throw error
        }
        return result
    }
}
