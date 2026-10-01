import XCTest
import Foundation
@testable import SquashAnalyzerCore

final class TeamImportTests: XCTestCase {
    private func file(_ json: String) throws -> TeamImportFile {
        try TeamImport.decode(json.data(using: String.Encoding.utf8)!)
    }

    private func error(_ block: () throws -> Void) -> TeamImportError? {
        do {
            try block()
            return nil
        } catch let caught as TeamImportError {
            return caught
        } catch {
            return nil
        }
    }

    func testEntriesTrimNamesAndUseTheAppsFocusSpelling() throws {
        let team = try file(#"{"team":"Club","players":[{"name":"  Niels ","photo":"photos/n.jpg","focus":["backhand"," DROP"],"notes":"Links"},{"name":"Paul"}]}"#)
        let entries = try TeamImport.entries(of: team)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].name, "Niels")
        XCTAssertEqual(entries[0].focus, ["Backhand", "Drop"])
        XCTAssertEqual(entries[0].photoPath, "photos/n.jpg")
        XCTAssertEqual(entries[0].notes, "Links")
        XCTAssertNil(entries[1].photoPath)
        XCTAssertEqual(team.team, "Club")
    }

    func testBadFilesAreRefusedAsAWhole() throws {
        XCTAssertEqual(error { _ = try TeamImport.decode("{}".data(using: String.Encoding.utf8)!) }, TeamImportError.invalidTeamJSON)
        let noName = try file(#"{"players":[{"name":"Niels"},{"name":" "}]}"#)
        XCTAssertEqual(error { _ = try TeamImport.entries(of: noName) }, TeamImportError.emptyName(index: 1))
        let badTag = try file(#"{"players":[{"name":"Niels","focus":["Lob"]}]}"#)
        XCTAssertEqual(error { _ = try TeamImport.entries(of: badTag) }, TeamImportError.unknownFocusTag(player: "Niels", tag: "Lob"))
    }

    func testTeamJSONInsideOneFolder() {
        XCTAssertEqual(TeamImport.teamJSONPath(in: ["team/photos/a.jpg", "team/team.json", "team/old/team.json"]), "team/team.json")
        XCTAssertEqual(TeamImport.teamJSONPath(in: ["team.json"]), "team.json")
        XCTAssertNil(TeamImport.teamJSONPath(in: ["myteam.json", "photos/a.jpg"]))
        XCTAssertEqual(TeamImport.baseDirectory(ofTeamJSON: "team/team.json"), "team/")
        XCTAssertEqual(TeamImport.baseDirectory(ofTeamJSON: "team.json"), "")
    }

    func testMatchIsByNameIgnoringCase() {
        let entry = TeamImportEntry(name: "niels", focus: [], notes: nil, photoPath: nil)
        XCTAssertEqual(TeamImport.matchIndex(for: entry, in: ["Paul", " Niels "]), 1)
        XCTAssertNil(TeamImport.matchIndex(for: entry, in: ["Paul"]))
    }

    func testOnlySquashAnalyzerTeamZipsAreLinks() {
        XCTAssertNotNil(TeamImport.link(from: " https://squashanalyzer.com/teams/k7f3x9/team.zip "))
        XCTAssertNotNil(TeamImport.link(from: "https://www.squashanalyzer.com/teams/abc/All-Inn.zip"))
        XCTAssertNil(TeamImport.link(from: "http://squashanalyzer.com/teams/abc/team.zip"))
        XCTAssertNil(TeamImport.link(from: "https://example.com/teams/abc/team.zip"))
        XCTAssertNil(TeamImport.link(from: "https://squashanalyzer.com/kaart/team.zip"))
        XCTAssertNil(TeamImport.link(from: "https://squashanalyzer.com/teams/abc/team.json"))
        XCTAssertNil(TeamImport.link(from: "https://squashanalyzer.com/teams/../privacy.zip"))
    }

    func testSummaryAndZipCheck() {
        XCTAssertEqual(TeamImportResult(team: "Club", added: 2, updated: 1, photos: 3).summary, "Club · 2 nieuw · 1 bijgewerkt · 3 foto's")
        XCTAssertTrue(TeamImport.looksLikeZip("PK..rest".data(using: String.Encoding.utf8)!))
        XCTAssertFalse(TeamImport.looksLikeZip("<html>".data(using: String.Encoding.utf8)!))
    }
}
