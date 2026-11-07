import Foundation

/// Zustand eines laufenden 7zz-Vorgangs: echter Fortschritt aus der
/// 7zz-Ausgabe (-bsp1), verstrichene Zeit, geschätzte Restzeit, Log, Abbruch.
@MainActor
final class JobViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case running
        case finished
        case failed(String)
        case cancelled
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var percent: Double = 0
    @Published private(set) var currentFile: String?
    @Published private(set) var startedAt: Date?
    @Published private(set) var log: String = ""
    @Published var showsVerboseLog: Bool = false

    let runner = SevenZipRunner()
    private var activeTask: Task<Void, Never>?

    var isRunning: Bool { state == .running }

    var elapsedTime: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    /// Geschätzte Restzeit basierend auf dem echten Fortschritt.
    var estimatedRemaining: TimeInterval? {
        guard percent > 1, isRunning else { return nil }
        let elapsed = elapsedTime
        return elapsed / percent * (100 - percent)
    }

    var formattedElapsed: String { Self.format(elapsedTime) }

    var formattedRemaining: String {
        guard let estimatedRemaining else { return "—" }
        return "ca. " + Self.format(estimatedRemaining)
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        if total < 60 { return "\(total) s" }
        if total < 3600 { return String(format: "%d:%02d min", total / 60, total % 60) }
        return String(format: "%d:%02d:%02d h", total / 3600, (total % 3600) / 60, total % 60)
    }

    func reset() {
        state = .idle
        percent = 0
        currentFile = nil
        startedAt = nil
        log = ""
    }

    /// Startet eine Operation. Progress- und Log-Callbacks laufen @Sendable
    /// im Hintergrund und werden hier auf den MainActor gehoben.
    func start(_ operation: @escaping @MainActor (SevenZipService) async throws -> Void) {
        reset()
        state = .running
        startedAt = Date()
        activeTask = Task { @MainActor in
            do {
                try await operation(SevenZipService.shared)
                // Nicht überschreiben, wenn der User währenddessen abgebrochen hat.
                if state == .running {
                    percent = 100
                    state = .finished
                }
            } catch let error as SevenZipError {
                if error == .cancelled || state == .cancelled {
                    state = .cancelled
                } else {
                    state = .failed(error.localizedDescription)
                }
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        activeTask?.cancel()
        Task {
            await runner.cancel()
        }
        state = .cancelled
        appendLog("— Vorgang vom Benutzer abgebrochen —")
    }

    // MARK: - Callbacks für SevenZipRunner

    var progressHandler: @Sendable (SevenZipProgress) -> Void {
        { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.percent = progress.percent
                if let file = progress.currentFile { self?.currentFile = file }
            }
        }
    }

    var logHandler: @Sendable (String) -> Void {
        { [weak self] line in
            Task { @MainActor [weak self] in
                self?.appendLog(line)
            }
        }
    }

    private func appendLog(_ line: String) {
        log += line + "\n"
        // Log auf ~4000 Zeilen begrenzen
        if log.count > 400_000 {
            log = String(log.suffix(200_000))
        }
    }
}
