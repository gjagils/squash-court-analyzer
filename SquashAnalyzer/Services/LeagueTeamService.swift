import Foundation
import SquashAnalyzerCore

// "Mijn team" parsing and the cookie-wall handling live in SquashAnalyzerCore
// (`LeagueTeamFetcher`, shared with Android); iOS only supplies the page loader.

extension LeagueTeamError: @retroactive LocalizedError {
    public var errorDescription: String? { message }
}

/// URLSession loader: an ephemeral session keeps the cookie-wall consent
/// cookie in memory for the requests that follow.
struct URLSessionLeaguePageLoader: LeaguePageLoader {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 SquashAnalyzer/2.2", "Accept-Language": "nl-NL,nl;q=0.9"]
        session = URLSession(configuration: config)
    }

    func get(_ url: URL) async throws -> LeaguePage {
        page(try await session.data(from: url))
    }

    func postForm(_ url: URL, body: String) async throws -> LeaguePage {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        return page(try await session.data(for: request))
    }

    private func page(_ result: (Data, URLResponse)) -> LeaguePage {
        let (data, response) = result
        return LeaguePage(finalURL: response.url, status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          body: String(data: data, encoding: .utf8), byteCount: data.count)
    }
}

enum LeagueTeamService {
    static let shared = LeagueTeamFetcher(loader: URLSessionLeaguePageLoader())
}
