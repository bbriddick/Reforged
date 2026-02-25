// MARK: - Doctrine Tracks

import Foundation

extension LearningTracks {

    static let doctrineTracks: [Track] = [

        // ============================================
        // TRACK 1: THE BIBLE
        // ============================================
        Track(
            id: "doctrine-bible",
            name: "The Bible",
            description: "Discover why Scripture is the inspired, authoritative Word of God and how to trust it completely",
            icon: "book.fill",
            color: "indigo",
            totalLessons: 8,
            completedLessons: 0,
            lessons: [
                // LESSON 1: What Makes the Bible Special?
                Lesson(
                    id: "bible-1",
                    trackId: "doctrine-bible",
                    title: "What Makes the Bible Special?",
                    description: "Learn why the Bible is unlike any other book ever written",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-1-1", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Timothy 3:16", text: "All Scripture is breathed out by God and profitable for teaching, for reproof, for correction, and for training in righteousness.", version: "ESV"))),
                        LessonContent(id: "bible-1-2", type: .explanation, data: .explanation(ExplanationContent(title: "God-Breathed Words", text: "The word \"inspired\" literally means \"God-breathed\" (Greek: theopneustos). This means the Bible did not originate from human ideas—it came from God Himself. While God used human authors with their own personalities and writing styles, He superintended the process so that every word they wrote was exactly what He intended. This is called verbal (every word) and plenary (completely) inspiration."))),
                        LessonContent(id: "bible-1-3", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Peter 1:20-21", text: "No prophecy of Scripture comes from someone's own interpretation. For no prophecy was ever produced by the will of man, but men spoke from God as they were carried along by the Holy Spirit.", version: "ESV"))),
                        LessonContent(id: "bible-1-4", type: .explanation, data: .explanation(ExplanationContent(title: "Carried Along by the Spirit", text: "The Holy Spirit \"carried along\" the human writers like wind filling the sails of a ship. God used about 40 different human authors over approximately 1,500 years to write the Bible. These men came from all walks of life—shepherds, kings, fishermen, doctors, and more. Yet the result is a unified message from Genesis to Revelation, pointing to Jesus Christ."))),
                        LessonContent(id: "bible-1-5", type: .question, data: .question(QuestionContent(question: "What does \"God-breathed\" (inspired) mean regarding Scripture?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "The Bible contains good human ideas about God"), AnswerChoice(id: "b", text: "God directly authored every word through human writers"), AnswerChoice(id: "c", text: "Only parts of the Bible came from God"), AnswerChoice(id: "d", text: "The Bible is just an inspiring book")], correctAnswer: "b", explanation: "God-breathed means the words of Scripture originated from God Himself, not from human invention. God used human authors but ensured every word was exactly what He intended."))),
                        LessonContent(id: "bible-1-6", type: .question, data: .question(QuestionContent(question: "According to 2 Peter 1:21, how were the Scriptures produced?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "By the will of man alone"), AnswerChoice(id: "b", text: "By church councils"), AnswerChoice(id: "c", text: "By men carried along by the Holy Spirit"), AnswerChoice(id: "d", text: "By random inspiration")], correctAnswer: "c", explanation: "Scripture was produced when men spoke from God as they were \"carried along\" by the Holy Spirit—ensuring divine authorship through human instruments."))),
                        LessonContent(id: "bible-1-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing that God authored the Bible change how you approach reading it?")))
                    ]
                ),
                // LESSON 2: The Canon of Scripture
                Lesson(
                    id: "bible-2",
                    trackId: "doctrine-bible",
                    title: "The Canon of Scripture",
                    description: "Understand why we have 66 books in the Bible",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-2-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 10:35", text: "Scripture cannot be broken.", version: "ESV"))),
                        LessonContent(id: "bible-2-2", type: .explanation, data: .explanation(ExplanationContent(title: "The 66 Books", text: "The Bible contains 66 books—39 in the Old Testament and 27 in the New Testament. These books were recognized (not decided) by the early church as being inspired by God. The word \"canon\" means \"measuring rod\" or \"standard.\" These 66 books are the complete revelation of God to mankind, and nothing should be added to or taken away from them."))),
                        LessonContent(id: "bible-2-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Revelation 22:18-19", text: "I warn everyone who hears the words of the prophecy of this book: if anyone adds to them, God will add to him the plagues described in this book, and if anyone takes away from the words of the book of this prophecy, God will take away his share in the tree of life.", version: "ESV"))),
                        LessonContent(id: "bible-2-4", type: .explanation, data: .explanation(ExplanationContent(title: "Complete and Sufficient", text: "The Bible is the supreme and final authority in faith and life, and is the sole and final source of all we believe. We do not need additional revelation beyond the 66 books. The canon is closed—God has given us everything we need for salvation, sanctification, and service in these sacred writings."))),
                        LessonContent(id: "bible-2-5", type: .question, data: .question(QuestionContent(question: "How many books are in the complete Bible?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "39 books"), AnswerChoice(id: "b", text: "27 books"), AnswerChoice(id: "c", text: "66 books"), AnswerChoice(id: "d", text: "73 books")], correctAnswer: "c", explanation: "The Bible contains 66 canonical books—39 in the Old Testament and 27 in the New Testament."))),
                        LessonContent(id: "bible-2-6", type: .question, data: .question(QuestionContent(question: "What does the word \"canon\" mean?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A weapon"), AnswerChoice(id: "b", text: "A measuring rod or standard"), AnswerChoice(id: "c", text: "A religious ritual"), AnswerChoice(id: "d", text: "An ancient book")], correctAnswer: "b", explanation: "Canon means \"measuring rod\" or \"standard\"—the 66 books are the standard by which all truth claims are measured."))),
                        LessonContent(id: "bible-2-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "Why is it important that the Bible is complete and nothing should be added to it?")))
                    ]
                ),
                // LESSON 3: The Authority of Scripture
                Lesson(
                    id: "bible-3",
                    trackId: "doctrine-bible",
                    title: "The Authority of Scripture",
                    description: "Learn why the Bible is the final word on all matters of faith and life",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-3-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 119:89", text: "Forever, O LORD, your word is firmly fixed in the heavens.", version: "ESV"))),
                        LessonContent(id: "bible-3-2", type: .explanation, data: .explanation(ExplanationContent(title: "Supreme and Final Authority", text: "Because the Bible is God's Word, it has the authority of God Himself. It is the supreme and final authority in all matters of faith (what we believe) and practice (how we live). Human traditions, church councils, personal feelings, and popular opinions must all bow to Scripture. When the Bible speaks, God speaks."))),
                        LessonContent(id: "bible-3-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Isaiah 40:8", text: "The grass withers, the flower fades, but the word of our God will stand forever.", version: "ESV"))),
                        LessonContent(id: "bible-3-4", type: .explanation, data: .explanation(ExplanationContent(title: "Unchanging Truth", text: "While culture changes and human opinions shift, God's Word remains constant. It is not subject to revision or updating. What was true 2,000 years ago is still true today. This gives us a firm foundation in an unstable world—an anchor for our souls in every storm of life."))),
                        LessonContent(id: "bible-3-5", type: .question, data: .question(QuestionContent(question: "What should be our final authority in matters of faith and life?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Church traditions"), AnswerChoice(id: "b", text: "Personal feelings"), AnswerChoice(id: "c", text: "The Bible"), AnswerChoice(id: "d", text: "Popular opinion")], correctAnswer: "c", explanation: "The Bible is the supreme and final authority in all matters of faith and practice. Everything else must be evaluated by Scripture."))),
                        LessonContent(id: "bible-3-6", type: .question, data: .question(QuestionContent(question: "According to Psalm 119:89, what is true about God's Word?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It changes with the times"), AnswerChoice(id: "b", text: "It is forever fixed and unchanging"), AnswerChoice(id: "c", text: "It is open to interpretation"), AnswerChoice(id: "d", text: "It needs updating")], correctAnswer: "b", explanation: "God's Word is \"firmly fixed in the heavens\"—eternal, unchanging, and forever settled."))),
                        LessonContent(id: "bible-3-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "Is there an area of your life where you have let something other than Scripture be your authority?")))
                    ]
                ),
                // LESSON 4: How We Got the Bible
                Lesson(
                    id: "bible-4",
                    trackId: "doctrine-bible",
                    title: "How We Got the Bible",
                    description: "Trace how Scripture was written and preserved through history",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-4-1", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Peter 1:20-21", text: "No prophecy of Scripture comes from someone's own interpretation. For no prophecy was ever produced by the will of man, but men spoke from God as they were carried along by the Holy Spirit.", version: "ESV"))),
                        LessonContent(id: "bible-4-2", type: .explanation, data: .explanation(ExplanationContent(title: "Carried Along by the Spirit", text: "God used about 40 different human authors over approximately 1,500 years to write the Bible. These men came from all walks of life—shepherds, kings, fishermen, doctors, and more. Yet the Holy Spirit \"carried them along,\" ensuring they wrote exactly what God intended. The result is a unified message from Genesis to Revelation, pointing to Jesus Christ."))),
                        LessonContent(id: "bible-4-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Matthew 5:18", text: "For truly, I say to you, until heaven and earth pass away, not an iota, not a dot, will pass from the Law until all is accomplished.", version: "ESV"))),
                        LessonContent(id: "bible-4-4", type: .explanation, data: .explanation(ExplanationContent(title: "Preserved Through the Ages", text: "God not only inspired the Scriptures but has preserved them through the centuries. Jesus promised that not even the smallest letter or stroke would be lost. Through careful copying, archaeological discoveries, and God's providence, we have confidence that our Bibles today faithfully represent the original manuscripts."))),
                        LessonContent(id: "bible-4-5", type: .question, data: .question(QuestionContent(question: "Who ultimately authored the Bible?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Only human writers"), AnswerChoice(id: "b", text: "The Holy Spirit through human authors"), AnswerChoice(id: "c", text: "Church leaders"), AnswerChoice(id: "d", text: "Unknown sources")], correctAnswer: "b", explanation: "The Holy Spirit carried human authors along, ensuring they wrote exactly what God intended. God is the ultimate author; humans were His instruments."))),
                        LessonContent(id: "bible-4-6", type: .question, data: .question(QuestionContent(question: "How many human authors did God use to write the Bible?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Just one"), AnswerChoice(id: "b", text: "About 12"), AnswerChoice(id: "c", text: "About 40"), AnswerChoice(id: "d", text: "Hundreds")], correctAnswer: "c", explanation: "God used about 40 different human authors over 1,500 years, yet produced one unified message—evidence of divine authorship."))),
                        LessonContent(id: "bible-4-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does the unity of the Bible across 40+ authors and 1,500 years strengthen your confidence in its divine origin?")))
                    ]
                ),
                // LESSON 5: The Perfection of Scripture
                Lesson(
                    id: "bible-5",
                    trackId: "doctrine-bible",
                    title: "The Perfection of Scripture",
                    description: "Discover how the Bible is perfect, complete, and sufficient",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-5-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 19:7", text: "The law of the LORD is perfect, reviving the soul; the testimony of the LORD is sure, making wise the simple.", version: "ESV"))),
                        LessonContent(id: "bible-5-2", type: .explanation, data: .explanation(ExplanationContent(title: "Perfect and Sufficient", text: "Scripture is described as perfect, sure, right, pure, clean, and true (Psalm 19:7-9). It lacks nothing we need for knowing God and living for Him. This is called the sufficiency of Scripture—we do not need additional revelation. The Bible gives us everything necessary for salvation, sanctification, and service."))),
                        LessonContent(id: "bible-5-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 19:8-11", text: "The precepts of the LORD are right, rejoicing the heart; the commandment of the LORD is pure, enlightening the eyes... More to be desired are they than gold, even much fine gold; sweeter also than honey and drippings of the honeycomb.", version: "ESV"))),
                        LessonContent(id: "bible-5-4", type: .explanation, data: .explanation(ExplanationContent(title: "More Precious Than Gold", text: "The psalmist understood that God's Word is more valuable than the greatest earthly treasures. It revives the soul, makes wise the simple, rejoices the heart, and enlightens the eyes. In Scripture we find everything we need for life and godliness—it is our greatest treasure."))),
                        LessonContent(id: "bible-5-5", type: .question, data: .question(QuestionContent(question: "What does the \"sufficiency of Scripture\" mean?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "The Bible needs to be updated"), AnswerChoice(id: "b", text: "We need additional revelations beyond the Bible"), AnswerChoice(id: "c", text: "The Bible contains everything we need for faith and godly living"), AnswerChoice(id: "d", text: "The Bible is just one of many sources of truth")], correctAnswer: "c", explanation: "The sufficiency of Scripture means the Bible contains everything necessary for knowing God, being saved, and living a godly life."))),
                        LessonContent(id: "bible-5-6", type: .question, data: .question(QuestionContent(question: "According to Psalm 19:7, what effect does God's perfect law have?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It burdens the soul"), AnswerChoice(id: "b", text: "It revives the soul"), AnswerChoice(id: "c", text: "It confuses the mind"), AnswerChoice(id: "d", text: "It has no effect")], correctAnswer: "b", explanation: "God's perfect law revives the soul—it brings spiritual life, refreshment, and restoration to those who embrace it."))),
                        LessonContent(id: "bible-5-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "In what practical way can you rely more on Scripture as your source of wisdom this week?")))
                    ]
                ),
                // LESSON 6: How to Read the Bible
                Lesson(
                    id: "bible-6",
                    trackId: "doctrine-bible",
                    title: "How to Read the Bible",
                    description: "Learn the grammatical-historical method of interpretation",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-6-1", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Timothy 2:15", text: "Do your best to present yourself to God as one approved, a worker who has no need to be ashamed, rightly handling the word of truth.", version: "ESV"))),
                        LessonContent(id: "bible-6-2", type: .explanation, data: .explanation(ExplanationContent(title: "Rightly Handling the Word", text: "We interpret the Bible using the grammatical-historical method: we look at the grammar (what the words actually say) and the historical context (what it meant to the original audience). We take the Bible literally—meaning we interpret it according to its normal, plain sense, while recognizing figures of speech and literary genres. When the Bible speaks plainly, we take it plainly."))),
                        LessonContent(id: "bible-6-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Nehemiah 8:8", text: "They read from the book, from the Law of God, clearly, and they gave the sense, so that the people understood the reading.", version: "ESV"))),
                        LessonContent(id: "bible-6-4", type: .explanation, data: .explanation(ExplanationContent(title: "Understanding the Meaning", text: "Good Bible interpretation asks: What did this passage mean to the original audience? Then it asks: How does this truth apply to us today? Context is crucial—who is speaking, to whom, when, and why. Scripture interprets Scripture—unclear passages are understood in light of clearer ones. Let the Bible explain itself."))),
                        LessonContent(id: "bible-6-5", type: .question, data: .question(QuestionContent(question: "What is the grammatical-historical method of interpretation?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Finding hidden spiritual meanings in every verse"), AnswerChoice(id: "b", text: "Interpreting based on grammar and historical context"), AnswerChoice(id: "c", text: "Letting each person decide what verses mean to them"), AnswerChoice(id: "d", text: "Only reading the New Testament")], correctAnswer: "b", explanation: "The grammatical-historical method interprets Scripture by examining what the words say (grammar) and what they meant to the original audience (historical context)."))),
                        LessonContent(id: "bible-6-6", type: .question, data: .question(QuestionContent(question: "What does it mean to take the Bible \"literally\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Ignoring all figures of speech"), AnswerChoice(id: "b", text: "Interpreting according to normal, plain sense"), AnswerChoice(id: "c", text: "Making up our own meanings"), AnswerChoice(id: "d", text: "Taking everything as poetry")], correctAnswer: "b", explanation: "Taking the Bible literally means interpreting it according to its normal, plain sense—while recognizing figures of speech and literary genres."))),
                        LessonContent(id: "bible-6-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How can understanding the original context of a passage help you apply it correctly today?")))
                    ]
                ),
                // LESSON 7: The Bible Transforms Lives
                Lesson(
                    id: "bible-7",
                    trackId: "doctrine-bible",
                    title: "The Bible Transforms Lives",
                    description: "See the power of Scripture to change hearts and minds",
                    order: 7,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-7-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Hebrews 4:12", text: "For the word of God is living and active, sharper than any two-edged sword, piercing to the division of soul and of spirit, of joints and of marrow, and discerning the thoughts and intentions of the heart.", version: "ESV"))),
                        LessonContent(id: "bible-7-2", type: .explanation, data: .explanation(ExplanationContent(title: "Living and Active", text: "The Bible is not a dead book—it is living and active! It has power to convict, convert, comfort, and transform. Through Scripture, the Holy Spirit works in our hearts to reveal sin, point us to Christ, and conform us to His image. Millions of lives throughout history have been radically changed by the power of God's Word."))),
                        LessonContent(id: "bible-7-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 17:17", text: "Sanctify them in the truth; your word is truth.", version: "ESV"))),
                        LessonContent(id: "bible-7-4", type: .explanation, data: .explanation(ExplanationContent(title: "Sanctified by Truth", text: "Jesus prayed that His followers would be sanctified—set apart and made holy—through God's Word. The Bible is the primary tool the Holy Spirit uses to grow us in Christlikeness. As we read, study, memorize, and obey Scripture, we are progressively transformed from the inside out."))),
                        LessonContent(id: "bible-7-5", type: .question, data: .question(QuestionContent(question: "Why is the Bible described as \"living and active\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It is constantly being rewritten"), AnswerChoice(id: "b", text: "It has power to transform hearts through the Holy Spirit"), AnswerChoice(id: "c", text: "It changes meaning over time"), AnswerChoice(id: "d", text: "It is just a metaphor")], correctAnswer: "b", explanation: "Scripture is living and active because through it, the Holy Spirit works to convict, convert, comfort, and transform lives."))),
                        LessonContent(id: "bible-7-6", type: .question, data: .question(QuestionContent(question: "According to John 17:17, how are believers sanctified?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Through religious rituals"), AnswerChoice(id: "b", text: "Through the truth of God's Word"), AnswerChoice(id: "c", text: "Through our own efforts"), AnswerChoice(id: "d", text: "Through church attendance alone")], correctAnswer: "b", explanation: "Jesus prayed that believers would be sanctified through truth—and He declared, \"Your word is truth.\""))),
                        LessonContent(id: "bible-7-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "Can you think of a time when a Bible verse deeply impacted your heart or changed your thinking?")))
                    ]
                ),
                // LESSON 8: Making Scripture Your Foundation
                Lesson(
                    id: "bible-8",
                    trackId: "doctrine-bible",
                    title: "Making Scripture Your Foundation",
                    description: "Commit to building your life on the solid rock of God's Word",
                    order: 8,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "bible-8-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 119:11", text: "I have stored up your word in my heart, that I might not sin against you.", version: "ESV"))),
                        LessonContent(id: "bible-8-2", type: .explanation, data: .explanation(ExplanationContent(title: "Storing Up God's Word", text: "The psalmist understood that hiding God's Word in our hearts protects us from sin. Memorizing Scripture gives us a ready defense against temptation and provides guidance when we need wisdom. Jesus Himself used Scripture to resist Satan's temptations in the wilderness (Matthew 4:1-11)."))),
                        LessonContent(id: "bible-8-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Matthew 7:24-25", text: "Everyone then who hears these words of mine and does them will be like a wise man who built his house on the rock. And the rain fell, and the floods came, and the winds blew and beat on that house, but it did not fall, because it had been founded on the rock.", version: "ESV"))),
                        LessonContent(id: "bible-8-4", type: .explanation, data: .explanation(ExplanationContent(title: "Building on the Rock", text: "Jesus compared those who hear and obey His words to a wise builder who built his house on rock. The storms came, but the house stood firm. When we read, study, memorize, and obey Scripture, we are building our lives on an unshakeable foundation. Make God's Word your daily priority!"))),
                        LessonContent(id: "bible-8-5", type: .question, data: .question(QuestionContent(question: "According to Jesus, what happens when we build our lives on His words?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "We will never face difficulties"), AnswerChoice(id: "b", text: "We will stand firm when storms come"), AnswerChoice(id: "c", text: "We will become wealthy"), AnswerChoice(id: "d", text: "We will be popular with everyone")], correctAnswer: "b", explanation: "Jesus taught that those who hear and obey His words are like a wise builder whose house stands firm when storms come (Matthew 7:24-27)."))),
                        LessonContent(id: "bible-8-6", type: .question, data: .question(QuestionContent(question: "According to Psalm 119:11, why should we store God's Word in our hearts?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "To impress others with our knowledge"), AnswerChoice(id: "b", text: "That we might not sin against God"), AnswerChoice(id: "c", text: "To pass Bible quizzes"), AnswerChoice(id: "d", text: "It has no particular purpose")], correctAnswer: "b", explanation: "Storing God's Word in our hearts protects us from sin—it gives us truth to combat temptation and wisdom for daily decisions."))),
                        LessonContent(id: "bible-8-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What is one practical step you can take this week to make Scripture a more central part of your daily life?")))
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK 2: GOD (THE TRINITY)
        // ============================================
        Track(
            id: "doctrine-trinity",
            name: "God (The Trinity)",
            description: "Explore the mystery and majesty of the one true God who exists eternally in three Persons",
            icon: "sun.max.fill",
            color: "indigo",
            totalLessons: 8,
            completedLessons: 0,
            lessons: [
                // LESSON 1: One God, Three Persons
                Lesson(
                    id: "trinity-1",
                    trackId: "doctrine-trinity",
                    title: "One God, Three Persons",
                    description: "Understand the foundational doctrine of the Trinity",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-1-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Mark 12:29-30", text: "Jesus answered, \"The most important is, 'Hear, O Israel: The Lord our God, the Lord is one. And you shall love the Lord your God with all your heart and with all your soul and with all your mind and with all your strength.'\"", version: "ESV"))),
                        LessonContent(id: "trinity-1-2", type: .explanation, data: .explanation(ExplanationContent(title: "One God", text: "We believe in one self-existent, sovereign God. There is only one true God—not many gods or competing deities. This truth sets Christianity apart from polytheism and sets the foundation for understanding who God is. When asked about the greatest commandment, Jesus began by affirming this truth: \"The Lord our God, the Lord is one.\" Everything we learn about God starts here—there is one God, and He alone deserves our complete love and devotion."))),
                        LessonContent(id: "trinity-1-3", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Corinthians 13:14", text: "The grace of the Lord Jesus Christ and the love of God and the fellowship of the Holy Spirit be with you all.", version: "ESV"))),
                        LessonContent(id: "trinity-1-4", type: .explanation, data: .explanation(ExplanationContent(title: "Three Persons", text: "This one God exists eternally in three Persons: God the Father, God the Son, and God the Holy Spirit. Each Person is fully and completely God, equal in every divine perfection, yet they are one in essence. This is not three gods (tritheism) or one God wearing three masks (modalism), but one God in three co-eternal, co-equal Persons."))),
                        LessonContent(id: "trinity-1-5", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Timothy 3:16", text: "Great indeed, we confess, is the mystery of godliness: He was manifested in the flesh, vindicated by the Spirit, seen by angels, proclaimed among the nations, believed on in the world, taken up in glory.", version: "ESV"))),
                        LessonContent(id: "trinity-1-6", type: .question, data: .question(QuestionContent(question: "What does the doctrine of the Trinity teach?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "There are three separate gods"), AnswerChoice(id: "b", text: "One God exists in three co-eternal, co-equal Persons"), AnswerChoice(id: "c", text: "God sometimes appears as Father, Son, or Spirit"), AnswerChoice(id: "d", text: "The Trinity is a contradiction")], correctAnswer: "b", explanation: "The Trinity is one God existing eternally in three Persons—Father, Son, and Holy Spirit—each fully God, yet one in essence."))),
                        LessonContent(id: "trinity-1-7", type: .question, data: .question(QuestionContent(question: "When Jesus stated the greatest commandment, what truth did He begin with?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "There are many paths to God"), AnswerChoice(id: "b", text: "The Lord our God, the Lord is one"), AnswerChoice(id: "c", text: "Love your neighbor as yourself"), AnswerChoice(id: "d", text: "Do not worship idols")], correctAnswer: "b", explanation: "In Mark 12:29, Jesus affirmed that the Lord our God is one—there is only one true God. This is the starting point for everything we believe about Him."))),
                        LessonContent(id: "trinity-1-8", type: .reflection, data: .reflection(ReflectionContent(prompt: "Why is it important that the three Persons of the Trinity are equal in every way?")))
                    ]
                ),
                // LESSON 2: God Is Spirit
                Lesson(
                    id: "trinity-2",
                    trackId: "doctrine-trinity",
                    title: "God Is Spirit",
                    description: "Learn about God's spiritual nature and what it means for worship",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-2-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 4:24", text: "God is spirit, and those who worship him must worship in spirit and truth.", version: "ESV"))),
                        LessonContent(id: "trinity-2-2", type: .explanation, data: .explanation(ExplanationContent(title: "An Eternal Spirit", text: "God is not a physical being limited by a body. He is spirit—invisible, immaterial, and not bound by space or time. When the Bible speaks of God's \"hands\" or \"eyes,\" these are figures of speech (anthropomorphisms) to help us understand Him. Because God is spirit, true worship is not about location or rituals, but about our hearts being aligned with His truth."))),
                        LessonContent(id: "trinity-2-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Colossians 1:15", text: "He is the image of the invisible God, the firstborn of all creation.", version: "ESV"))),
                        LessonContent(id: "trinity-2-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Invisible God Made Visible", text: "While God is spirit and invisible, Jesus Christ is the image of the invisible God. Through Jesus, we can know what God is like. The Son has made the Father known (John 1:18). Though no one has ever seen God directly, Jesus has revealed His character, nature, and heart to us."))),
                        LessonContent(id: "trinity-2-5", type: .question, data: .question(QuestionContent(question: "What does it mean that \"God is spirit\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God has a physical body like humans"), AnswerChoice(id: "b", text: "God is invisible and not limited by space or time"), AnswerChoice(id: "c", text: "God is a ghost"), AnswerChoice(id: "d", text: "God only exists in our minds")], correctAnswer: "b", explanation: "God is spirit means He is invisible, immaterial, and not bound by physical limitations of space or time."))),
                        LessonContent(id: "trinity-2-6", type: .question, data: .question(QuestionContent(question: "According to Colossians 1:15, who is the image of the invisible God?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Angels"), AnswerChoice(id: "b", text: "Adam"), AnswerChoice(id: "c", text: "Jesus Christ"), AnswerChoice(id: "d", text: "Moses")], correctAnswer: "c", explanation: "Jesus Christ is the image of the invisible God—through Him we can see and know what God is like."))),
                        LessonContent(id: "trinity-2-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing God is spirit change the way you think about prayer and worship?")))
                    ]
                ),
                // LESSON 3: God Is Self-Existent
                Lesson(
                    id: "trinity-3",
                    trackId: "doctrine-trinity",
                    title: "God Is Self-Existent",
                    description: "Discover that God depends on nothing outside Himself",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-3-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Exodus 3:14", text: "God said to Moses, \"I AM WHO I AM.\" And he said, \"Say this to the people of Israel: 'I AM has sent me to you.'\"", version: "ESV"))),
                        LessonContent(id: "trinity-3-2", type: .explanation, data: .explanation(ExplanationContent(title: "I AM WHO I AM", text: "When God revealed His name as \"I AM,\" He declared His self-existence. God has no beginning, no end, and no cause. He does not depend on anything or anyone for His existence. Everything else that exists depends on Him, but He depends on nothing. This is called God's aseity—He is completely self-sufficient and independent."))),
                        LessonContent(id: "trinity-3-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Exodus 6:3", text: "I appeared to Abraham, to Isaac, and to Jacob, as God Almighty, but by my name the LORD I did not make myself known to them.", version: "ESV"))),
                        LessonContent(id: "trinity-3-4", type: .explanation, data: .explanation(ExplanationContent(title: "The LORD (Yahweh)", text: "God progressively revealed Himself throughout history. To Moses, He revealed His covenant name—Yahweh (the LORD)—connected to \"I AM.\" This name speaks of His eternal, unchanging, self-existent nature. He is the same yesterday, today, and forever. We can trust Him completely because He will never change."))),
                        LessonContent(id: "trinity-3-5", type: .question, data: .question(QuestionContent(question: "What does God's name \"I AM\" reveal about Him?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God was created before everything else"), AnswerChoice(id: "b", text: "God is self-existent and depends on nothing"), AnswerChoice(id: "c", text: "God is uncertain about His identity"), AnswerChoice(id: "d", text: "God exists because we believe in Him")], correctAnswer: "b", explanation: "The name \"I AM\" reveals God's self-existence—He has no beginning, no end, and depends on nothing outside Himself."))),
                        LessonContent(id: "trinity-3-6", type: .question, data: .question(QuestionContent(question: "What is God's \"aseity\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God's anger at sin"), AnswerChoice(id: "b", text: "God's complete self-sufficiency and independence"), AnswerChoice(id: "c", text: "God's ability to create"), AnswerChoice(id: "d", text: "God's presence everywhere")], correctAnswer: "b", explanation: "Aseity refers to God's complete self-sufficiency—He depends on nothing outside Himself for His existence or attributes."))),
                        LessonContent(id: "trinity-3-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does God's self-existence give you confidence that He can be trusted completely?")))
                    ]
                ),
                // LESSON 4: God Is Sovereign
                Lesson(
                    id: "trinity-4",
                    trackId: "doctrine-trinity",
                    title: "God Is Sovereign",
                    description: "See how God rules over all creation with absolute authority",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-4-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 115:3", text: "Our God is in the heavens; he does all that he pleases.", version: "ESV"))),
                        LessonContent(id: "trinity-4-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Sovereign King", text: "God's sovereignty means He has supreme authority and power over all things. Nothing happens outside His knowledge or control. He is not anxious, surprised, or threatened by anything. While He allows human choices and even permits evil for a time, He is always working all things according to His perfect plan. We can rest in His sovereignty!"))),
                        LessonContent(id: "trinity-4-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Daniel 4:35", text: "He does according to his will among the host of heaven and among the inhabitants of the earth; and none can stay his hand or say to him, \"What have you done?\"", version: "ESV"))),
                        LessonContent(id: "trinity-4-4", type: .explanation, data: .explanation(ExplanationContent(title: "None Can Resist His Will", text: "Nebuchadnezzar learned the hard way that God is sovereign over all—including the mightiest earthly kings. No one can stop God's hand or question His actions. This truth humbles the proud and comforts the afflicted. Whatever God has purposed will come to pass, and His plans cannot be thwarted."))),
                        LessonContent(id: "trinity-4-5", type: .question, data: .question(QuestionContent(question: "What does God's sovereignty mean?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God controls some things but not others"), AnswerChoice(id: "b", text: "God has supreme authority and power over all things"), AnswerChoice(id: "c", text: "God is just one of many powerful beings"), AnswerChoice(id: "d", text: "God's plans can be thwarted by evil")], correctAnswer: "b", explanation: "God's sovereignty means He has supreme authority and power over all creation—nothing is outside His control or knowledge."))),
                        LessonContent(id: "trinity-4-6", type: .question, data: .question(QuestionContent(question: "According to Daniel 4:35, can anyone stop God's hand?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Yes, powerful kings can"), AnswerChoice(id: "b", text: "Yes, Satan can"), AnswerChoice(id: "c", text: "No, none can stay His hand"), AnswerChoice(id: "d", text: "Yes, through prayer")], correctAnswer: "c", explanation: "No one can stay God's hand or question His actions—His sovereignty is absolute over heaven and earth."))),
                        LessonContent(id: "trinity-4-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does believing in God's sovereignty help you face uncertainty or difficult circumstances?")))
                    ]
                ),
                // LESSON 5: God Is Holy
                Lesson(
                    id: "trinity-5",
                    trackId: "doctrine-trinity",
                    title: "God Is Holy",
                    description: "Stand in awe of God's perfect purity and moral excellence",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-5-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Isaiah 6:3", text: "And one called to another and said: \"Holy, holy, holy is the LORD of hosts; the whole earth is full of his glory!\"", version: "ESV"))),
                        LessonContent(id: "trinity-5-2", type: .explanation, data: .explanation(ExplanationContent(title: "Holy, Holy, Holy", text: "Holiness is the attribute that sets God apart from everything else. He is absolutely pure, without any trace of sin or imperfection. The seraphim cry \"Holy\" three times—the only attribute repeated this way—emphasizing its supreme importance. God's holiness means He cannot tolerate sin, which is why we need a Savior."))),
                        LessonContent(id: "trinity-5-3", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Peter 1:15-16", text: "But as he who called you is holy, you also be holy in all your conduct, since it is written, \"You shall be holy, for I am holy.\"", version: "ESV"))),
                        LessonContent(id: "trinity-5-4", type: .explanation, data: .explanation(ExplanationContent(title: "Called to Holiness", text: "Because God is holy, He calls His people to be holy. We are set apart for Him, called to reflect His character in our conduct. This is not about earning salvation but about becoming who we already are in Christ. Through the Spirit's power, we pursue holiness in response to God's grace."))),
                        LessonContent(id: "trinity-5-5", type: .question, data: .question(QuestionContent(question: "Why is \"holy\" repeated three times in Isaiah 6:3?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It was a copying error"), AnswerChoice(id: "b", text: "To emphasize the supreme importance of God's holiness"), AnswerChoice(id: "c", text: "To represent the Trinity"), AnswerChoice(id: "d", text: "It was a common greeting")], correctAnswer: "b", explanation: "The threefold repetition \"Holy, holy, holy\" emphasizes the supreme importance and intensity of God's holiness—it is His defining attribute."))),
                        LessonContent(id: "trinity-5-6", type: .question, data: .question(QuestionContent(question: "According to 1 Peter, why should believers be holy?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "To earn God's favor"), AnswerChoice(id: "b", text: "Because God who called them is holy"), AnswerChoice(id: "c", text: "To impress other people"), AnswerChoice(id: "d", text: "It's optional for believers")], correctAnswer: "b", explanation: "We are called to be holy because God who called us is holy—we are to reflect His character in our conduct."))),
                        LessonContent(id: "trinity-5-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How should God's holiness affect the way you live and the choices you make?")))
                    ]
                ),
                // LESSON 6: God Is Love
                Lesson(
                    id: "trinity-6",
                    trackId: "doctrine-trinity",
                    title: "God Is Love",
                    description: "Experience the infinite, unconditional love of God",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-6-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 John 4:8", text: "Anyone who does not love does not know God, because God is love.", version: "ESV"))),
                        LessonContent(id: "trinity-6-2", type: .explanation, data: .explanation(ExplanationContent(title: "God IS Love", text: "The Bible does not just say God loves—it says God IS love. Love is essential to His very nature. Even before creation, perfect love existed between the Father, Son, and Holy Spirit. God's love is not based on our worthiness; it flows from who He is. The cross is the ultimate demonstration of His love—while we were still sinners, Christ died for us."))),
                        LessonContent(id: "trinity-6-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Romans 5:8", text: "But God shows his love for us in that while we were still sinners, Christ died for us.", version: "ESV"))),
                        LessonContent(id: "trinity-6-4", type: .explanation, data: .explanation(ExplanationContent(title: "Love Demonstrated at the Cross", text: "God's love is not just words—it is action. He demonstrated His love in the most profound way possible: sending His Son to die for sinners. This was not love for the lovely but love for the unlovely. We did not earn it or deserve it; we were enemies of God. Yet He loved us anyway."))),
                        LessonContent(id: "trinity-6-5", type: .question, data: .question(QuestionContent(question: "What is the ultimate demonstration of God's love?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Creation"), AnswerChoice(id: "b", text: "The Ten Commandments"), AnswerChoice(id: "c", text: "Christ dying for us while we were sinners"), AnswerChoice(id: "d", text: "Beautiful sunsets")], correctAnswer: "c", explanation: "Romans 5:8 says, \"God shows his love for us in that while we were still sinners, Christ died for us.\" The cross is the ultimate display of God's love."))),
                        LessonContent(id: "trinity-6-6", type: .question, data: .question(QuestionContent(question: "According to 1 John 4:8, what is true about God's nature?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God sometimes loves"), AnswerChoice(id: "b", text: "God IS love—it is His very nature"), AnswerChoice(id: "c", text: "God loves only those who obey Him"), AnswerChoice(id: "d", text: "God's love must be earned")], correctAnswer: "b", explanation: "God does not merely love—God IS love. Love is essential to His very nature and flows eternally from who He is."))),
                        LessonContent(id: "trinity-6-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing that God's love is not based on your performance change how you relate to Him?")))
                    ]
                ),
                // LESSON 7: God Is Just
                Lesson(
                    id: "trinity-7",
                    trackId: "doctrine-trinity",
                    title: "God Is Just",
                    description: "Understand how God is perfectly righteous in all His judgments",
                    order: 7,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-7-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 89:14", text: "Righteousness and justice are the foundation of your throne; steadfast love and faithfulness go before you.", version: "ESV"))),
                        LessonContent(id: "trinity-7-2", type: .explanation, data: .explanation(ExplanationContent(title: "Perfect Justice", text: "God is perfectly just—He always does what is right. He never makes mistakes, plays favorites, or overlooks sin. His justice demands that sin be punished. This is why the cross was necessary: God's love provided a way of salvation, and His justice was satisfied when Jesus took our punishment. At the cross, love and justice meet perfectly."))),
                        LessonContent(id: "trinity-7-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Romans 3:26", text: "It was to show his righteousness at the present time, so that he might be just and the justifier of the one who has faith in Jesus.", version: "ESV"))),
                        LessonContent(id: "trinity-7-4", type: .explanation, data: .explanation(ExplanationContent(title: "Just and Justifier", text: "How can God be just (punishing sin) while also justifying (declaring righteous) guilty sinners? Through the cross! Jesus took the punishment we deserved, satisfying God's justice. Now God can righteously forgive all who put their faith in Jesus. God remains just while freely justifying sinners—the greatest news ever!"))),
                        LessonContent(id: "trinity-7-5", type: .question, data: .question(QuestionContent(question: "How was God's justice satisfied while also showing mercy to sinners?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God decided to overlook sin"), AnswerChoice(id: "b", text: "Jesus took our punishment on the cross"), AnswerChoice(id: "c", text: "God lowered His standards"), AnswerChoice(id: "d", text: "We have to earn forgiveness through good works")], correctAnswer: "b", explanation: "God's justice was satisfied when Jesus, the sinless Son of God, took our punishment on the cross. Justice was served, and mercy was extended."))),
                        LessonContent(id: "trinity-7-6", type: .question, data: .question(QuestionContent(question: "According to Romans 3:26, what does the cross demonstrate about God?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "That God is only loving"), AnswerChoice(id: "b", text: "That God is only just"), AnswerChoice(id: "c", text: "That God is both just and the justifier of believers"), AnswerChoice(id: "d", text: "That God is unpredictable")], correctAnswer: "c", explanation: "The cross shows that God is both just (sin must be punished) and the justifier (He freely forgives those who trust in Jesus)."))),
                        LessonContent(id: "trinity-7-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does understanding God's perfect justice increase your gratitude for salvation through Christ?")))
                    ]
                ),
                // LESSON 8: Worshiping the Triune God
                Lesson(
                    id: "trinity-8",
                    trackId: "doctrine-trinity",
                    title: "Worshiping the Triune God",
                    description: "Respond to who God is with wholehearted worship",
                    order: 8,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "trinity-8-1", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Corinthians 13:14", text: "The grace of the Lord Jesus Christ and the love of God and the fellowship of the Holy Spirit be with you all.", version: "ESV"))),
                        LessonContent(id: "trinity-8-2", type: .explanation, data: .explanation(ExplanationContent(title: "Worship the Three-in-One", text: "We worship one God in three Persons. The Father loved us and sent the Son. The Son obeyed the Father and died for us. The Spirit applies salvation and empowers us. All three Persons work together in perfect harmony for our redemption. Our worship should acknowledge and honor each Person of the Godhead while recognizing they are one God."))),
                        LessonContent(id: "trinity-8-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Matthew 28:19", text: "Go therefore and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit.", version: "ESV"))),
                        LessonContent(id: "trinity-8-4", type: .explanation, data: .explanation(ExplanationContent(title: "In the Name (Singular)", text: "Notice that Jesus said \"in the name\" (singular) of the Father, Son, and Holy Spirit—not \"names\" (plural). Three Persons, one name, one God. This Trinitarian formula in baptism reminds us that we belong to the Triune God. Our whole Christian life—from beginning to end—is lived in relationship with Father, Son, and Spirit."))),
                        LessonContent(id: "trinity-8-5", type: .question, data: .question(QuestionContent(question: "How do all three Persons of the Trinity work together in salvation?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Only the Son was involved in salvation"), AnswerChoice(id: "b", text: "The Father planned, the Son accomplished, the Spirit applies"), AnswerChoice(id: "c", text: "They each save different people"), AnswerChoice(id: "d", text: "The Spirit is not involved in salvation")], correctAnswer: "b", explanation: "The Father planned salvation, the Son accomplished it through His death and resurrection, and the Spirit applies it to believers. All three work together in perfect unity."))),
                        LessonContent(id: "trinity-8-6", type: .question, data: .question(QuestionContent(question: "In Matthew 28:19, why does Jesus say \"name\" (singular) for all three Persons?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It was a grammatical error"), AnswerChoice(id: "b", text: "Because the three Persons are one God"), AnswerChoice(id: "c", text: "It doesn't have any significance"), AnswerChoice(id: "d", text: "Because only one Person exists")], correctAnswer: "b", explanation: "Jesus uses \"name\" (singular) because the three Persons—Father, Son, and Holy Spirit—are one God with one name."))),
                        LessonContent(id: "trinity-8-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How can you more intentionally worship and thank each Person of the Trinity in your prayers this week?")))
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK 3: GOD THE FATHER
        // ============================================
        Track(
            id: "doctrine-father",
            name: "God the Father",
            description: "Know your Heavenly Father—His character, His care, and His heart for His children",
            icon: "heart.fill",
            color: "indigo",
            totalLessons: 6,
            completedLessons: 0,
            lessons: [
                // LESSON 1: The Flawless Character of the Father
                Lesson(
                    id: "father-1",
                    trackId: "doctrine-father",
                    title: "The Flawless Character of the Father",
                    description: "See the perfection and purity of God the Father",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "father-1-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Matthew 5:48", text: "You therefore must be perfect, as your heavenly Father is perfect.", version: "ESV"))),
                        LessonContent(id: "father-1-2", type: .explanation, data: .explanation(ExplanationContent(title: "A Perfect Father", text: "God the Father is flawless in character. Unlike earthly fathers who fail, the heavenly Father is absolutely perfect in every way. He never makes mistakes, never acts selfishly, and never fails to keep His promises. His character is the standard of perfection that all creation reflects and to which we are called to aspire through His grace."))),
                        LessonContent(id: "father-1-3", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Samuel 22:3", text: "My God, my rock, in whom I take refuge, my shield, and the horn of my salvation, my stronghold and my refuge, my savior; you save me from violence.", version: "ESV"))),
                        LessonContent(id: "father-1-4", type: .explanation, data: .explanation(ExplanationContent(title: "Our Rock and Refuge", text: "The Father is described as our rock, refuge, shield, and stronghold. These images speak of His unwavering protection and stability. Unlike earthly sources of security that can fail, the Father is absolutely dependable. We can trust Him completely because of His flawless character."))),
                        LessonContent(id: "father-1-5", type: .question, data: .question(QuestionContent(question: "How does the heavenly Father differ from earthly fathers?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "He is distant and uncaring"), AnswerChoice(id: "b", text: "He is flawless and never fails"), AnswerChoice(id: "c", text: "He has the same weaknesses as humans"), AnswerChoice(id: "d", text: "He only loves perfect children")], correctAnswer: "b", explanation: "Unlike earthly fathers who fail, the heavenly Father is absolutely perfect—flawless in character, never making mistakes, and always faithful."))),
                        LessonContent(id: "father-1-6", type: .question, data: .question(QuestionContent(question: "According to 2 Samuel 22:3, what is God to His people?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A distant observer"), AnswerChoice(id: "b", text: "A rock, refuge, shield, and stronghold"), AnswerChoice(id: "c", text: "An uncertain help"), AnswerChoice(id: "d", text: "A harsh judge")], correctAnswer: "b", explanation: "God is our rock, refuge, shield, stronghold, and savior—images of complete protection and unwavering security."))),
                        LessonContent(id: "father-1-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How can the truth of God's perfect fatherhood heal any wounds from imperfect earthly experiences?")))
                    ]
                ),
                // LESSON 2: The Father's Merciful Care
                Lesson(
                    id: "father-2",
                    trackId: "doctrine-father",
                    title: "The Father's Merciful Care",
                    description: "Experience the compassion of God for His creation",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "father-2-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Psalm 8:4", text: "What is man that you are mindful of him, and the son of man that you care for him?", version: "ESV"))),
                        LessonContent(id: "father-2-2", type: .explanation, data: .explanation(ExplanationContent(title: "Mindful of Us", text: "The God who created the vast universe is mindful of you! He mercifully concerns Himself with His creation. This is astounding—the infinite God cares about finite humans. He knows your struggles, your fears, your needs. He is not too busy running the universe to notice your life. He sees. He cares. He acts."))),
                        LessonContent(id: "father-2-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Matthew 6:26", text: "Look at the birds of the air: they neither sow nor reap nor gather into barns, and yet your heavenly Father feeds them. Are you not of more value than they?", version: "ESV"))),
                        LessonContent(id: "father-2-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Father Provides", text: "Jesus pointed to the birds as evidence of the Father's care. If God provides for birds, how much more will He care for His children whom He made in His image? The Father's interests include the salvation of men and their subsequent well-being. We can trust Him to meet our needs."))),
                        LessonContent(id: "father-2-5", type: .question, data: .question(QuestionContent(question: "What amazes the psalmist in Psalm 8:4?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "That God ignores humanity"), AnswerChoice(id: "b", text: "That the infinite God is mindful of finite humans"), AnswerChoice(id: "c", text: "That God is too busy for us"), AnswerChoice(id: "d", text: "That humans are unimportant")], correctAnswer: "b", explanation: "The psalmist is amazed that the God who created everything is mindful of and cares for humanity—His attention to us is astounding."))),
                        LessonContent(id: "father-2-6", type: .question, data: .question(QuestionContent(question: "According to Matthew 6:26, how does Jesus encourage trust in God's provision?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "By pointing to wealthy people"), AnswerChoice(id: "b", text: "By pointing to how God feeds the birds"), AnswerChoice(id: "c", text: "By saying we must worry constantly"), AnswerChoice(id: "d", text: "By ignoring our needs")], correctAnswer: "b", explanation: "Jesus points to the birds—if God feeds them, how much more will He care for His children who are of greater value?"))),
                        LessonContent(id: "father-2-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What current worry or need can you entrust to the Father's merciful care today?")))
                    ]
                ),
                // LESSON 3: The Father Sent His Son
                Lesson(
                    id: "father-3",
                    trackId: "doctrine-father",
                    title: "The Father Sent His Son",
                    description: "Marvel at the Father's love in giving His only Son",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "father-3-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 3:16", text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.", version: "ESV"))),
                        LessonContent(id: "father-3-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Greatest Gift", text: "The Father's love is not passive—it is active and sacrificial. He gave His most precious possession, His only begotten Son, for rebellious sinners. God's vital interests include the salvation of men. He did not spare His own Son but delivered Him up for us all. This is the measure of the Father's love!"))),
                        LessonContent(id: "father-3-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 1:14", text: "And the Word became flesh and dwelt among us, and we have seen his glory, glory as of the only Son from the Father, full of grace and truth.", version: "ESV"))),
                        LessonContent(id: "father-3-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Incarnation", text: "The Father sent the eternal Son to take on human flesh. The Word became flesh—God became man! This was the Father's plan to redeem humanity. Jesus came full of grace and truth, perfectly revealing the Father's character. If you want to know what the Father is like, look at Jesus."))),
                        LessonContent(id: "father-3-5", type: .question, data: .question(QuestionContent(question: "What does John 3:16 reveal about the Father's love?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "His love is passive and inactive"), AnswerChoice(id: "b", text: "His love led Him to give His most precious gift—His Son"), AnswerChoice(id: "c", text: "His love is only for certain people"), AnswerChoice(id: "d", text: "His love has limits")], correctAnswer: "b", explanation: "The Father's love is active and sacrificial—He gave His only Son so that whoever believes would have eternal life."))),
                        LessonContent(id: "father-3-6", type: .question, data: .question(QuestionContent(question: "According to John 1:14, what did the Son reveal about the Father?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Only His power"), AnswerChoice(id: "b", text: "His glory, full of grace and truth"), AnswerChoice(id: "c", text: "Only His judgment"), AnswerChoice(id: "d", text: "Nothing about the Father")], correctAnswer: "b", explanation: "The Son revealed the Father's glory, full of grace and truth—showing us exactly what the Father is like."))),
                        LessonContent(id: "father-3-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does the Father's willingness to give His Son affect how you view His love for you personally?")))
                    ]
                ),
                // LESSON 4: Becoming Children of the Father
                Lesson(
                    id: "father-4",
                    trackId: "doctrine-father",
                    title: "Becoming Children of the Father",
                    description: "Understand how we become part of God's family",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "father-4-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 1:12", text: "But to all who did receive him, who believed in his name, he gave the right to become children of God.", version: "ESV"))),
                        LessonContent(id: "father-4-2", type: .explanation, data: .explanation(ExplanationContent(title: "Adopted into His Family", text: "Not everyone is a child of God in the spiritual sense. We become children of God when we receive Jesus Christ by faith. At that moment, we are adopted into God's family! The Father becomes our heavenly Father—not just in title but in reality. We can call Him \"Abba, Father\" (daddy) with intimate affection and confidence."))),
                        LessonContent(id: "father-4-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Galatians 4:6", text: "And because you are sons, God has sent the Spirit of his Son into our hearts, crying, \"Abba! Father!\"", version: "ESV"))),
                        LessonContent(id: "father-4-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit of Sonship", text: "God promised to Abraham that the nations would be blessed through his seed. Those who are in Christ are Abraham's seed and heirs according to the promise. Because of this placement as a child of God, the Christian has access to the Spirit of Jesus in their hearts. The term \"Abba\" is Aramaic for father and gives the idea of \"papa\"—a term of intimate relationship."))),
                        LessonContent(id: "father-4-5", type: .question, data: .question(QuestionContent(question: "How does a person become a child of God?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Everyone is automatically a child of God"), AnswerChoice(id: "b", text: "By receiving Jesus Christ through faith"), AnswerChoice(id: "c", text: "By being born into a Christian family"), AnswerChoice(id: "d", text: "By doing enough good works")], correctAnswer: "b", explanation: "John 1:12 says we become children of God when we receive Jesus and believe in His name—it is through faith in Christ."))),
                        LessonContent(id: "father-4-6", type: .question, data: .question(QuestionContent(question: "What does \"Abba\" mean and what does it teach us?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A formal title for a distant deity"), AnswerChoice(id: "b", text: "An intimate term like \"daddy\" or \"papa\""), AnswerChoice(id: "c", text: "A name for angels"), AnswerChoice(id: "d", text: "A word for servant")], correctAnswer: "b", explanation: "Abba is an Aramaic term of intimate affection like \"daddy\" or \"papa\"—showing our close relationship with our Heavenly Father."))),
                        LessonContent(id: "father-4-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What does it mean to you personally to be able to call the Creator of the universe your Father?")))
                    ]
                ),
                // LESSON 5: The Father Desires Our Worship
                Lesson(
                    id: "father-5",
                    trackId: "doctrine-father",
                    title: "The Father Desires Our Worship",
                    description: "Learn what it means to worship the Father in spirit and truth",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "father-5-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 4:23", text: "But the hour is coming, and is now here, when the true worshipers will worship the Father in spirit and truth, for the Father is seeking such people to worship him.", version: "ESV"))),
                        LessonContent(id: "father-5-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Father Seeks Worshipers", text: "Amazingly, the Father actively seeks true worshipers! He desires a relationship with us. True worship is not about location or external rituals—it is about our hearts (\"in spirit\") and alignment with God's Word (\"in truth\"). The Father is honored when we come to Him sincerely, with hearts full of love, gratitude, and reverence."))),
                        LessonContent(id: "father-5-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Romans 12:1", text: "I appeal to you therefore, brothers, by the mercies of God, to present your bodies as a living sacrifice, holy and acceptable to God, which is your spiritual worship.", version: "ESV"))),
                        LessonContent(id: "father-5-4", type: .explanation, data: .explanation(ExplanationContent(title: "Living Sacrifices", text: "True worship extends beyond Sunday morning. The Father desires our entire lives to be an act of worship. We present our bodies—our whole selves—as living sacrifices. This is motivated not by duty but by gratitude for His mercies. Every action, every decision can be worship when offered to the Father."))),
                        LessonContent(id: "father-5-5", type: .question, data: .question(QuestionContent(question: "What does it mean to worship the Father \"in spirit and truth\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Worshiping at the right physical location"), AnswerChoice(id: "b", text: "Worshiping with sincere hearts aligned with God's Word"), AnswerChoice(id: "c", text: "Only worshiping on Sundays"), AnswerChoice(id: "d", text: "Singing only old hymns")], correctAnswer: "b", explanation: "Worshiping in spirit means with sincere, engaged hearts. Worshiping in truth means in alignment with who God truly is as revealed in Scripture."))),
                        LessonContent(id: "father-5-6", type: .question, data: .question(QuestionContent(question: "According to Romans 12:1, what is spiritual worship?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Only singing songs"), AnswerChoice(id: "b", text: "Presenting our bodies as living sacrifices"), AnswerChoice(id: "c", text: "Only praying"), AnswerChoice(id: "d", text: "Only attending church")], correctAnswer: "b", explanation: "Spiritual worship is presenting our entire selves as living sacrifices to God—our whole lives as an act of worship."))),
                        LessonContent(id: "father-5-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How can you become a more genuine worshiper who honors the Father with your whole heart?")))
                    ]
                ),
                // LESSON 6: The Father Desires Our Service
                Lesson(
                    id: "father-6",
                    trackId: "doctrine-father",
                    title: "The Father Desires Our Service",
                    description: "Serve the Father with fruitful, joy-filled obedience",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "father-6-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Romans 12:1-2", text: "I appeal to you therefore, brothers, by the mercies of God, to present your bodies as a living sacrifice, holy and acceptable to God, which is your spiritual worship. Do not be conformed to this world, but be transformed by the renewal of your mind.", version: "ESV"))),
                        LessonContent(id: "father-6-2", type: .explanation, data: .explanation(ExplanationContent(title: "Living Sacrifices", text: "The Father not only desires our worship but also our fruitful service. In light of His great mercies to us, we respond by offering our entire lives to Him—our time, talents, resources, and bodies. This is not burdensome slavery but joyful service motivated by gratitude for what He has done for us through Christ."))),
                        LessonContent(id: "father-6-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Ephesians 2:10", text: "For we are his workmanship, created in Christ Jesus for good works, which God prepared beforehand, that we should walk in them.", version: "ESV"))),
                        LessonContent(id: "father-6-4", type: .explanation, data: .explanation(ExplanationContent(title: "Created for Good Works", text: "We are God's masterpiece, created in Christ for a purpose. The Father has prepared specific good works for each of us to walk in. Our service is not random but part of His divine plan. As we serve Him, we fulfill the purpose for which we were created and bring glory to our Father in heaven."))),
                        LessonContent(id: "father-6-5", type: .question, data: .question(QuestionContent(question: "What is our motivation for serving God according to Romans 12:1?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Fear of punishment"), AnswerChoice(id: "b", text: "Earning salvation through works"), AnswerChoice(id: "c", text: "Response to God's mercies"), AnswerChoice(id: "d", text: "Impressing other people")], correctAnswer: "c", explanation: "Romans 12:1 says we serve God as a response to His mercies—gratitude for what He has done motivates our joyful obedience."))),
                        LessonContent(id: "father-6-6", type: .question, data: .question(QuestionContent(question: "According to Ephesians 2:10, what were we created for?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Just to be saved"), AnswerChoice(id: "b", text: "Good works God prepared beforehand"), AnswerChoice(id: "c", text: "Our own pleasure"), AnswerChoice(id: "d", text: "Nothing in particular")], correctAnswer: "b", explanation: "We are created in Christ Jesus for good works that God prepared beforehand for us to walk in—service is part of our purpose."))),
                        LessonContent(id: "father-6-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What is one area of your life you can offer more fully to the Father as an act of grateful worship?")))
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK 4: GOD THE SON
        // ============================================
        Track(
            id: "doctrine-son",
            name: "God the Son",
            description: "Meet Jesus Christ—fully God and fully man, Savior and Lord",
            icon: "crown.fill",
            color: "indigo",
            totalLessons: 10,
            completedLessons: 0,
            lessons: [
                // LESSON 1: The Deity of Christ
                Lesson(
                    id: "son-1",
                    trackId: "doctrine-son",
                    title: "The Deity of Christ",
                    description: "Understand that Jesus Christ is fully and completely God",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-1-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 1:1", text: "In the beginning was the Word, and the Word was with God, and the Word was God.", version: "ESV"))),
                        LessonContent(id: "son-1-2", type: .explanation, data: .explanation(ExplanationContent(title: "Jesus IS God", text: "The \"Word\" in John 1 is Jesus Christ. This verse declares His eternal existence (\"in the beginning\"), His distinct personhood (\"with God\"), and His full deity (\"was God\"). Jesus is not a lesser god, a created being, or just a good teacher. He is the absolute, eternal, sovereign God—the second Person of the Trinity."))),
                        LessonContent(id: "son-1-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 1:14", text: "And the Word became flesh and dwelt among us, and we have seen his glory, glory as of the only Son from the Father, full of grace and truth.", version: "ESV"))),
                        LessonContent(id: "son-1-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Word Became Flesh", text: "We believe in the absolute deity of the Lord Jesus Christ. The eternal Word took on human nature without ceasing to be God. He \"dwelt\" (literally \"tabernacled\") among us—God pitched His tent in our midst! He is full of grace and truth, perfectly revealing the Father to us."))),
                        LessonContent(id: "son-1-5", type: .question, data: .question(QuestionContent(question: "What does John 1:1 teach about Jesus?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Jesus was created by God"), AnswerChoice(id: "b", text: "Jesus is a lesser god"), AnswerChoice(id: "c", text: "Jesus is eternal and is fully God"), AnswerChoice(id: "d", text: "Jesus became God when He was baptized")], correctAnswer: "c", explanation: "John 1:1 declares that Jesus (the Word) existed from the beginning, was with God, and was God—affirming His eternal deity."))),
                        LessonContent(id: "son-1-6", type: .question, data: .question(QuestionContent(question: "What does \"the Word became flesh\" mean?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Jesus stopped being God"), AnswerChoice(id: "b", text: "Jesus took on human nature while remaining fully God"), AnswerChoice(id: "c", text: "Jesus only appeared to be human"), AnswerChoice(id: "d", text: "Jesus was created at His birth")], correctAnswer: "b", explanation: "The Word becoming flesh means the eternal Son took on human nature through the incarnation while remaining fully God."))),
                        LessonContent(id: "son-1-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "Why is it essential for our salvation that Jesus is fully God?")))
                    ]
                ),
                // LESSON 2: The Virgin Birth
                Lesson(
                    id: "son-2",
                    trackId: "doctrine-son",
                    title: "The Virgin Birth",
                    description: "Marvel at Christ's miraculous incarnation",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-2-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Isaiah 7:14", text: "Therefore the Lord himself will give you a sign. Behold, the virgin shall conceive and bear a son, and shall call his name Immanuel.", version: "ESV"))),
                        LessonContent(id: "son-2-2", type: .explanation, data: .explanation(ExplanationContent(title: "Prophecy Fulfilled", text: "Centuries before Christ, Isaiah prophesied that a virgin would conceive and bear a son called Immanuel (\"God with us\"). This was no ordinary birth prediction—it pointed to the miraculous incarnation of God Himself entering humanity."))),
                        LessonContent(id: "son-2-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Matthew 1:23", text: "\"Behold, the virgin shall conceive and bear a son, and they shall call his name Immanuel\" (which means, God with us).", version: "ESV"))),
                        LessonContent(id: "son-2-4", type: .explanation, data: .explanation(ExplanationContent(title: "God Became Man", text: "We believe in His incarnation by means of the virgin birth and the Holy Spirit's conception. Jesus was born of a virgin by the Holy Spirit's conception. This was not ordinary—it was the eternal Son of God taking on human flesh while remaining fully God. The virgin birth protected Jesus from inheriting Adam's sinful nature while allowing Him to be truly human."))),
                        LessonContent(id: "son-2-5", type: .question, data: .question(QuestionContent(question: "Why is the virgin birth essential to Christian doctrine?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It was just a nice story"), AnswerChoice(id: "b", text: "It enabled Jesus to be truly human yet without inherited sin"), AnswerChoice(id: "c", text: "It has no theological significance"), AnswerChoice(id: "d", text: "It was added later by the church")], correctAnswer: "b", explanation: "The virgin birth enabled Jesus to be truly human (born of a woman) while being protected from Adam's sinful nature, making Him the sinless Savior."))),
                        LessonContent(id: "son-2-6", type: .question, data: .question(QuestionContent(question: "What does \"Immanuel\" mean?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Prince of Peace"), AnswerChoice(id: "b", text: "God with us"), AnswerChoice(id: "c", text: "Mighty God"), AnswerChoice(id: "d", text: "Eternal Father")], correctAnswer: "b", explanation: "Immanuel means \"God with us\"—through Jesus, God literally came to dwell among humanity!"))),
                        LessonContent(id: "son-2-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What does it mean to you that God loved you enough to become human and enter our broken world?")))
                    ]
                ),
                // LESSON 3: The Sinless Life of Christ
                Lesson(
                    id: "son-3",
                    trackId: "doctrine-son",
                    title: "The Sinless Life of Christ",
                    description: "See how Jesus lived a perfect life in our place",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-3-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Hebrews 4:15", text: "For we do not have a high priest who is unable to sympathize with our weaknesses, but one who in every respect has been tempted as we are, yet without sin.", version: "ESV"))),
                        LessonContent(id: "son-3-2", type: .explanation, data: .explanation(ExplanationContent(title: "Tempted Yet Sinless", text: "We believe in His sinless life. Jesus faced every kind of temptation we face—yet He never sinned. Not once. Not in thought, word, or deed. This is essential because only a sinless sacrifice could pay for our sins. Jesus also understands our struggles from personal experience, which means He can sympathize with us and help us in our temptations."))),
                        LessonContent(id: "son-3-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Philippians 2:5-7", text: "Have this mind among yourselves, which is yours in Christ Jesus, who, though he was in the form of God, did not count equality with God a thing to be grasped, but emptied himself, by taking the form of a servant, being born in the likeness of men.", version: "ESV"))),
                        LessonContent(id: "son-3-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Humble Servant", text: "Though Jesus was fully God, He humbled Himself and took on the form of a servant. He lived a life of perfect obedience to the Father, demonstrating what humanity was meant to be. His perfect life provides the righteousness we need—His righteousness is credited to all who believe."))),
                        LessonContent(id: "son-3-5", type: .question, data: .question(QuestionContent(question: "Why is Jesus' sinlessness important for salvation?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It is not really important"), AnswerChoice(id: "b", text: "Only a sinless sacrifice could pay for our sins"), AnswerChoice(id: "c", text: "It proves He was not human"), AnswerChoice(id: "d", text: "It means He cannot understand our struggles")], correctAnswer: "b", explanation: "Jesus' sinlessness was essential because only a perfect, spotless sacrifice could pay the penalty for our sins and satisfy God's justice."))),
                        LessonContent(id: "son-3-6", type: .question, data: .question(QuestionContent(question: "According to Hebrews 4:15, can Jesus sympathize with our weaknesses?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "No, He was never tempted"), AnswerChoice(id: "b", text: "Yes, He was tempted in every way yet without sin"), AnswerChoice(id: "c", text: "Only with minor temptations"), AnswerChoice(id: "d", text: "He cannot relate to humans")], correctAnswer: "b", explanation: "Jesus was tempted in every respect as we are, yet without sin—He fully understands our struggles and can help us."))),
                        LessonContent(id: "son-3-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing that Jesus was tempted yet sinless encourage you when you face temptation?")))
                    ]
                ),
                // LESSON 4: The Substitutionary Death of Christ
                Lesson(
                    id: "son-4",
                    trackId: "doctrine-son",
                    title: "The Substitutionary Death of Christ",
                    description: "Understand how Jesus died in your place",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-4-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Peter 3:18", text: "For Christ also suffered once for sins, the righteous for the unrighteous, that he might bring us to God.", version: "ESV"))),
                        LessonContent(id: "son-4-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Righteous for the Unrighteous", text: "We believe in His substitutionary death as the atonement for the sins of all men. Jesus' death was substitutionary—He died in our place. The righteous One took the punishment that we, the unrighteous, deserved. This is called penal substitutionary atonement: \"penal\" because it was a punishment, \"substitutionary\" because He took our place."))),
                        LessonContent(id: "son-4-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Isaiah 53:5", text: "But he was pierced for our transgressions; he was crushed for our iniquities; upon him was the chastisement that brought us peace, and with his wounds we are healed.", version: "ESV"))),
                        LessonContent(id: "son-4-4", type: .explanation, data: .explanation(ExplanationContent(title: "Crushed for Our Iniquities", text: "Isaiah prophesied the suffering servant who would bear our sins. Jesus was pierced for our transgressions, crushed for our iniquities. The chastisement (punishment) that should have fallen on us fell on Him, bringing us peace with God. The cross was not an accident but God's plan to save sinners while satisfying His justice."))),
                        LessonContent(id: "son-4-5", type: .question, data: .question(QuestionContent(question: "What does \"substitutionary atonement\" mean?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Jesus showed us how to die bravely"), AnswerChoice(id: "b", text: "Jesus took the punishment we deserved in our place"), AnswerChoice(id: "c", text: "We still have to pay for some of our sins"), AnswerChoice(id: "d", text: "Jesus' death was an example only")], correctAnswer: "b", explanation: "Substitutionary atonement means Jesus, the righteous One, took the punishment for sin that we, the unrighteous, deserved. He died in our place."))),
                        LessonContent(id: "son-4-6", type: .question, data: .question(QuestionContent(question: "According to Isaiah 53:5, what brought us peace with God?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Our good works"), AnswerChoice(id: "b", text: "The chastisement that fell on Christ"), AnswerChoice(id: "c", text: "Religious rituals"), AnswerChoice(id: "d", text: "Our own suffering")], correctAnswer: "b", explanation: "The chastisement (punishment) that brought us peace fell on Christ—He bore what we deserved so we could have peace with God."))),
                        LessonContent(id: "son-4-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "Take a moment to thank Jesus for taking the punishment you deserved. What does His sacrifice mean to you?")))
                    ]
                ),
                // LESSON 5: The Bodily Resurrection of Christ
                Lesson(
                    id: "son-5",
                    trackId: "doctrine-son",
                    title: "The Bodily Resurrection of Christ",
                    description: "Celebrate Christ's victory over death",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-5-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Corinthians 15:3-4", text: "For I delivered to you as of first importance what I also received: that Christ died for our sins in accordance with the Scriptures, that he was buried, that he was raised on the third day in accordance with the Scriptures.", version: "ESV"))),
                        LessonContent(id: "son-5-2", type: .explanation, data: .explanation(ExplanationContent(title: "He Is Risen!", text: "We believe in His bodily resurrection from the dead. Jesus did not just spiritually rise—He bodily rose from the dead! The tomb was empty. His disciples touched Him. He ate with them. The resurrection proves that the Father accepted Jesus' sacrifice, that Jesus has power over death, and that we too will be raised. Without the resurrection, our faith would be useless (1 Corinthians 15:17)."))),
                        LessonContent(id: "son-5-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Romans 4:25", text: "Who was delivered up for our trespasses and raised for our justification.", version: "ESV"))),
                        LessonContent(id: "son-5-4", type: .explanation, data: .explanation(ExplanationContent(title: "Raised for Our Justification", text: "Jesus was delivered to death because of our sins and raised to life for our justification. The resurrection is God's declaration that Jesus' sacrifice was accepted. Because He lives, we have the assurance that our sins are forgiven and we are declared righteous before God."))),
                        LessonContent(id: "son-5-5", type: .question, data: .question(QuestionContent(question: "What does Christ's resurrection prove?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Jesus was just a good teacher"), AnswerChoice(id: "b", text: "The Father accepted Jesus' sacrifice and He has power over death"), AnswerChoice(id: "c", text: "Death is the end"), AnswerChoice(id: "d", text: "Nothing significant")], correctAnswer: "b", explanation: "The resurrection proves that God accepted Jesus' sacrifice, that Jesus conquered death, and that we too will rise!"))),
                        LessonContent(id: "son-5-6", type: .question, data: .question(QuestionContent(question: "According to Romans 4:25, why was Jesus raised?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Just to prove He was alive"), AnswerChoice(id: "b", text: "For our justification"), AnswerChoice(id: "c", text: "To start a new religion"), AnswerChoice(id: "d", text: "It was an accident")], correctAnswer: "b", explanation: "Jesus was raised for our justification—His resurrection proves that His sacrifice was accepted and we are declared righteous."))),
                        LessonContent(id: "son-5-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What difference does Christ's resurrection make in your daily life and your hope for the future?")))
                    ]
                ),
                // LESSON 6: Christ Exalted at God's Right Hand
                Lesson(
                    id: "son-6",
                    trackId: "doctrine-son",
                    title: "Christ Exalted at God's Right Hand",
                    description: "See where Jesus is now and what He is doing",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-6-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Acts 2:33", text: "Being therefore exalted at the right hand of God, and having received from the Father the promise of the Holy Spirit, he has poured out this that you yourselves are seeing and hearing.", version: "ESV"))),
                        LessonContent(id: "son-6-2", type: .explanation, data: .explanation(ExplanationContent(title: "Exalted to Glory", text: "We believe in His current exaltation to the right hand of God as Lord. After His resurrection and ascension, Jesus was exalted to the position of highest honor—the right hand of the Father. From there He poured out the Holy Spirit on His church. The one who humbled Himself is now highly exalted!"))),
                        LessonContent(id: "son-6-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Philippians 2:9-11", text: "Therefore God has highly exalted him and bestowed on him the name that is above every name, so that at the name of Jesus every knee should bow, in heaven and on earth and under the earth, and every tongue confess that Jesus Christ is Lord, to the glory of God the Father.", version: "ESV"))),
                        LessonContent(id: "son-6-4", type: .explanation, data: .explanation(ExplanationContent(title: "Every Knee Will Bow", text: "Because Jesus humbled Himself to death on a cross, God has given Him the name above every name. One day every knee will bow and every tongue confess that Jesus Christ is Lord. We can choose to bow now in worship or be compelled to bow later in judgment—but all will acknowledge Him."))),
                        LessonContent(id: "son-6-5", type: .question, data: .question(QuestionContent(question: "Where is Jesus now?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Still in the tomb"), AnswerChoice(id: "b", text: "Exalted at the right hand of God"), AnswerChoice(id: "c", text: "Nowhere—He was just a man"), AnswerChoice(id: "d", text: "Wandering the earth")], correctAnswer: "b", explanation: "After His resurrection and ascension, Jesus was exalted to the right hand of God—the position of highest honor and authority."))),
                        LessonContent(id: "son-6-6", type: .question, data: .question(QuestionContent(question: "According to Philippians 2:10-11, what will every knee eventually do?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Nothing"), AnswerChoice(id: "b", text: "Bow to Jesus and confess He is Lord"), AnswerChoice(id: "c", text: "Only believers will acknowledge Him"), AnswerChoice(id: "d", text: "Reject Him")], correctAnswer: "b", explanation: "Every knee will bow and every tongue confess that Jesus Christ is Lord—whether willingly now or compelled later, all will acknowledge Him."))),
                        LessonContent(id: "son-6-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing Jesus is exalted as Lord affect how you live under His authority today?")))
                    ]
                ),
                // LESSON 7: Christ Our Mediator
                Lesson(
                    id: "son-7",
                    trackId: "doctrine-son",
                    title: "Christ Our Mediator",
                    description: "See Jesus as the only way to the Father",
                    order: 7,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-7-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Timothy 2:5", text: "For there is one God, and there is one mediator between God and men, the man Christ Jesus.", version: "ESV"))),
                        LessonContent(id: "son-7-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Only Mediator", text: "We believe in Jesus as Mediator. A mediator brings two parties together. Sin separated us from God—an infinite gap we could never cross. Jesus, being fully God and fully man, is the perfect Mediator. He represents God to us and us to God. There is no other mediator—not Mary, not saints, not angels. Only Jesus can bring us to the Father."))),
                        LessonContent(id: "son-7-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 14:6", text: "Jesus said to him, \"I am the way, and the truth, and the life. No one comes to the Father except through me.\"", version: "ESV"))),
                        LessonContent(id: "son-7-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Only Way", text: "Jesus made an exclusive claim: He is THE way, THE truth, THE life—not A way among many. No one comes to the Father except through Him. This is not narrow-mindedness but good news—there IS a way to God, and His name is Jesus! All other paths lead to destruction, but Jesus leads to the Father."))),
                        LessonContent(id: "son-7-5", type: .question, data: .question(QuestionContent(question: "Why is Jesus the only mediator between God and man?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "There are actually many mediators"), AnswerChoice(id: "b", text: "He is both fully God and fully man"), AnswerChoice(id: "c", text: "He was chosen randomly"), AnswerChoice(id: "d", text: "He is the most popular religious figure")], correctAnswer: "b", explanation: "Jesus is the only mediator because He is both fully God and fully man—able to represent both parties and bridge the gap sin created."))),
                        LessonContent(id: "son-7-6", type: .question, data: .question(QuestionContent(question: "According to John 14:6, how many ways are there to the Father?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Many ways"), AnswerChoice(id: "b", text: "Only one—through Jesus"), AnswerChoice(id: "c", text: "Any sincere path"), AnswerChoice(id: "d", text: "Through good works")], correctAnswer: "b", explanation: "Jesus said, \"No one comes to the Father except through me.\" There is only one way to God—through Jesus Christ."))),
                        LessonContent(id: "son-7-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does Jesus being your mediator change the way you pray?")))
                    ]
                ),
                // LESSON 8: Christ Our High Priest
                Lesson(
                    id: "son-8",
                    trackId: "doctrine-son",
                    title: "Christ Our High Priest",
                    description: "Discover how Jesus continually intercedes for us",
                    order: 8,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-8-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Hebrews 7:25", text: "Consequently, he is able to save to the uttermost those who draw near to God through him, since he always lives to make intercession for them.", version: "ESV"))),
                        LessonContent(id: "son-8-2", type: .explanation, data: .explanation(ExplanationContent(title: "He Always Lives to Intercede", text: "We believe in Jesus as our High Priest. Unlike Old Testament priests who died, Jesus lives forever and continually intercedes for us. This means He is always bringing our needs before the Father, always advocating on our behalf. Because of His ongoing priesthood, He is able to save us \"to the uttermost\"—completely and forever. Nothing and no one can snatch us from His hand."))),
                        LessonContent(id: "son-8-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Hebrews 4:14-15", text: "Since then we have a great high priest who has passed through the heavens, Jesus, the Son of God, let us hold fast our confession. For we do not have a high priest who is unable to sympathize with our weaknesses, but one who in every respect has been tempted as we are, yet without sin.", version: "ESV"))),
                        LessonContent(id: "son-8-4", type: .explanation, data: .explanation(ExplanationContent(title: "A Sympathetic High Priest", text: "Our High Priest understands our weaknesses. He was tempted in every way as we are, yet without sin. He knows the struggles we face. He does not condemn us from a distance but sympathizes with us and helps us in our time of need. We can approach God's throne with confidence because of our High Priest."))),
                        LessonContent(id: "son-8-5", type: .question, data: .question(QuestionContent(question: "What does it mean that Jesus \"saves to the uttermost\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "He saves us partially"), AnswerChoice(id: "b", text: "He saves us completely and forever"), AnswerChoice(id: "c", text: "He saves only the best people"), AnswerChoice(id: "d", text: "He saves us temporarily")], correctAnswer: "b", explanation: "Jesus saves \"to the uttermost\" means He saves completely and forever—His intercession ensures our salvation is secure and eternal."))),
                        LessonContent(id: "son-8-6", type: .question, data: .question(QuestionContent(question: "What is Jesus doing right now as our High Priest?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Nothing—His work is finished"), AnswerChoice(id: "b", text: "Making intercession for us"), AnswerChoice(id: "c", text: "Sleeping"), AnswerChoice(id: "d", text: "Judging us")], correctAnswer: "b", explanation: "Jesus always lives to make intercession for us—He is continually advocating on our behalf before the Father."))),
                        LessonContent(id: "son-8-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does Jesus' ongoing intercession give you confidence about your standing with God?")))
                    ]
                ),
                // LESSON 9: Christ Our Advocate
                Lesson(
                    id: "son-9",
                    trackId: "doctrine-son",
                    title: "Christ Our Advocate",
                    description: "Find comfort in Jesus as your defender when you sin",
                    order: 9,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-9-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 John 2:1", text: "My little children, I am writing these things to you so that you may not sin. But if anyone does sin, we have an advocate with the Father, Jesus Christ the righteous.", version: "ESV"))),
                        LessonContent(id: "son-9-2", type: .explanation, data: .explanation(ExplanationContent(title: "Your Defense Attorney", text: "We believe in Jesus as our Advocate. An advocate is like a defense attorney. When we sin (and we will), Satan accuses us before God. But Jesus stands as our advocate, pointing to His finished work on the cross. He does not excuse our sin—He has already paid for it! His advocacy is based not on our goodness but on His righteousness. We can confess our sins with confidence that we are forgiven."))),
                        LessonContent(id: "son-9-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Revelation 12:10", text: "And I heard a loud voice in heaven, saying, \"Now the salvation and the power and the kingdom of our God and the authority of his Christ have come, for the accuser of our brothers has been thrown down, who accuses them day and night before our God.\"", version: "ESV"))),
                        LessonContent(id: "son-9-4", type: .explanation, data: .explanation(ExplanationContent(title: "Against the Accuser", text: "Satan is called \"the accuser of our brothers\" who accuses believers day and night before God. But we have an Advocate! When Satan points to our sins, Jesus points to His blood. When Satan says \"guilty,\" Jesus says \"paid for.\" His advocacy silences every accusation because the debt has been fully satisfied."))),
                        LessonContent(id: "son-9-5", type: .question, data: .question(QuestionContent(question: "On what basis does Jesus advocate for us when we sin?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Our good intentions"), AnswerChoice(id: "b", text: "His finished work and righteousness"), AnswerChoice(id: "c", text: "How sorry we are"), AnswerChoice(id: "d", text: "Our promises to do better")], correctAnswer: "b", explanation: "Jesus advocates for us based on His finished work on the cross and His righteousness—not our goodness or good intentions."))),
                        LessonContent(id: "son-9-6", type: .question, data: .question(QuestionContent(question: "Who is called \"the accuser of our brothers\"?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "God"), AnswerChoice(id: "b", text: "Satan"), AnswerChoice(id: "c", text: "Other Christians"), AnswerChoice(id: "d", text: "Our conscience")], correctAnswer: "b", explanation: "Satan is the accuser who brings charges against believers day and night—but Jesus our Advocate defends us with His blood."))),
                        LessonContent(id: "son-9-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing Jesus is your advocate help you approach God after you have sinned?")))
                    ]
                ),
                // LESSON 10: Christ's Imminent Return
                Lesson(
                    id: "son-10",
                    trackId: "doctrine-son",
                    title: "Christ's Imminent Return",
                    description: "Live in anticipation of Jesus coming back",
                    order: 10,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "son-10-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Thessalonians 4:16-17", text: "For the Lord himself will descend from heaven with a cry of command, with the voice of an archangel, and with the sound of the trumpet of God. And the dead in Christ will rise first. Then we who are alive, who are left, will be caught up together with them in the clouds to meet the Lord in the air.", version: "ESV"))),
                        LessonContent(id: "son-10-2", type: .explanation, data: .explanation(ExplanationContent(title: "He Is Coming Back!", text: "We believe in His imminent return to fulfill His work of redemption through final triumph over all His enemies. Jesus promised to return, and He will! His return is imminent—it could happen at any moment. When He comes, the dead in Christ will rise first, and then living believers will be \"caught up\" (raptured) to meet Him in the air. This is our blessed hope!"))),
                        LessonContent(id: "son-10-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Revelation 19:11-16", text: "Then I saw heaven opened, and behold, a white horse! The one sitting on it is called Faithful and True, and in righteousness he judges and makes war... On his robe and on his thigh he has a name written, King of kings and Lord of lords.", version: "ESV"))),
                        LessonContent(id: "son-10-4", type: .explanation, data: .explanation(ExplanationContent(title: "King of Kings", text: "Jesus will return not as a suffering servant but as a conquering King! He is King of kings and Lord of lords. He will triumph over all His enemies and establish His kingdom. We do not know when it will happen, so we should live in constant readiness and anticipation. Maranatha—come, Lord Jesus!"))),
                        LessonContent(id: "son-10-5", type: .question, data: .question(QuestionContent(question: "What does \"imminent\" mean regarding Christ's return?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "It will happen thousands of years from now"), AnswerChoice(id: "b", text: "It could happen at any moment"), AnswerChoice(id: "c", text: "We can calculate the exact date"), AnswerChoice(id: "d", text: "It is not a certainty")], correctAnswer: "b", explanation: "Imminent means Christ's return could happen at any moment—no prophecy must be fulfilled before He comes for His church."))),
                        LessonContent(id: "son-10-6", type: .question, data: .question(QuestionContent(question: "According to Revelation 19, what title is written on Jesus?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Good Teacher"), AnswerChoice(id: "b", text: "King of kings and Lord of lords"), AnswerChoice(id: "c", text: "Wise Prophet"), AnswerChoice(id: "d", text: "Just a man")], correctAnswer: "b", explanation: "Jesus returns as King of kings and Lord of lords—He is the supreme ruler over all!"))),
                        LessonContent(id: "son-10-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "If Jesus returned today, what would you want Him to find you doing?")))
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK 5: GOD THE HOLY SPIRIT
        // ============================================
        Track(
            id: "doctrine-spirit",
            name: "God the Holy Spirit",
            description: "Discover the Person and work of the Holy Spirit who lives in every believer",
            icon: "wind",
            color: "indigo",
            totalLessons: 8,
            completedLessons: 0,
            lessons: [
                // LESSON 1: The Personality of the Spirit
                Lesson(
                    id: "spirit-1",
                    trackId: "doctrine-spirit",
                    title: "The Personality of the Spirit",
                    description: "Understand that the Holy Spirit is a Person, not a force",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-1-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Ephesians 4:30", text: "And do not grieve the Holy Spirit of God, by whom you were sealed for the day of redemption.", version: "ESV"))),
                        LessonContent(id: "spirit-1-2", type: .explanation, data: .explanation(ExplanationContent(title: "A Person, Not a Force", text: "We believe in the personality of the Holy Spirit. The Holy Spirit is not an impersonal force like \"the Force\" in Star Wars. He is a Person—the third Person of the Trinity. He has a mind, emotions, and will. He can be grieved (as our verse shows), lied to, and resisted. He speaks, guides, teaches, and comforts. We relate to Him as a Person, not use Him as a power."))),
                        LessonContent(id: "spirit-1-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 16:13", text: "When the Spirit of truth comes, he will guide you into all the truth, for he will not speak on his own authority, but whatever he hears he will speak, and he will declare to you the things that are to come.", version: "ESV"))),
                        LessonContent(id: "spirit-1-4", type: .explanation, data: .explanation(ExplanationContent(title: "He Speaks and Guides", text: "Jesus referred to the Spirit using personal pronouns (\"he,\" not \"it\"). The Spirit hears, speaks, and guides—actions that require personhood. He glorifies Christ by taking what belongs to Jesus and declaring it to us. He is not an impersonal energy but a divine Person with whom we have relationship."))),
                        LessonContent(id: "spirit-1-5", type: .question, data: .question(QuestionContent(question: "How do we know the Holy Spirit is a Person?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "He is just another name for God's power"), AnswerChoice(id: "b", text: "He has mind, emotions, will and can be grieved"), AnswerChoice(id: "c", text: "The Spirit is an impersonal force"), AnswerChoice(id: "d", text: "He does not have personality")], correctAnswer: "b", explanation: "The Holy Spirit is a Person because He has a mind, emotions, and will. He can be grieved, lied to, and resisted—qualities of personhood."))),
                        LessonContent(id: "spirit-1-6", type: .question, data: .question(QuestionContent(question: "According to John 16:13, what does the Spirit do?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Nothing active"), AnswerChoice(id: "b", text: "Guides into truth, speaks, and declares"), AnswerChoice(id: "c", text: "Only observes"), AnswerChoice(id: "d", text: "Remains silent")], correctAnswer: "b", explanation: "The Spirit guides us into all truth, speaks what He hears from the Father, and declares things to come—personal actions."))),
                        LessonContent(id: "spirit-1-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How should knowing the Holy Spirit is a Person change how you relate to Him daily?")))
                    ]
                ),
                // LESSON 2: The Deity of the Spirit
                Lesson(
                    id: "spirit-2",
                    trackId: "doctrine-spirit",
                    title: "The Deity of the Spirit",
                    description: "See that the Holy Spirit is fully God",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-2-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Acts 5:3-4", text: "But Peter said, \"Ananias, why has Satan filled your heart to lie to the Holy Spirit?... You have not lied to man but to God.\"", version: "ESV"))),
                        LessonContent(id: "spirit-2-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit IS God", text: "We believe in the deity of the Holy Spirit. Peter equates lying to the Holy Spirit with lying to God—because the Holy Spirit IS God! He possesses all divine attributes: He is eternal, omnipresent, omniscient, and omnipotent. He was active in creation, in inspiring Scripture, and in the resurrection of Christ. The Holy Spirit is fully and completely God, equal with the Father and Son."))),
                        LessonContent(id: "spirit-2-3", type: .scripture, data: .scripture(ScriptureContent(reference: "2 Peter 1:21", text: "For no prophecy was ever produced by the will of man, but men spoke from God as they were carried along by the Holy Spirit.", version: "ESV"))),
                        LessonContent(id: "spirit-2-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Inspired Scripture", text: "The Holy Spirit moved holy men to pen the Scriptures. He \"carried along\" the human writers, ensuring every word was exactly what God intended. This divine authorship proves His deity—only God could ensure the perfect inspiration of His Word across centuries and multiple authors."))),
                        LessonContent(id: "spirit-2-5", type: .question, data: .question(QuestionContent(question: "What does Acts 5:3-4 reveal about the Holy Spirit?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "The Spirit is less than God"), AnswerChoice(id: "b", text: "Lying to the Spirit is lying to God—He IS God"), AnswerChoice(id: "c", text: "The Spirit is a created being"), AnswerChoice(id: "d", text: "The Spirit is just God's power")], correctAnswer: "b", explanation: "Peter says Ananias lied to the Holy Spirit, then says he lied to God—directly equating the Holy Spirit with God."))),
                        LessonContent(id: "spirit-2-6", type: .question, data: .question(QuestionContent(question: "What role did the Spirit play in producing Scripture?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "No role"), AnswerChoice(id: "b", text: "He carried along the human writers"), AnswerChoice(id: "c", text: "He dictated every word audibly"), AnswerChoice(id: "d", text: "Only a minor role")], correctAnswer: "b", explanation: "The Spirit carried along the human authors, ensuring they wrote exactly what God intended—divine inspiration through human instruments."))),
                        LessonContent(id: "spirit-2-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How should the deity of the Holy Spirit affect how you treat His promptings and convictions?")))
                    ]
                ),
                // LESSON 3: The Spirit Convicts and Regenerates
                Lesson(
                    id: "spirit-3",
                    trackId: "doctrine-spirit",
                    title: "The Spirit Convicts and Regenerates",
                    description: "Learn how the Holy Spirit brings sinners to salvation",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-3-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 16:8", text: "And when he comes, he will convict the world concerning sin and righteousness and judgment.", version: "ESV"))),
                        LessonContent(id: "spirit-3-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Convicts", text: "We believe He convicts sinners of their sin and draws them to Christ for salvation. No one comes to Christ on their own—the Holy Spirit must draw them (John 6:44). He convicts sinners of their sin, showing them their need for a Savior. He opens blind eyes to see the truth of the gospel."))),
                        LessonContent(id: "spirit-3-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 3:5-6", text: "Jesus answered, \"Truly, truly, I say to you, unless one is born of water and the Spirit, he cannot enter the kingdom of God. That which is born of the flesh is flesh, and that which is born of the Spirit is spirit.\"", version: "ESV"))),
                        LessonContent(id: "spirit-3-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Regenerates", text: "He regenerates (gives new birth to) those who believe. Salvation is entirely a work of God's grace through the Spirit. We cannot save ourselves or even believe on our own—the Spirit must give us spiritual life. This new birth is a supernatural work of the Spirit, creating a new creature in Christ."))),
                        LessonContent(id: "spirit-3-5", type: .question, data: .question(QuestionContent(question: "What does the Holy Spirit convict people of?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Only minor mistakes"), AnswerChoice(id: "b", text: "Sin, righteousness, and judgment"), AnswerChoice(id: "c", text: "Their good qualities"), AnswerChoice(id: "d", text: "Nothing—people convict themselves")], correctAnswer: "b", explanation: "The Spirit convicts the world concerning sin (their guilt), righteousness (Christ's standard), and judgment (the coming consequence)."))),
                        LessonContent(id: "spirit-3-6", type: .question, data: .question(QuestionContent(question: "According to John 3, what must happen for someone to enter God's kingdom?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Be good enough"), AnswerChoice(id: "b", text: "Be born of the Spirit"), AnswerChoice(id: "c", text: "Join a church"), AnswerChoice(id: "d", text: "Be baptized only")], correctAnswer: "b", explanation: "Jesus said we must be born of the Spirit—this new birth is essential for entering God's kingdom."))),
                        LessonContent(id: "spirit-3-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "Can you remember a time when the Holy Spirit convicted you of sin or drew you toward Christ?")))
                    ]
                ),
                // LESSON 4: The Spirit Indwells and Sanctifies
                Lesson(
                    id: "spirit-4",
                    trackId: "doctrine-spirit",
                    title: "The Spirit Indwells and Sanctifies",
                    description: "Understand how the Spirit lives in and transforms believers",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-4-1", type: .scripture, data: .scripture(ScriptureContent(reference: "1 Corinthians 6:19", text: "Or do you not know that your body is a temple of the Holy Spirit within you, whom you have from God? You are not your own.", version: "ESV"))),
                        LessonContent(id: "spirit-4-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Indwells", text: "We believe that He indwells every believer. When you trusted Christ, the Holy Spirit came to live inside you! Your body is now His temple. He is not occasionally present but permanently dwelling within. This incredible reality means God is always with you, always in you, always working in you."))),
                        LessonContent(id: "spirit-4-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Galatians 5:16-17", text: "But I say, walk by the Spirit, and you will not gratify the desires of the flesh. For the desires of the flesh are against the Spirit, and the desires of the Spirit are against the flesh.", version: "ESV"))),
                        LessonContent(id: "spirit-4-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Sanctifies", text: "We believe that He regenerates and sanctifies believing men. The indwelling Spirit is at work transforming you from the inside out. He produces fruit in your life—love, joy, peace, patience, kindness, goodness, faithfulness, gentleness, and self-control. As you walk by the Spirit, He progressively makes you more like Christ."))),
                        LessonContent(id: "spirit-4-5", type: .question, data: .question(QuestionContent(question: "According to 1 Corinthians 6:19, where does the Holy Spirit live?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Only in church buildings"), AnswerChoice(id: "b", text: "In heaven alone"), AnswerChoice(id: "c", text: "In the believer's body as His temple"), AnswerChoice(id: "d", text: "Nowhere in particular")], correctAnswer: "c", explanation: "Your body is a temple of the Holy Spirit—He permanently dwells within every believer!"))),
                        LessonContent(id: "spirit-4-6", type: .question, data: .question(QuestionContent(question: "According to Galatians 5:16, what happens when we walk by the Spirit?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "We become perfect immediately"), AnswerChoice(id: "b", text: "We will not gratify the desires of the flesh"), AnswerChoice(id: "c", text: "Nothing changes"), AnswerChoice(id: "d", text: "The flesh disappears")], correctAnswer: "b", explanation: "Walking by the Spirit enables us to overcome fleshly desires—the Spirit gives victory over sin."))),
                        LessonContent(id: "spirit-4-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does knowing the Holy Spirit lives in you affect how you treat your body and live your life?")))
                    ]
                ),
                // LESSON 5: The Spirit Seals and Secures
                Lesson(
                    id: "spirit-5",
                    trackId: "doctrine-spirit",
                    title: "The Spirit Seals and Secures",
                    description: "Find assurance in the Spirit's sealing work",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-5-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Ephesians 1:13-14", text: "In him you also, when you heard the word of truth, the gospel of your salvation, and believed in him, were sealed with the promised Holy Spirit, who is the guarantee of our inheritance until we acquire possession of it.", version: "ESV"))),
                        LessonContent(id: "spirit-5-2", type: .explanation, data: .explanation(ExplanationContent(title: "Sealed by the Spirit", text: "When you believed, you were sealed with the Holy Spirit. In ancient times, a seal marked ownership and guaranteed protection. The Spirit's seal marks you as belonging to God and guarantees your inheritance in Christ. This sealing is permanent—you belong to God forever!"))),
                        LessonContent(id: "spirit-5-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Ephesians 4:30", text: "And do not grieve the Holy Spirit of God, by whom you were sealed for the day of redemption.", version: "ESV"))),
                        LessonContent(id: "spirit-5-4", type: .explanation, data: .explanation(ExplanationContent(title: "Sealed for Redemption Day", text: "You are sealed \"for the day of redemption\"—the day when Christ returns and our salvation is complete. The Spirit is God's down payment, guaranteeing that He will complete what He started. Nothing can break this seal! Your salvation is secure because God Himself has sealed you."))),
                        LessonContent(id: "spirit-5-5", type: .question, data: .question(QuestionContent(question: "What does it mean to be \"sealed\" with the Holy Spirit?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A temporary marking"), AnswerChoice(id: "b", text: "You are marked as belonging to God with guaranteed inheritance"), AnswerChoice(id: "c", text: "It can be broken by sin"), AnswerChoice(id: "d", text: "Just a symbol with no meaning")], correctAnswer: "b", explanation: "The Spirit's seal marks you as God's possession and guarantees your inheritance—permanent security!"))),
                        LessonContent(id: "spirit-5-6", type: .question, data: .question(QuestionContent(question: "According to Ephesians 1:14, what is the Holy Spirit called?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A temporary guest"), AnswerChoice(id: "b", text: "The guarantee of our inheritance"), AnswerChoice(id: "c", text: "An uncertain promise"), AnswerChoice(id: "d", text: "A symbol only")], correctAnswer: "b", explanation: "The Spirit is the guarantee (down payment, earnest) of our inheritance—God's promise that He will complete our salvation."))),
                        LessonContent(id: "spirit-5-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How does the Spirit's sealing give you assurance about your eternal security?")))
                    ]
                ),
                // LESSON 6: The Spirit Teaches and Guides
                Lesson(
                    id: "spirit-6",
                    trackId: "doctrine-spirit",
                    title: "The Spirit Teaches and Guides",
                    description: "Learn how the Spirit illuminates Scripture and leads believers",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-6-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 14:26", text: "But the Helper, the Holy Spirit, whom the Father will send in my name, he will teach you all things and bring to your remembrance all that I have said to you.", version: "ESV"))),
                        LessonContent(id: "spirit-6-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Teaches", text: "We believe that He teaches every believer. Jesus promised that the Spirit would teach His followers and remind them of His words. The Spirit illuminates Scripture, helping us understand and apply God's Word. He is our divine Teacher, making spiritual truth real to our hearts and minds."))),
                        LessonContent(id: "spirit-6-3", type: .scripture, data: .scripture(ScriptureContent(reference: "John 16:13", text: "When the Spirit of truth comes, he will guide you into all the truth, for he will not speak on his own authority, but whatever he hears he will speak, and he will declare to you the things that are to come.", version: "ESV"))),
                        LessonContent(id: "spirit-6-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Spirit Guides", text: "We believe that He guides every believer. The Spirit is called the \"Spirit of truth\" who guides us into all truth. He does not speak on His own but communicates what He hears from the Father. He guides through Scripture, through circumstances, through the counsel of mature believers, and through inner conviction."))),
                        LessonContent(id: "spirit-6-5", type: .question, data: .question(QuestionContent(question: "According to John 14:26, what will the Spirit do for believers?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Nothing in particular"), AnswerChoice(id: "b", text: "Teach all things and bring Christ's words to remembrance"), AnswerChoice(id: "c", text: "Only convict of sin"), AnswerChoice(id: "d", text: "Remain silent")], correctAnswer: "b", explanation: "The Spirit teaches us all things and brings to remembrance what Jesus said—He is our divine Teacher."))),
                        LessonContent(id: "spirit-6-6", type: .question, data: .question(QuestionContent(question: "What is the Spirit called in John 16:13?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "The Spirit of Power"), AnswerChoice(id: "b", text: "The Spirit of Truth"), AnswerChoice(id: "c", text: "The Spirit of Law"), AnswerChoice(id: "d", text: "The Spirit of Judgment")], correctAnswer: "b", explanation: "Jesus called Him \"the Spirit of truth\" who guides us into all truth—He leads us in God's way of truth."))),
                        LessonContent(id: "spirit-6-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "How can you become more attentive to the Spirit's teaching and guidance in your daily life?")))
                    ]
                ),
                // LESSON 7: The Spirit Comforts and Empowers
                Lesson(
                    id: "spirit-7",
                    trackId: "doctrine-spirit",
                    title: "The Spirit Comforts and Empowers",
                    description: "Experience the Spirit's comfort in trials and power for service",
                    order: 7,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-7-1", type: .scripture, data: .scripture(ScriptureContent(reference: "John 14:16", text: "And I will ask the Father, and he will give you another Helper, to be with you forever.", version: "ESV"))),
                        LessonContent(id: "spirit-7-2", type: .explanation, data: .explanation(ExplanationContent(title: "The Comforter", text: "We believe that He comforts every believer. Jesus called the Spirit \"another Helper\" (Paraclete)—One called alongside to help. The Spirit is our Comforter, Counselor, and Advocate. When we are hurting, He brings comfort. When we are confused, He brings wisdom. When we are weak, He brings strength. He is with us forever!"))),
                        LessonContent(id: "spirit-7-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Acts 1:8", text: "But you will receive power when the Holy Spirit has come upon you, and you will be my witnesses in Jerusalem and in all Judea and Samaria, and to the end of the earth.", version: "ESV"))),
                        LessonContent(id: "spirit-7-4", type: .explanation, data: .explanation(ExplanationContent(title: "Power for Witness", text: "We believe that the Spirit empowers believers with gifts to serve the Lord. Jesus promised that the Spirit would give power for witness. We are not left to serve in our own strength! The Spirit empowers us to be bold witnesses, to use our spiritual gifts, and to accomplish what God has called us to do."))),
                        LessonContent(id: "spirit-7-5", type: .question, data: .question(QuestionContent(question: "What does \"Helper\" (Paraclete) mean regarding the Spirit?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A distant observer"), AnswerChoice(id: "b", text: "One called alongside to help—Comforter, Counselor, Advocate"), AnswerChoice(id: "c", text: "A temporary assistant"), AnswerChoice(id: "d", text: "Someone who judges us")], correctAnswer: "b", explanation: "Paraclete means \"one called alongside to help\"—the Spirit is our Comforter, Counselor, and Advocate, always with us."))),
                        LessonContent(id: "spirit-7-6", type: .question, data: .question(QuestionContent(question: "According to Acts 1:8, what does the Spirit give for witness?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Just information"), AnswerChoice(id: "b", text: "Power"), AnswerChoice(id: "c", text: "Money"), AnswerChoice(id: "d", text: "Nothing specific")], correctAnswer: "b", explanation: "The Spirit gives power for witness—supernatural enablement to be bold and effective in sharing Christ."))),
                        LessonContent(id: "spirit-7-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "When have you experienced the Spirit's comfort in trials or His power for service?")))
                    ]
                ),
                // LESSON 8: Being Filled with the Spirit
                Lesson(
                    id: "spirit-8",
                    trackId: "doctrine-spirit",
                    title: "Being Filled with the Spirit",
                    description: "Learn how to walk in the Spirit's fullness daily",
                    order: 8,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(id: "spirit-8-1", type: .scripture, data: .scripture(ScriptureContent(reference: "Ephesians 5:18", text: "And do not get drunk with wine, for that is debauchery, but be filled with the Spirit.", version: "ESV"))),
                        LessonContent(id: "spirit-8-2", type: .explanation, data: .explanation(ExplanationContent(title: "Continually Filled", text: "We believe that the filling of the Spirit is the continual opportunity and responsibility of every believer, assuring joy and power in service along with victory over sin. \"Be filled\" is a present continuous command—keep being filled! Unlike indwelling (which is once-for-all), filling is ongoing. We are to be continually controlled and empowered by the Spirit."))),
                        LessonContent(id: "spirit-8-3", type: .scripture, data: .scripture(ScriptureContent(reference: "Galatians 5:22-23", text: "But the fruit of the Spirit is love, joy, peace, patience, kindness, goodness, faithfulness, gentleness, self-control; against such things there is no law.", version: "ESV"))),
                        LessonContent(id: "spirit-8-4", type: .explanation, data: .explanation(ExplanationContent(title: "The Fruit of Filling", text: "When we are filled with the Spirit, His fruit becomes evident in our lives. This fruit is not produced by our effort but by His presence and control. As we yield to Him daily—through confession, surrender, and obedience—He produces love, joy, peace, and all these wonderful qualities in and through us."))),
                        LessonContent(id: "spirit-8-5", type: .question, data: .question(QuestionContent(question: "What does \"be filled with the Spirit\" command us to do?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "A one-time experience"), AnswerChoice(id: "b", text: "Continually be controlled and empowered by the Spirit"), AnswerChoice(id: "c", text: "Only for special occasions"), AnswerChoice(id: "d", text: "Optional for mature believers")], correctAnswer: "b", explanation: "The command is present continuous—keep being filled! It is an ongoing responsibility to be controlled by the Spirit."))),
                        LessonContent(id: "spirit-8-6", type: .question, data: .question(QuestionContent(question: "According to Galatians 5, what is produced when we are filled with the Spirit?", type: .multipleChoice, options: [AnswerChoice(id: "a", text: "Pride and self-righteousness"), AnswerChoice(id: "b", text: "The fruit of the Spirit: love, joy, peace, etc."), AnswerChoice(id: "c", text: "Wealth and success"), AnswerChoice(id: "d", text: "Popularity")], correctAnswer: "b", explanation: "The Spirit produces His fruit in us—love, joy, peace, patience, kindness, goodness, faithfulness, gentleness, and self-control."))),
                        LessonContent(id: "spirit-8-7", type: .reflection, data: .reflection(ReflectionContent(prompt: "What steps can you take today to be continually filled with the Holy Spirit?")))
                    ]
                )
            ]
        )
    ]
}
