import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Live score op het vergrendelscherm: links lezen, alleen bekende servers,
// en de push-token registratie bij de live-server.
final class LiveFollowTests: XCTestCase {

    func testParsesViewerPageAppLinkAndBareId() {
        XCTAssertEqual(LiveFollowLink.parse("https://live.squashanalyzer.com/l/abcdefgh2345"),
                       LiveFollowTarget(id: "abcdefgh2345", server: "https://live.squashanalyzer.com"))
        XCTAssertEqual(LiveFollowLink.parse("Kijk mee: https://beta.squashanalyzer.com/l/abcdefgh2345."),
                       LiveFollowTarget(id: "abcdefgh2345", server: "https://beta.squashanalyzer.com"))
        XCTAssertEqual(LiveFollowLink.parse("squashanalyzer://volg#abcdefgh2345"),
                       LiveFollowTarget(id: "abcdefgh2345", server: "https://live.squashanalyzer.com"))
        XCTAssertEqual(LiveFollowLink.parse("squashanalyzer://volg#abcdefgh2345@squash-live-dev.gerdjan.workers.dev"),
                       LiveFollowTarget(id: "abcdefgh2345", server: "https://squash-live-dev.gerdjan.workers.dev"))
        XCTAssertEqual(LiveFollowLink.parse("abcdefgh2345"),
                       LiveFollowTarget(id: "abcdefgh2345", server: "https://live.squashanalyzer.com"))
    }

    func testRefusesUnknownServersAndBadIds() {
        XCTAssertNil(LiveFollowLink.parse("https://evil.example.com/l/abcdefgh2345"))
        XCTAssertNil(LiveFollowLink.parse("squashanalyzer://volg#abcdefgh2345@evil.example.com"))
        XCTAssertNil(LiveFollowLink.parse("squashanalyzer://volg#abcdefgh2345@other.gerdjan.workers.dev"))
        XCTAssertNil(LiveFollowLink.parse("https://live.squashanalyzer.com/t/abcdefgh2345"))
        XCTAssertNil(LiveFollowLink.parse("https://live.squashanalyzer.com/l/ABC"))
        XCTAssertNil(LiveFollowLink.parse("hallo"))
    }

    func testAppLinkRoundTrips() {
        let live = LiveFollowTarget(id: "abcdefgh2345", server: LiveFollowLink.defaultServer)
        XCTAssertEqual(live.appLink, "squashanalyzer://volg#abcdefgh2345")
        let dev = LiveFollowTarget(id: "abcdefgh2345", server: "https://squash-live-dev.gerdjan.workers.dev")
        XCTAssertEqual(LiveFollowLink.parse(dev.appLink), dev)
    }

    @MainActor
    func testFollowShowsTheStateAndRegistersTheToken() async throws {
        let transport = FakeFollowTransport()
        let presenter = FakeFollowPresenter()
        let follow = LiveFollow(transport: transport)
        follow.presenter = presenter
        let target = LiveFollowTarget(id: "abcdefgh2345", server: "https://live.squashanalyzer.com")

        try await follow.follow(target)
        XCTAssertEqual(presenter.started.count, 1)
        XCTAssertEqual(presenter.started.first?.p1, "Jan")
        XCTAssertTrue(follow.isFollowing(target))
        XCTAssertEqual(follow.title(of: target), "Jan – Piet")
        XCTAssertEqual(transport.requests.first?.method, "GET")
        XCTAssertEqual(transport.requests.first?.url, "https://live.squashanalyzer.com/api/live/abcdefgh2345")

        await follow.tokenChanged("tok1", for: target)
        await follow.tokenChanged("tok1", for: target)
        let posts = transport.requests.filter { request in request.method == "POST" }
        XCTAssertEqual(posts.count, 1, "the same token is sent once")
        XCTAssertEqual(posts.first?.url, "https://live.squashanalyzer.com/api/live/abcdefgh2345/followers")
        XCTAssertTrue(posts.first?.body.contains("\"platform\":\"ios\"") == true)
        XCTAssertTrue(posts.first?.body.contains("\"token\":\"tok1\"") == true)

        await follow.unfollow(target)
        XCTAssertFalse(follow.isFollowing(target))
        XCTAssertEqual(presenter.stopped, [target])
        XCTAssertEqual(transport.requests.last?.method, "DELETE")
    }

    @MainActor
    func testAnEndedMatchKeepsItsResultOnTheLockScreen() async throws {
        let transport = FakeFollowTransport()
        let presenter = FakeFollowPresenter()
        let follow = LiveFollow(transport: transport)
        follow.presenter = presenter
        let target = LiveFollowTarget(id: "abcdefgh2345", server: LiveFollowLink.defaultServer)
        try await follow.follow(target)
        await follow.tokenChanged("tok1", for: target)
        await follow.ended(target)
        XCTAssertFalse(follow.isFollowing(target))
        XCTAssertTrue(presenter.stopped.isEmpty, "the result stays on the lock screen")
        XCTAssertEqual(transport.requests.last?.method, "DELETE")
        XCTAssertTrue(transport.requests.last?.body.contains("\"token\":\"tok1\"") == true)
    }

    @MainActor
    func testRestoreFollowsAgainWithoutAskingTheServer() async {
        let transport = FakeFollowTransport()
        let follow = LiveFollow(transport: transport)
        follow.presenter = FakeFollowPresenter()
        let target = LiveFollowTarget(id: "abcdefgh2345", server: LiveFollowLink.defaultServer)
        follow.restore(target, title: "Jan – Piet")
        follow.restore(target)
        XCTAssertEqual(follow.following, [target])
        XCTAssertEqual(follow.title(of: target), "Jan – Piet")
        XCTAssertTrue(transport.requests.isEmpty)
        await follow.tokenChanged("tok2", for: target)
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.method, "POST")
        follow.forget(target)
        XCTAssertFalse(follow.isFollowing(target))
        XCTAssertNil(follow.title(of: target))
    }

    @MainActor
    func testAFinishedMatchCannotBeFollowed() async {
        let transport = FakeFollowTransport()
        transport.getStatus = 404
        let follow = LiveFollow(transport: transport)
        follow.presenter = FakeFollowPresenter()
        do {
            try await follow.follow(LiveFollowTarget(id: "abcdefgh2345", server: LiveFollowLink.defaultServer))
            XCTFail("a finished match throws")
        } catch {
            XCTAssertEqual(error as? LiveFollowError, LiveFollowError.notFound)
            XCTAssertEqual(LiveFollowError.notFound.message, "Deze wedstrijd is afgelopen of de link klopt niet.")
        }
    }

    @MainActor
    func testARefusedTokenTakesItOffTheLockScreen() async throws {
        let transport = FakeFollowTransport()
        transport.postStatus = 503
        let presenter = FakeFollowPresenter()
        let follow = LiveFollow(transport: transport)
        follow.presenter = presenter
        let target = LiveFollowTarget(id: "abcdefgh2345", server: LiveFollowLink.defaultServer)
        try await follow.follow(target)
        await follow.tokenChanged("tok1", for: target)
        XCTAssertFalse(follow.isFollowing(target))
        XCTAssertEqual(presenter.stopped, [target])
        XCTAssertEqual(follow.lastError, LiveFollowError.pushUnavailable)
        try await follow.follow(target)
        XCTAssertNil(follow.lastError, "a new attempt starts clean")
    }
}

struct FollowRequest {
    let method: String
    let url: String
    let body: String
}

final class FakeFollowTransport: LiveTransport, @unchecked Sendable {
    var requests: [FollowRequest] = []
    var getStatus = 200
    var postStatus = 201

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        var text = ""
        if let body { text = String(data: body, encoding: String.Encoding.utf8) ?? "" }
        requests.append(FollowRequest(method: method, url: url.absoluteString, body: text))
        if method == "GET" {
            let json = "{\"snapshot\":{\"p1\":\"Jan\",\"p2\":\"Piet\",\"bestOf\":5,\"games\":[[11,8]],\"score\":[3,2],\"gamesWon\":[1,0],\"server\":1,\"side\":\"R\",\"status\":\"playing\"},\"updatedAt\":1,\"photos\":[false,false],\"photoVersion\":0}"
            return AITransportResponse(status: getStatus, body: json.data(using: String.Encoding.utf8) ?? Data())
        }
        if method == "POST" { return AITransportResponse(status: postStatus, body: Data()) }
        return AITransportResponse(status: 204, body: Data())
    }
}

@MainActor
final class FakeFollowPresenter: LiveFollowPresenter {
    var started: [LiveSnapshot] = []
    var stopped: [LiveFollowTarget] = []
    var platform: String { "ios" }
    var usesSandbox: Bool { true }

    func start(_ target: LiveFollowTarget, snapshot: LiveSnapshot) async throws {
        started.append(snapshot)
    }

    func stop(_ target: LiveFollowTarget) async {
        stopped.append(target)
    }
}
