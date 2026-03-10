import Foundation

// MARK: - Network Retry Utility

/// Performs a URLRequest with automatic silent retry on 429 (rate-limited) and 5xx responses.
///
/// - Parameters:
///   - request: The URLRequest to execute.
///   - maxAttempts: Total number of attempts before giving up (default: 4 — up to 3 retries).
/// - Returns: `(Data, HTTPURLResponse)` from the first successful attempt.
///   On non-retriable errors the last response is returned so the caller can throw its own typed error.
/// - Throws: `CancellationError` if the task is cancelled while waiting between retries,
///   or any error thrown by URLSession itself (network unreachable, etc.).
func performWithRetry(
    _ request: URLRequest,
    maxAttempts: Int = 4
) async throws -> (Data, HTTPURLResponse) {

    var attempt = 0

    while true {
        let (data, urlResponse) = try await URLSession.shared.data(for: request)

        guard let http = urlResponse as? HTTPURLResponse else {
            // Should never happen with http(s) URLs, but handle gracefully
            throw URLError(.badServerResponse)
        }

        // 2xx — success, return immediately
        if (200...299).contains(http.statusCode) {
            return (data, http)
        }

        // Decide whether to retry:
        //   • 429 Too Many Requests — always retry
        //   • 5xx Server Error     — retry
        //   • Any other 4xx        — don't retry; return for the caller to throw
        let isRetriable = http.statusCode == 429 || http.statusCode >= 500
        guard isRetriable, attempt + 1 < maxAttempts else {
            return (data, http)     // caller checks statusCode and throws its own typed error
        }

        attempt += 1

        // Honour the Retry-After header when present (ESV API sets this on 429).
        // Fall back to exponential backoff: 1 s, 2 s, 4 s, …  capped at 30 s.
        let delay: Double
        if http.statusCode == 429,
           let retryAfterStr = http.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfterStr) {
            delay = min(seconds, 30.0)
        } else {
            delay = min(pow(2.0, Double(attempt - 1)), 30.0)    // 1, 2, 4, 8 …
        }

        if Task.isCancelled { throw CancellationError() }
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if Task.isCancelled { throw CancellationError() }
    }
}
