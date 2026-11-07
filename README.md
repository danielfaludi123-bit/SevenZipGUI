# SevenZipGUI

Native macOS-Oberfläche für das offizielle 7-Zip CLI (`7zz`) — SwiftUI, ohne eigenes Kompressions-Backend.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![7-Zip](https://img.shields.io/badge/7--Zip%20CLI-26.05-green)

## Features

- **Archiv erstellen**: 7z, ZIP, TAR, GZIP, BZIP2, XZ, WIM
  - Kompressionsstufe 0–9, Methoden (LZMA2, LZMA, PPMd, BZip2, Deflate, …), Wörterbuchgröße
  - Solid Compression (7z), Multithreading, Mehrteilige Archive (`-v`)
  - AES-256-Verschlüsselung (7z & ZIP), Dateinamen-Verschlüsselung (`-mhe=on`, nur 7z)
- **Archive öffnen & verwalten**: Inhaltstabelle (Größe, komprimiert, Ratio, Datum), Suche, Sortierung
  - Einzelne Dateien oder alles extrahieren, Archive testen, Dateien hinzufügen/entfernen,
    Einträge umbenennen (`7zz rn`), Archivdatei umbenennen
- **Extrahieren**: Zielwahl, Unterordner-Option, Überschreibverhalten (umbenennen/überschreiben/überspringen)
- **Echte Fortschrittsanzeige**: Prozent, aktuelle Datei, verstrichene Zeit, Restzeit-Schätzung
  (geparst aus der echten 7zz-Ausgabe via `-bsp1`), Abbrechen laufender Vorgänge
- **Sicherheit**: Argumente als Array (keine Shell, keine Command Injection), Passwörter nie in Logs
  (maskiert als `-p***`) und niemals gespeichert, keine Netzwerkzugriffe, keine Telemetrie

## Voraussetzungen

- macOS 14 (Sonoma) oder neuer
- 7-Zip CLI: `brew install sevenzip`
  - Gesucht wird in `/opt/homebrew/bin` (Apple Silicon), `/usr/local/bin` (Intel), MacPorts und im PATH.
  - Ein eigener Pfad lässt sich in den Einstellungen setzen.

## Installation (DMG)

1. `SevenZipGUI.dmg` aus den [Releases](https://github.com/danielfaludi123-bit/SevenZipGUI/releases) laden
2. App nach „Programme“ ziehen
3. Beim ersten Start: Rechtsklick → **Öffnen** (App ist nicht notarisiert)

## Selbst bauen

```bash
git clone https://github.com/danielfaludi123-bit/SevenZipGUI.git
cd SevenZipGUI
xcodebuild -project SevenZipGUI.xcodeproj -scheme SevenZipGUI \
  -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO
open ~/Library/Developer/Xcode/DerivedData/SevenZipGUI-*/Build/Products/Debug/SevenZipGUI.app
```

Tests:

```bash
xcodebuild -project SevenZipGUI.xcodeproj -scheme SevenZipGUI \
  -destination "platform=macOS" test CODE_SIGNING_ALLOWED=NO
```

DMG erzeugen:

```bash
./scripts/build-dmg.sh        # erzeugt dist/SevenZipGUI.dmg (Release)
```

## Architektur

MVVM, modular:

```
SevenZipGUI/
├── App/            # @main, Fenster & Commands (Tastaturkürzel ⌘1–⌘4)
├── Models/         # ArchiveFormat (7zz-Fähigkeiten), ArchiveEntry, Fehler-Mapping
├── Services/       # SevenZipLocator (Binary finden), SevenZipArguments (CLI-Builder),
│                   # SevenZipRunner (Process, async, abbrechbar), ArchiveInspector (l -slt Parser)
├── ViewModels/     # JobViewModel (Fortschritt/Log/Abbruch) + Bereichs-ViewModels
└── Views/          # Sidebar-Navigation, Home, Erstellen, Öffnen, Extrahieren, Einstellungen
```

Die verwendeten 7zz-Parameter sind in [docs/7zz-cli.md](docs/7zz-cli.md) dokumentiert.
Das `.xcodeproj` ist generiert (`scripts/generate_xcodeproj.py`) — bei neuen Dateien
Skript anpassen und erneut ausführen.

## Lizenz

MIT — siehe [LICENSE](LICENSE). 7-Zip selbst: LGPL/BSD (Igor Pavlov), hier nur als externes CLI genutzt.
