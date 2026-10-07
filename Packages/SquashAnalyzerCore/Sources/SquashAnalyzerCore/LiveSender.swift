import Foundation

/// Sends only the newest value per channel (the live match, or one partij
/// of a live team match): values that pile up during a send are merged, and a
/// value that could not be sent is kept for the next try. Shared by
/// `LiveShare` and `TeamLive`; what a failure means stays with them.
@MainActor
final class LatestValueSender<Value: Sendable> {
    private var pending: [String: Value] = [:]
    private var sending: [String: Bool] = [:]

    func set(_ value: Value, for channel: String) {
        pending[channel] = value
    }

    func hasPending(_ channel: String) -> Bool { pending[channel] != nil }

    func isSending(_ channel: String) -> Bool { sending[channel] == true }

    /// Channels with something waiting
    var pendingChannels: [String] { Array(pending.keys) }

    func drop(_ channel: String) {
        pending[channel] = nil
    }

    /// Forgets what waits on every channel that starts with `prefix`
    func drop(prefix: String) {
        for channel in pendingChannels where channel.hasPrefix(prefix) { pending[channel] = nil }
    }

    /// Sends what waits on `channel` until nothing is left or a send fails
    /// (the value is then kept, unless a newer one came in). Does nothing
    /// while a send on this channel is under way: that one picks it up.
    func flush(_ channel: String, send: @MainActor (Value) async -> Bool) async {
        if sending[channel] == true { return }
        sending[channel] = true
        while let next = pending[channel] {
            pending[channel] = nil
            let ok = await send(next)
            if !ok {
                if pending[channel] == nil { pending[channel] = next }
                break
            }
        }
        sending[channel] = false
    }
}

/// The write requests to the live server, the same for a match and a team match
enum LiveWrite {
    /// A JSON PUT with the write key: the HTTP status, or nil when the
    /// request did not get through (no network)
    static func put(_ body: Data, to url: URL, key: String, transport: any LiveTransport) async -> Int? {
        do {
            let response = try await transport.send(method: "PUT", url: url,
                                                    headers: ["Content-Type": "application/json", "Authorization": "Bearer \(key)"],
                                                    body: body)
            return response.status
        } catch {
            return nil
        }
    }

    /// Deletes a live page with its key; the answer does not matter
    static func delete(_ url: URL, key: String, transport: any LiveTransport) async {
        _ = try? await transport.send(method: "DELETE", url: url, headers: ["Authorization": "Bearer \(key)"], body: nil)
    }

    static func isSuccess(_ status: Int) -> Bool { status >= 200 && status < 300 }
}
