import XCTest
@testable import SevenZipGUI

final class ArgumentBuilderTests: XCTestCase {

    func testCreateBasic7z() {
        var opts = CreateArchiveOptions()
        opts.format = .sevenZ
        opts.compressionLevel = 9
        let args = SevenZipArguments.create(archive: "/tmp/a b/test.7z",
                                            files: ["/tmp/a b/datei 1.txt"], options: opts)
        XCTAssertEqual(args.first, "a")
        XCTAssertTrue(args.contains("-t7z"))
        XCTAssertTrue(args.contains("-mx=9"))
        // Pfade mit Leerzeichen bleiben EIN Argument — keine Shell nötig
        XCTAssertTrue(args.contains("/tmp/a b/test.7z"))
        XCTAssertTrue(args.contains("/tmp/a b/datei 1.txt"))
    }

    func testCreatePasswordEncrypted7zWithHeaderEncryption() {
        var opts = CreateArchiveOptions()
        opts.format = .sevenZ
        opts.password = "geheim"
        opts.encryptHeaders = true
        let args = SevenZipArguments.create(archive: "/tmp/t.7z", files: ["/tmp/f.txt"], options: opts)
        XCTAssertTrue(args.contains("-pgeheim"))
        XCTAssertTrue(args.contains("-mhe=on"))
        // Passwort wird im Log maskiert
        let redacted = SevenZipArguments.redacted(args)
        XCTAssertFalse(redacted.contains("-pgeheim"))
        XCTAssertTrue(redacted.contains("-p***"))
    }

    func testZipUsesAES256() {
        var opts = CreateArchiveOptions()
        opts.format = .zip
        opts.password = "x"
        let args = SevenZipArguments.create(archive: "/tmp/t.zip", files: ["/tmp/f"], options: opts)
        XCTAssertTrue(args.contains("-mem=AES256"))
        XCTAssertFalse(args.contains("-mhe=on"))
    }

    func testEncryptionNotOfferedForUnsupportedFormats() {
        var opts = CreateArchiveOptions()
        opts.format = .gzip
        opts.password = "x"
        let args = SevenZipArguments.create(archive: "/tmp/t.gz", files: ["/tmp/f"], options: opts)
        XCTAssertFalse(args.contains { $0.hasPrefix("-p") && $0.count > 2 })
    }

    func testTarHasNoCompressionLevel() {
        var opts = CreateArchiveOptions()
        opts.format = .tar
        let args = SevenZipArguments.create(archive: "/tmp/t.tar", files: ["/tmp/f"], options: opts)
        XCTAssertFalse(args.contains { $0.hasPrefix("-mx=") })
    }

    func testDictionaryAndMethod() {
        var opts = CreateArchiveOptions()
        opts.format = .sevenZ
        opts.method = "LZMA2"
        opts.dictionarySize = "24 MB"
        let args = SevenZipArguments.create(archive: "/tmp/t.7z", files: ["/tmp/f"], options: opts)
        XCTAssertTrue(args.contains("-m0=LZMA2:d=24m"))
    }

    func testVolumes() {
        var opts = CreateArchiveOptions()
        opts.volumeSize = "100m"
        let args = SevenZipArguments.create(archive: "/tmp/t.7z", files: ["/tmp/f"], options: opts)
        XCTAssertTrue(args.contains("-v100m"))
    }

    func testExtractArguments() {
        let args = SevenZipArguments.extract(archive: "/tmp/a.7z", to: "/tmp/out",
                                             password: "pw", overwrite: .autoRename,
                                             entries: ["docs/readme.txt"])
        XCTAssertEqual(args.first, "x")
        XCTAssertTrue(args.contains("-o/tmp/out"))
        XCTAssertTrue(args.contains("-aou"))
        XCTAssertTrue(args.contains("docs/readme.txt"))
    }

    func testDeleteAndRename() {
        let del = SevenZipArguments.delete(archive: "/tmp/a.7z", entries: ["old.txt"])
        XCTAssertEqual(del.first, "d")
        XCTAssertTrue(del.contains("old.txt"))

        let ren = SevenZipArguments.rename(archive: "/tmp/a.7z", from: "old.txt", to: "new.txt")
        XCTAssertEqual(ren, ["rn", "/tmp/a.7z", "old.txt", "new.txt"])
    }
}
