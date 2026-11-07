import XCTest
@testable import SevenZipGUI

final class ListParserTests: XCTestCase {

    /// Reale Ausgabeform von `7zz l -slt`.
    let sampleListing = """
    7-Zip (z) 26.05 (arm64) : Copyright (c) 1999-2026 Igor Pavlov : 2026-10-21

    Listing archive: /tmp/test.7z

    --
    Path = /tmp/test.7z
    Type = 7z
    Physical Size = 1543
    Headers Size = 210
    Method = LZMA2:24
    Solid = +
    Blocks = 1

    ----------
    Path = docs
    Folder = +
    Size = 0
    Packed Size = 0
    Modified = 2026-01-15 10:30:00
    Attributes = D drwxr-xr-x
    CRC =
    Encrypted = -

    Path = docs/readme.txt
    Size = 1024
    Packed Size = 512
    Modified = 2026-01-15 10:30:01
    Attributes = A_ -rw-r--r--
    CRC = A1B2C3D4
    Encrypted = +
    Method = LZMA2:24
    Block = 0

    """

    func testParsesEntries() {
        let entries = ArchiveInspector.parseListing(sampleListing)
        XCTAssertEqual(entries.count, 2)

        let dir = entries[0]
        XCTAssertEqual(dir.path, "docs")
        XCTAssertTrue(dir.isDirectory)

        let file = entries[1]
        XCTAssertEqual(file.path, "docs/readme.txt")
        XCTAssertFalse(file.isDirectory)
        XCTAssertEqual(file.size, 1024)
        XCTAssertEqual(file.packedSize, 512)
        XCTAssertTrue(file.isEncrypted)
        XCTAssertEqual(file.crc, "A1B2C3D4")
        XCTAssertNotNil(file.modified)
        // Ratio: 1 - 512/1024 = 50 %
        XCTAssertEqual(file.formattedRatio, "50 %")
    }

    func testParsesArchiveInfo() {
        let info = ArchiveInspector.parseArchiveInfo(sampleListing)
        XCTAssertEqual(info.type, "7z")
        XCTAssertFalse(info.isMultivolume)
    }

    func testEmptyListing() {
        XCTAssertEqual(ArchiveInspector.parseListing(""), [])
    }

    func testProgressLineParsing() {
        let p1 = SevenZipRunner.parseProgressLine(" 42% 3 - docs/readme.txt")
        XCTAssertEqual(p1?.percent, 42)
        XCTAssertEqual(p1?.currentFile, "docs/readme.txt")

        let p2 = SevenZipRunner.parseProgressLine("17% + some file.txt")
        XCTAssertEqual(p2?.percent, 17)
        XCTAssertEqual(p2?.currentFile, "some file.txt")

        XCTAssertNil(SevenZipRunner.parseProgressLine("Everything is Ok"))
    }
}
