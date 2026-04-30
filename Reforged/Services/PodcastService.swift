import Foundation
import UserNotifications

// MARK: - PodcastService

@MainActor
final class PodcastService: NSObject, ObservableObject {
    static let shared = PodcastService()

    @Published private(set) var feed: PodcastFeed?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let rssURL = URL(string: "https://anchor.fm/s/90447f88/podcast/rss")!
    private let cacheKey = "podcast_feed_cache"
    private let lastSeenKey = "podcast_last_seen_date"

    // MARK: - Played Episodes

    private let playedKey = "podcast_played_ids"
    @Published private(set) var playedEpisodeIDs: Set<String> = []

    func markAsPlayed(_ id: String) {
        playedEpisodeIDs.insert(id)
        UserDefaults.standard.set(Array(playedEpisodeIDs), forKey: playedKey)
    }

    func markAsUnplayed(_ id: String) {
        playedEpisodeIDs.remove(id)
        UserDefaults.standard.set(Array(playedEpisodeIDs), forKey: playedKey)
    }

    func isPlayed(_ id: String) -> Bool {
        playedEpisodeIDs.contains(id)
    }

    override private init() {
        super.init()
        configureURLCache()
        if let arr = UserDefaults.standard.array(forKey: playedKey) as? [String] {
            playedEpisodeIDs = Set(arr)
        }
        loadFromCache()
    }

    private func configureURLCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 150 * 1024 * 1024,
            diskPath: nil
        )
    }

    func loadEpisodes() async {
        if let cached = feed, !cached.isStale { return }
        await fetchFeed()
    }

    func refresh() async {
        await fetchFeed()
    }

    // MARK: - Private

    private func fetchFeed() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: rssURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw PodcastError.httpError
            }
            let parsed = try parseRSS(data: data)
            feed = parsed
            saveToCache(parsed)
            checkForNewEpisodes(feed: parsed)
            prefetchArtwork(feed: parsed)
        } catch {
            self.error = error
        }
    }

    private func parseRSS(data: Data) throws -> PodcastFeed {
        let delegate = PodcastXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), delegate.parseError == nil else {
            throw PodcastError.parseError(delegate.parseError?.localizedDescription ?? parser.parserError?.localizedDescription ?? "unknown")
        }
        return PodcastFeed(
            title: delegate.feedTitle,
            description: delegate.feedDescription,
            artworkURL: delegate.feedArtworkURL,
            episodes: delegate.parsedEpisodes,
            cachedAt: Date()
        )
    }

    private func prefetchArtwork(feed: PodcastFeed) {
        // Deduplicate: collect distinct URLs in order (header first, then per-episode).
        var seen = Set<URL>()
        func enqueue(_ url: URL?) -> URL? {
            guard let url, seen.insert(url).inserted else { return nil }
            return url
        }

        // Header artwork is always eager — it's shown before any episode is tapped.
        let headerURL = enqueue(feed.artworkURL)

        // Per-episode artworks for the 15 most recent episodes.
        let episodeURLs = feed.episodes.prefix(15).compactMap { enqueue($0.imageURL ?? feed.artworkURL) }

        // Eager batch: header + first 5 episode artworks — fetched concurrently, high priority.
        let eagerURLs  = [headerURL].compactMap { $0 } + Array(episodeURLs.prefix(5))
        // Lazy batch:  episodes 6–15 — fetched sequentially at utility priority so they
        //              don't compete with the UI when the list first appears.
        let lazyURLs   = Array(episodeURLs.dropFirst(5))

        Task.detached(priority: .userInitiated) {
            await withTaskGroup(of: Void.self) { group in
                for url in eagerURLs {
                    group.addTask {
                        let req = URLRequest(url: url)
                        guard URLCache.shared.cachedResponse(for: req) == nil else { return }
                        _ = try? await URLSession.shared.data(for: req)
                    }
                }
            }
        }

        guard !lazyURLs.isEmpty else { return }
        Task.detached(priority: .utility) {
            for url in lazyURLs {
                let req = URLRequest(url: url)
                guard URLCache.shared.cachedResponse(for: req) == nil else { continue }
                _ = try? await URLSession.shared.data(for: req)
            }
        }
    }

    private func checkForNewEpisodes(feed: PodcastFeed) {
        guard SettingsManager.shared.podcastNewEpisodeNotifications else { return }
        let lastSeen = UserDefaults.standard.object(forKey: lastSeenKey) as? Date ?? .distantPast
        let newEpisodes = feed.episodes.filter { $0.pubDate > lastSeen }
        guard !newEpisodes.isEmpty else { return }
        if let latest = feed.episodes.map(\.pubDate).max() {
            UserDefaults.standard.set(latest, forKey: lastSeenKey)
        }
        NotificationManager.shared.schedulePodcastNotification(
            episodeCount: newEpisodes.count,
            title: newEpisodes.first?.title ?? ""
        )
    }

    private func saveToCache(_ feed: PodcastFeed) {
        if let data = try? JSONEncoder().encode(feed) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(PodcastFeed.self, from: data) else { return }
        feed = cached
    }
}

// MARK: - PodcastError

enum PodcastError: LocalizedError {
    case httpError
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .httpError: return "Could not reach the podcast feed."
        case .parseError(let msg): return "Failed to parse feed: \(msg)"
        }
    }
}

// MARK: - XML Parser Delegate

private final class PodcastXMLParser: NSObject, XMLParserDelegate {
    var feedTitle = ""
    var feedDescription = ""
    var feedArtworkURL: URL?
    var parsedEpisodes: [PodcastEpisode] = []
    var parseError: Error?

    private var inItem = false
    private var currentElement = ""
    private var characterBuffer = ""
    private var fields: [String: String] = [:]
    private var enclosureURL: URL?
    private var episodeImageURL: URL?

    private let dateFormatters: [DateFormatter] = {
        let numeric = DateFormatter()
        numeric.locale = Locale(identifier: "en_US_POSIX")
        numeric.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        let named = DateFormatter()
        named.locale = Locale(identifier: "en_US_POSIX")
        named.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        return [numeric, named]
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        characterBuffer = ""

        if elementName == "item" {
            inItem = true
            fields = [:]
            enclosureURL = nil
            episodeImageURL = nil
        } else if elementName == "enclosure", inItem {
            if let urlStr = attributeDict["url"], let url = URL(string: urlStr) {
                enclosureURL = url
            }
        } else if elementName == "itunes:image" {
            if let href = attributeDict["href"], let url = URL(string: href) {
                if inItem {
                    episodeImageURL = url
                } else {
                    feedArtworkURL = url
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "item" {
            buildEpisode()
            inItem = false
        } else if inItem {
            fields[elementName] = text
        } else {
            if elementName == "title" && feedTitle.isEmpty {
                feedTitle = text
            } else if elementName == "description" && feedDescription.isEmpty {
                feedDescription = text
            }
        }

        characterBuffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    private func buildEpisode() {
        guard let audioURL = enclosureURL else { return }

        let rawDate = fields["pubDate"] ?? ""
        var pubDate: Date = Date()
        for fmt in dateFormatters {
            if let d = fmt.date(from: rawDate) { pubDate = d; break }
        }

        let rawGuid = fields["guid"] ?? ""
        let id = rawGuid.isEmpty ? audioURL.absoluteString : rawGuid

        let episode = PodcastEpisode(
            id: id,
            title: fields["title"] ?? "Untitled",
            pubDate: pubDate,
            audioURL: audioURL,
            duration: fields["itunes:duration"] ?? "",
            descriptionHTML: fields["description"] ?? "",
            imageURL: episodeImageURL
        )
        parsedEpisodes.append(episode)
    }
}
