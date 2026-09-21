import Foundation

/// Posts one request body. The only network seam of the analytics adapter, so tests never touch the network.
protocol AnalyticsHTTPTransport: Sendable {
    /// The HTTP status code of the response; throws when no response arrived.
    func post(_ body: Data, to url: URL) async throws -> Int
}

struct URLSessionAnalyticsTransport: AnalyticsHTTPTransport {
    let session: URLSession

    /// Ephemeral: no cookies, cache, or credentials are kept or sent with analytics requests.
    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func post(_ body: Data, to url: URL) async throws -> Int {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpShouldHandleCookies = false
        // Replace URLSession's defaults, which carry the app build, OS version, and preferred languages.
        request.setValue("PitStop", forHTTPHeaderField: "User-Agent")
        request.setValue("*", forHTTPHeaderField: "Accept-Language")
        request.httpBody = body
        let (_, response) = try await session.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
