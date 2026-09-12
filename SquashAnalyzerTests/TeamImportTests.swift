import XCTest
import SwiftData
import Compression
import UIKit
@testable import SquashAnalyzer

final class TeamImportTests: XCTestCase {
    // MARK: - Helpers

    /// Builds a zip in memory (stored or deflated entries). CRCs are left 0; the reader does not verify them.
    private func makeZip(_ entries: [(path: String, data: Data, deflate: Bool)]) -> Data {
        var out = Data()
        var central = Data()
        func le16(_ v: Int) -> Data { Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff)]) }
        func le32(_ v: Int) -> Data { Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)]) }

        for entry in entries {
            let name = Data(entry.path.utf8)
            let payload: Data
            if entry.deflate {
                var dst = Data(count: entry.data.count + 64)
                let n = dst.withUnsafeMutableBytes { d in
                    entry.data.withUnsafeBytes { s in
                        compression_encode_buffer(d.bindMemory(to: UInt8.self).baseAddress!, d.count,
                                                  s.bindMemory(to: UInt8.self).baseAddress!, s.count, nil, COMPRESSION_ZLIB)
                    }
                }
                payload = dst.prefix(n)
            } else {
                payload = entry.data
            }
            let method = entry.deflate ? 8 : 0
            let offset = out.count
            out += le32(0x04034b50) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0)
            out += le32(0) + le32(payload.count) + le32(entry.data.count) + le16(name.count) + le16(0)
            out += name + payload
            central += le32(0x02014b50) + le16(20) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0)
            central += le32(0) + le32(payload.count) + le32(entry.data.count) + le16(name.count) + le16(0) + le16(0)
            central += le16(0) + le16(0) + le32(0) + le32(offset) + name
        }
        let centralOffset = out.count
        out += central
        out += le32(0x06054b50) + le16(0) + le16(0) + le16(entries.count) + le16(entries.count)
        out += le32(central.count) + le32(centralOffset) + le16(0)
        return out
    }

    private func jpeg(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).jpegData(withCompressionQuality: 0.9) { ctx in
            UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: Schema(versionedSchema: SquashAnalyzerCurrentSchema.self),
                                  migrationPlan: SquashAnalyzerMigrationPlan.self, configurations: [config])
    }

    // MARK: - Zip

    func testZipReaderHandlesStoredAndDeflatedEntriesAndSkipsMacJunk() throws {
        let text = Data(String(repeating: "squash ", count: 200).utf8)
        let zip = makeZip([
            ("team/", Data(), false),
            ("team/a.txt", Data("hello".utf8), false),
            ("team/b.txt", text, true),
            ("__MACOSX/team/._a.txt", Data([1, 2, 3]), false),
            ("team/.DS_Store", Data([0]), false),
        ])
        let archive = try ZipArchive(data: zip)
        XCTAssertEqual(archive.fileEntries.map(\.path), ["team/a.txt", "team/b.txt"])
        XCTAssertEqual(try archive.contents(of: archive.entry(named: "team/a.txt")!), Data("hello".utf8))
        XCTAssertEqual(try archive.contents(of: archive.entry(named: "team/b.txt")!), text)
    }

    func testZipReaderRejectsNonZipData() {
        XCTAssertThrowsError(try ZipArchive(data: Data("{\"players\":[]}".utf8)))
    }

    // MARK: - Import

    @MainActor
    func testImportAddsPlayersWithSquarePhotosFromWrappedFolder() throws {
        let json = """
        {"team":"Test","players":[
          {"name":" Gerd-Jan ","photo":"photos/gj.jpg","focus":["backhand","Conditie"],"notes":"Linkshandig"},
          {"name":"Paul"}
        ]}
        """
        let zip = makeZip([
            ("team/team.json", Data(json.utf8), true),
            ("team/photos/gj.jpg", jpeg(width: 300, height: 600), false),
        ])
        let container = try makeContainer()
        let result = try TeamImportService.importTeam(zipData: zip, context: container.mainContext)

        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.photos, 1)
        let players = try container.mainContext.fetch(FetchDescriptor<SavedPlayer>(sortBy: [SortDescriptor(\.name)]))
        XCTAssertEqual(players.map(\.name), ["Gerd-Jan", "Paul"])
        XCTAssertEqual(players[0].coachingFocusAreas, ["Backhand", "Conditie"])
        XCTAssertEqual(players[0].coachingNotes, "Linkshandig")
        let photo = try XCTUnwrap(players[0].photoData.flatMap(UIImage.init(data:)))
        XCTAssertEqual(photo.size.width, photo.size.height, "photo is cropped square")
        XCTAssertLessThanOrEqual(photo.size.width, PlayerPhoto.maxDimension)
        XCTAssertNil(players[1].photoData)
    }

    @MainActor
    func testImportUpdatesExistingPlayerByNameInsteadOfDuplicating() throws {
        let container = try makeContainer()
        container.mainContext.insert(SavedPlayer(name: "paul", coachingFocusAreas: ["Drop"], coachingNotes: "oud"))
        try container.mainContext.save()

        let zip = makeZip([("team.json", Data("{\"players\":[{\"name\":\"Paul\",\"photo\":\"p.jpg\"}]}".utf8), false),
                           ("p.jpg", jpeg(width: 50, height: 50), false)])
        let result = try TeamImportService.importTeam(zipData: zip, context: container.mainContext)

        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.updated, 1)
        let players = try container.mainContext.fetch(FetchDescriptor<SavedPlayer>())
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players[0].coachingFocusAreas, ["Drop"], "focus is kept when the import has none")
        XCTAssertEqual(players[0].coachingNotes, "oud", "notes are kept when the import has none")
        XCTAssertNotNil(players[0].photoData)
    }

    @MainActor
    func testImportRejectsBadFilesBeforeWritingAnything() throws {
        let container = try makeContainer()
        let cases: [(String, [(path: String, data: Data, deflate: Bool)])] = [
            ("missing team.json", [("photos/x.jpg", jpeg(width: 10, height: 10), false)]),
            ("unknown focus tag", [("team.json", Data("{\"players\":[{\"name\":\"A\",\"focus\":[\"Smash\"]}]}".utf8), false)]),
            ("missing photo", [("team.json", Data("{\"players\":[{\"name\":\"A\",\"photo\":\"nope.jpg\"}]}".utf8), false)]),
            ("photo not an image", [("team.json", Data("{\"players\":[{\"name\":\"A\",\"photo\":\"a.jpg\"}]}".utf8), false),
                                    ("a.jpg", Data("not an image".utf8), false)]),
            ("empty name", [("team.json", Data("{\"players\":[{\"name\":\"  \"}]}".utf8), false)]),
        ]
        for (label, entries) in cases {
            XCTAssertThrowsError(try TeamImportService.importTeam(zipData: makeZip(entries), context: container.mainContext), label)
        }
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SavedPlayer>()).count, 0)
    }

    // MARK: - Backup

    @MainActor
    func testBackupRoundTripsPlayerPhoto() throws {
        let container = try makeContainer()
        let photo = PlayerPhoto.normalized(jpeg(width: 40, height: 40))
        container.mainContext.insert(SavedPlayer(name: "Niels", photoData: photo))
        try container.mainContext.save()
        let players = try container.mainContext.fetch(FetchDescriptor<SavedPlayer>())
        let data = try ExportService.exportFullBackup(players: players, matches: [], standaloneGames: [])

        let restored = try makeContainer()
        let counts = try ExportService.importFullBackup(data, context: restored.mainContext)
        XCTAssertEqual(counts.players, 1)
        XCTAssertEqual(try restored.mainContext.fetch(FetchDescriptor<SavedPlayer>()).first?.photoData, photo)
    }
}
