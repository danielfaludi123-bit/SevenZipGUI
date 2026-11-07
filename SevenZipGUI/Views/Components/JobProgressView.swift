import SwiftUI

/// Echte Fortschrittsanzeige für laufende 7zz-Vorgänge:
/// Prozent aus 7zz-Output, aktuelle Datei, Zeiten, Abbruch, Log.
struct JobProgressView: View {

    @ObservedObject var job: JobViewModel

    var body: some View {
        if job.state != .idle {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    statusRow

                    if job.isRunning || job.state == .finished {
                        ProgressView(value: job.percent, total: 100)
                        HStack {
                            Text(job.currentFile ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(String(format: "%.0f %%", job.percent))
                                .monospacedDigit()
                                .font(.caption)
                        }
                        HStack(spacing: 16) {
                            Label("Verstrichen: \(job.formattedElapsed)", systemImage: "clock")
                            Label("Restzeit: \(job.formattedRemaining)", systemImage: "hourglass")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("CLI-Ausgabe anzeigen", isExpanded: $job.showsVerboseLog) {
                        ScrollView {
                            Text(job.log.isEmpty ? "—" : job.log)
                                .font(.system(.caption2, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 160)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .font(.caption)
                }
                .padding(4)
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch job.state {
        case .idle:
            EmptyView()
        case .running:
            HStack {
                Label("Vorgang läuft…", systemImage: "gearshape.2")
                    .font(.headline)
                Spacer()
                Button(role: .cancel) { job.cancel() } label: {
                    Label("Abbrechen", systemImage: "xmark.circle")
                }
            }
        case .finished:
            Label("Erfolgreich abgeschlossen", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
        case .cancelled:
            Label("Abgebrochen", systemImage: "stop.circle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label("Fehler", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
