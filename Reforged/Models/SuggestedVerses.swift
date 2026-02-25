import Foundation

// MARK: - Suggested Verse Model

struct SuggestedVerse: Identifiable {
    let id: String
    let reference: String
    let text: String
    let category: String

    init(reference: String, text: String, category: String) {
        self.id = reference
        self.reference = reference
        self.text = text
        self.category = category
    }
}

// MARK: - Suggested Verses Data

struct SuggestedVersesData {

    static let categories = ["Faith", "Salvation", "Strength", "Peace", "Love", "Hope", "Wisdom", "Trust"]

    static let allVerses: [SuggestedVerse] = [
        // Faith
        SuggestedVerse(
            reference: "Hebrews 11:1",
            text: "Now faith is the assurance of things hoped for, the conviction of things not seen.",
            category: "Faith"
        ),
        SuggestedVerse(
            reference: "Romans 10:17",
            text: "So faith comes from hearing, and hearing through the word of Christ.",
            category: "Faith"
        ),
        SuggestedVerse(
            reference: "2 Corinthians 5:7",
            text: "For we walk by faith, not by sight.",
            category: "Faith"
        ),
        SuggestedVerse(
            reference: "Mark 11:24",
            text: "Therefore I tell you, whatever you ask in prayer, believe that you have received it, and it will be yours.",
            category: "Faith"
        ),

        // Salvation
        SuggestedVerse(
            reference: "John 3:16",
            text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            category: "Salvation"
        ),
        SuggestedVerse(
            reference: "Romans 6:23",
            text: "For the wages of sin is death, but the free gift of God is eternal life in Christ Jesus our Lord.",
            category: "Salvation"
        ),
        SuggestedVerse(
            reference: "Ephesians 2:8-9",
            text: "For by grace you have been saved through faith. And this is not your own doing; it is the gift of God, not a result of works, so that no one may boast.",
            category: "Salvation"
        ),
        SuggestedVerse(
            reference: "Romans 10:9",
            text: "Because, if you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved.",
            category: "Salvation"
        ),

        // Strength
        SuggestedVerse(
            reference: "Philippians 4:13",
            text: "I can do all things through him who strengthens me.",
            category: "Strength"
        ),
        SuggestedVerse(
            reference: "Isaiah 40:31",
            text: "But they who wait for the Lord shall renew their strength; they shall mount up with wings like eagles; they shall run and not be weary; they shall walk and not faint.",
            category: "Strength"
        ),
        SuggestedVerse(
            reference: "Joshua 1:9",
            text: "Have I not commanded you? Be strong and courageous. Do not be frightened, and do not be dismayed, for the Lord your God is with you wherever you go.",
            category: "Strength"
        ),
        SuggestedVerse(
            reference: "2 Timothy 1:7",
            text: "For God gave us a spirit not of fear but of power and love and self-control.",
            category: "Strength"
        ),

        // Peace
        SuggestedVerse(
            reference: "Philippians 4:6-7",
            text: "Do not be anxious about anything, but in everything by prayer and supplication with thanksgiving let your requests be made known to God. And the peace of God, which surpasses all understanding, will guard your hearts and your minds in Christ Jesus.",
            category: "Peace"
        ),
        SuggestedVerse(
            reference: "John 14:27",
            text: "Peace I leave with you; my peace I give to you. Not as the world gives do I give to you. Let not your hearts be troubled, neither let them be afraid.",
            category: "Peace"
        ),
        SuggestedVerse(
            reference: "Isaiah 26:3",
            text: "You keep him in perfect peace whose mind is stayed on you, because he trusts in you.",
            category: "Peace"
        ),

        // Love
        SuggestedVerse(
            reference: "1 Corinthians 13:4-5",
            text: "Love is patient and kind; love does not envy or boast; it is not arrogant or rude. It does not insist on its own way; it is not irritable or resentful.",
            category: "Love"
        ),
        SuggestedVerse(
            reference: "Romans 8:38-39",
            text: "For I am sure that neither death nor life, nor angels nor rulers, nor things present nor things to come, nor powers, nor height nor depth, nor anything else in all creation, will be able to separate us from the love of God in Christ Jesus our Lord.",
            category: "Love"
        ),
        SuggestedVerse(
            reference: "1 John 4:19",
            text: "We love because he first loved us.",
            category: "Love"
        ),

        // Hope
        SuggestedVerse(
            reference: "Jeremiah 29:11",
            text: "For I know the plans I have for you, declares the Lord, plans for welfare and not for evil, to give you a future and a hope.",
            category: "Hope"
        ),
        SuggestedVerse(
            reference: "Romans 15:13",
            text: "May the God of hope fill you with all joy and peace in believing, so that by the power of the Holy Spirit you may abound in hope.",
            category: "Hope"
        ),
        SuggestedVerse(
            reference: "Romans 8:28",
            text: "And we know that for those who love God all things work together for good, for those who are called according to his purpose.",
            category: "Hope"
        ),

        // Wisdom
        SuggestedVerse(
            reference: "Proverbs 3:5-6",
            text: "Trust in the Lord with all your heart, and do not lean on your own understanding. In all your ways acknowledge him, and he will make straight your paths.",
            category: "Wisdom"
        ),
        SuggestedVerse(
            reference: "James 1:5",
            text: "If any of you lacks wisdom, let him ask God, who gives generously to all without reproach, and it will be given him.",
            category: "Wisdom"
        ),
        SuggestedVerse(
            reference: "Psalm 119:105",
            text: "Your word is a lamp to my feet and a light to my path.",
            category: "Wisdom"
        ),

        // Trust
        SuggestedVerse(
            reference: "Psalm 46:1",
            text: "God is our refuge and strength, a very present help in trouble.",
            category: "Trust"
        ),
        SuggestedVerse(
            reference: "Psalm 23:1",
            text: "The Lord is my shepherd; I shall not want.",
            category: "Trust"
        ),
        SuggestedVerse(
            reference: "Isaiah 41:10",
            text: "Fear not, for I am with you; be not dismayed, for I am your God; I will strengthen you, I will help you, I will uphold you with my righteous right hand.",
            category: "Trust"
        ),
        SuggestedVerse(
            reference: "Matthew 6:33",
            text: "But seek first the kingdom of God and his righteousness, and all these things will be added to you.",
            category: "Trust"
        ),
    ]

    static func verses(for category: String) -> [SuggestedVerse] {
        allVerses.filter { $0.category == category }
    }
}
