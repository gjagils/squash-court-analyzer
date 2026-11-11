import Foundation
import XCTest
@testable import SquashAnalyzerCore

final class ManualQuestionTests: XCTestCase {
    private final class FakeTransport: LiveTransport, @unchecked Sendable {
        var status = 200
        var reply = Data()
        var sent: Data? = nil
        var url: URL? = nil

        func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
            self.url = url
            sent = body
            return AITransportResponse(status: status, body: reply)
        }
    }

    func testAsksTheWorkerAndReadsTheAnswer() async throws {
        let transport = FakeTransport()
        transport.reply = Data("{\"answer\":\"Tik op Badges.\",\"links\":[{\"title\":\"Badges\",\"href\":\"/handleiding/iphone.html#badges\"}]}".utf8)
        let answer = try await ManualQuestion.ask("  Hoe werken badges? ", english: false, android: false, transport: transport)
        XCTAssertEqual(answer.answer, "Tik op Badges.")
        XCTAssertEqual(answer.links.first?.url?.absoluteString, "https://www.squashanalyzer.com/handleiding/iphone.html#badges")
        XCTAssertEqual(transport.url?.absoluteString, "https://www.squashanalyzer.com/api/vraag")
        let sent = String(data: transport.sent ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(sent.contains("\"question\":\"Hoe werken badges?\""))
        XCTAssertTrue(sent.contains("\"platform\":\"iphone\""))
        XCTAssertTrue(sent.contains("\"lang\":\"nl\""))
        XCTAssertTrue(sent.contains("\"source\":\"app\""))
    }

    func testBusyAndFailures() async {
        let transport = FakeTransport()
        transport.status = 429
        do {
            _ = try await ManualQuestion.ask("Hoe werkt dit?", english: true, android: true, transport: transport)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? ManualQuestionError, ManualQuestionError.busy)
        }
        transport.status = 500
        do {
            _ = try await ManualQuestion.ask("Hoe werkt dit?", english: true, android: true, transport: transport)
            XCTFail("no error")
        } catch {
            XCTAssertEqual(error as? ManualQuestionError, ManualQuestionError.failed)
        }
        XCTAssertFalse(ManualQuestion.isAskable(" a "))
        XCTAssertTrue(ManualQuestion.isAskable("Hoe?!"))
    }
}
