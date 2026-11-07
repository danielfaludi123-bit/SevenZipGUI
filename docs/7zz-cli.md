# Verwendete 7zz-Parameter (7-Zip 26.05)

Geprüft gegen die installierte Version: `7zz` = **7-Zip (z) 26.05 (arm64)** via Homebrew (`brew install sevenzip`).
Quellen: `7zz --help`, `7zz i` (Formate), offizielle 7-Zip-Doku.

## Befehle

| App-Funktion | 7zz-Befehl |
|---|---|
| Archiv erstellen | `7zz a [switches] <archiv> <dateien...>` |
| Inhalt listen | `7zz l -slt <archiv>` |
| Extrahieren (mit Pfaden) | `7zz x <archiv> -o<ziel> [-ao*] [dateien...]` |
| Archiv testen | `7zz t <archiv>` |
| Dateien hinzufügen/aktualisieren | `7zz u <archiv> <dateien...>` |
| Dateien entfernen | `7zz d <archiv> <dateien...>` |
| Eintrag umbenennen | `7zz rn <archiv> <alt> <neu>` |

## Switches

| Switch | Bedeutung | Verwendet in |
|---|---|---|
| `-t{typ}` | Archivtyp: `7z`, `zip`, `tar`, `gzip`, `bzip2`, `xz`, `wim` | Erstellen |
| `-mx={0..9}` | Kompressionsstufe (0 = speichern, 9 = ultra) | Erstellen (nicht TAR) |
| `-m0={Methode}` | Kompressionsmethode (LZMA2, LZMA, PPMd, BZip2, Deflate, Deflate64, Copy, LZX, LZMS, XPRESS) | Erstellen |
| `-m0=LZMA2:d={n}` | Wörterbuchgröße, z. B. `d=24m` | Erstellen (LZMA/LZMA2) |
| `-ms=on/off` | Solid Compression (nur 7z) | Erstellen |
| `-mmt=on/off` | Multithreading | Erstellen |
| `-p{pw}` | Passwort (aktiviert AES-256 bei 7z) | Erstellen/Öffnen/Extrahieren |
| `-mem=AES256` | Verschlüsselungsmethode für ZIP | Erstellen (ZIP + Passwort) |
| `-mhe=on` | Header-/Dateinamen-Verschlüsselung (nur 7z) | Erstellen (7z + Passwort) |
| `-v{größe}` | Mehrteiliges Archiv, z. B. `-v100m`, `-v2g`, `-v500k` | Erstellen |
| `-o{pfad}` | Zielverzeichnis (direkt angehängt, kein Leerzeichen) | Extrahieren |
| `-aoa` / `-aos` / `-aou` | Überschreiben / Überspringen / Auto-Umbenennen der extrahierten Dateien | Extrahieren |
| `-slt` | Technisches Listing (Schlüssel-Wert-Blöcke) für Parser | Öffnen |
| `-bso1` | Standard-Ausgabe auf stdout umleiten | Fortschritt/Logs |
| `-bsp1` | Fortschrittsanzeige auf stdout umleiten | Fortschritt |

## Fortschritt

Mit `-bsp1` schreibt 7zz Zeilen wie ` 42% 12 - pfad/datei.txt` auf stdout und überschreibt
sie mit `\r`- und Backspace-Sequenzen (`\x08`). Die App trennt den Stream auf `\r`, `\n` und `\x08`
und parst Prozent + aktuelle Datei. Die Restzeit wird aus dem echten Fortschritt geschätzt.

## Exit-Codes

| Code | Bedeutung | App-Mapping |
|---|---|---|
| 0 | OK | Erfolg |
| 1 | Warnung (z. B. Datei gesperrt) | Warnung im Log, kein Abbruch |
| 2 | Fataler Fehler | Analysiert: „Wrong password“, „Is not archive“, „Headers Error“/„CRC Failed“ → verständliche Meldung |
| 7 | Ungültige CLI-Parameter | Fataler Fehler (App-Bug) |
| 8 | Zu wenig Speicher | Out-of-Memory-Meldung |
| 255 | Vom Benutzer abgebrochen | „Abgebrochen“ |

## Sicherheit

- Argumente werden ausschließlich als `Process.arguments`-Array übergeben — keine Shell, keine Injection.
- `-p{pw}`-Argumente werden in Logs als `-p***` maskiert. Passwörter werden niemals persistiert.
- Extrahierte Dateien werden von der App niemals automatisch ausgeführt.
