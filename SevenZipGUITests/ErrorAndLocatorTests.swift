import XCTest
@testable import SevenZipGUI

final class ErrorMappingTests: XCTestCase {

    func testExitCodes() {
        XCTAssertNil(SevenZipError.map(exitCode: 0, stderr: "", stdout: ""))
        XCTAssertEqual(SevenZipError.map(exitCode: 8, stderr: "", stdout: ""), .outOfMemory)
        XCTAssertEqual(SevenZipError.map(exitCode: 255, stderr: "", stdout: ""), .cancelled)

        if case .warning = SevenZipError.map(exitCode: 1, stderr: "x", stdout: "")! {} else {
            XCTFail("Code 1 muss Warnung sein")
        }
    }

    func testWrongPasswordDetection() {
        let err = SevenZipError.map(exitCode: 2, stderr: "ERROR: Wrong password", stdout: "")
        XCTAssertEqual(err, .wrongPassword)
    }

    func testCorruptArchiveDetection() {
        let err = SevenZipError.map(exitCode: 2, stderr: "ERROR: Headers Error", stdout: "")
        XCTAssertEqual(err, .corruptArchive)
    }

    func testNotAnArchive() {
        let err = SevenZipError.map(exitCode: 2, stderr: "ERROR: /tmp/x.txt : Is not archive", stdout: "")
        XCTAssertEqual(err, .notAnArchive)
    }
}

final class LocatorTests: XCTestCase {

    func testDictionaryFlag() {
        XCTAssertEqual(ArchiveFormat.dictionaryFlag("24 MB"), "24m")
        XCTAssertEqual(ArchiveFormat.dictionaryFlag("256 KB"), "256k")
    }

    func testFormatCapabilities() {
        XCTAssertTrue(ArchiveFormat.sevenZ.supportsHeaderEncryption)
        XCTAssertFalse(ArchiveFormat.zip.supportsHeaderEncryption)
        XCTAssertTrue(ArchiveFormat.zip.supportsEncryption)
        XCTAssertFalse(ArchiveFormat.gzip.supportsEncryption)
        XCTAssertTrue(ArchiveFormat.sevenZ.supportsSolid)
        XCTAssertFalse(ArchiveFormat.tar.supportsCompressionLevel)
    }

    /// Findet 7zz auf diesem System (Homebrew ist installiert).
    func testLocateSevenZip() {
        let path = SevenZipLocator.locate()
        XCTAssertNotNil(path, "7zz sollte über Homebrew installiert sein")
        if let path {
            XCTAssertTrue(path.hasSuffix("7zz"))
            XCTAssertNotNil(SevenZipLocator.version(of: path))
        }
    }
}
