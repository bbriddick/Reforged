import Foundation

// MARK: - Learning Tracks
// All tracks ordered in a discipleship progression of growth

struct LearningTracks {

    /// All tracks in discipleship progression order:
    /// 1. Scripture Foundation → 2. Nature of God → 3. Creation & Fall → 4. Redemption → 5. Devotional Living
    static let allTracks: [Track] = {
        var tracks: [Track] = []

        // --- Phase 1: Scripture Foundation ---
        // The Bible (learn your source of truth first)
        tracks.append(contentsOf: doctrineTracks.filter { $0.id == "doctrine-bible" })

        // --- Phase 2: Know Your God ---
        // Trinity → Father → Son → Holy Spirit
        tracks.append(contentsOf: doctrineTracks.filter { $0.id == "doctrine-trinity" })
        tracks.append(contentsOf: doctrineTracks.filter { $0.id == "doctrine-father" })
        tracks.append(contentsOf: doctrineTracks.filter { $0.id == "doctrine-son" })
        tracks.append(contentsOf: doctrineTracks.filter { $0.id == "doctrine-spirit" })

        // --- Phase 3: Creation, Fall & Redemption ---
        // Creation → Humanity & Sin → Salvation → Satan
        tracks.append(contentsOf: doctrineTracksExtended.filter { $0.id == "doctrine-creation" })
        tracks.append(contentsOf: doctrineTracksExtended.filter { $0.id == "doctrine-man" })
        tracks.append(contentsOf: doctrineTracksExtended.filter { $0.id == "doctrine-salvation" })
        tracks.append(contentsOf: doctrineTracksExtended.filter { $0.id == "doctrine-satan" })

        // --- Phase 4: Devotional Living ---
        // Foundations → Faithful Living → Christian Community
        tracks.append(contentsOf: devotionalTracks.filter { $0.id == "devotional-foundations" })
        tracks.append(contentsOf: devotionalTracks.filter { $0.id == "devotional-faithful-living" })
        tracks.append(contentsOf: devotionalTracks.filter { $0.id == "devotional-christian-community" })

        return tracks
    }()
}
