// MARK: - Doctrine Tracks Extended

import Foundation

extension LearningTracks {

    static let doctrineTracksExtended: [Track] = [

        // ============================================
        // TRACK: CREATION
        // ============================================
        Track(
            id: "doctrine-creation",
            name: "Creation",
            description: "See how God spoke the universe into existence in six literal days",
            icon: "globe",
            color: "indigo",
            totalLessons: 6,
            completedLessons: 0,
            lessons: [
                // LESSON 1: God Created Everything
                Lesson(
                    id: "creation-1",
                    trackId: "doctrine-creation",
                    title: "God Created Everything",
                    description: "Understand that God is the sole Creator of all things",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "creation-1-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 1:1",
                                text: "In the beginning, God created the heavens and the earth.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-1-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 2:1-3",
                                text: "Thus the heavens and the earth were finished, and all the host of them. And on the seventh day God finished his work that he had done, and he rested on the seventh day from all his work that he had done. So God blessed the seventh day and made it holy, because on it God rested from all his work that he had done in creation.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-1-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "The Creating God",
                                text: "The Bible begins with the foundational truth that God created everything. \"The heavens and the earth\" is a Hebrew expression meaning the entire universe—everything that exists. Before creation, there was only God. He did not create from pre-existing materials; He spoke everything into existence from nothing (ex nihilo). This sets the God of the Bible apart from all false gods.\n\nWe believe that the entire universe was brought into existence by the creating act of the Triune God. This is not a mythological account but historical truth that establishes God as sovereign over all that exists. The one who creates is greater than the creation—only God can bring something from nothing."
                            ))
                        ),
                        LessonContent(
                            id: "creation-1-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What does \"God created the heavens and the earth\" mean?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "God reshaped existing materials"),
                                    AnswerChoice(id: "b", text: "God created the entire universe from nothing"),
                                    AnswerChoice(id: "c", text: "God only created the sky and ground"),
                                    AnswerChoice(id: "d", text: "Angels helped God create")
                                ],
                                correctAnswer: "b",
                                explanation: "\"The heavens and the earth\" means the entire universe. God created everything from nothing—there was no pre-existing matter."
                            ))
                        ),
                        LessonContent(
                            id: "creation-1-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Who existed before creation?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Only matter and energy"),
                                    AnswerChoice(id: "b", text: "Only the Triune God"),
                                    AnswerChoice(id: "c", text: "God and angels"),
                                    AnswerChoice(id: "d", text: "Nothing at all")
                                ],
                                correctAnswer: "b",
                                explanation: "Before creation, only the eternal Triune God existed. He brought everything else into being by His word."
                            ))
                        ),
                        LessonContent(
                            id: "creation-1-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does God being the Creator affect how you view your own purpose and value?"
                            ))
                        )
                    ]
                ),

                // LESSON 2: Six Literal Days
                Lesson(
                    id: "creation-2",
                    trackId: "doctrine-creation",
                    title: "Six Literal Days",
                    description: "Learn that creation occurred in six 24-hour periods",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "creation-2-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Exodus 20:11",
                                text: "For in six days the LORD made heaven and earth, the sea, and all that is in them, and rested on the seventh day.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-2-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 1:5",
                                text: "God called the light Day, and the darkness he called Night. And there was evening and there was morning, the first day.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-2-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Twenty-Four Hour Days",
                                text: "We believe God created in six literal twenty-four hour periods. The Hebrew word \"yom\" (day), when used with a number and \"evening and morning\" (as in Genesis 1), always refers to a normal day. God who is infinite could have created in an instant, but He chose six days to establish a pattern for our work week.\n\nThis foundational doctrine matters because it affects our understanding of the authority and clarity of Scripture. If we cannot trust the plain meaning of Genesis, how can we trust the rest of the Bible? The same God who inspired Genesis also inspired the Gospel accounts. The pattern of six days of work and one day of rest that God established in creation is repeated in the Fourth Commandment as the basis for Israel's Sabbath observance."
                            ))
                        ),
                        LessonContent(
                            id: "creation-2-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Why do we believe creation occurred in six literal days?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "The days could mean long ages"),
                                    AnswerChoice(id: "b", text: "The Hebrew text uses \"day\" with numbers and \"evening and morning\""),
                                    AnswerChoice(id: "c", text: "It does not matter how long creation took"),
                                    AnswerChoice(id: "d", text: "Science has proven it was millions of years")
                                ],
                                correctAnswer: "b",
                                explanation: "When the Hebrew word \"yom\" is used with a number and \"evening and morning\" (as in Genesis 1), it always refers to a literal 24-hour day."
                            ))
                        ),
                        LessonContent(
                            id: "creation-2-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Why does this doctrine matter for trusting Scripture?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "It does not affect anything else"),
                                    AnswerChoice(id: "b", text: "If we cannot trust Genesis plainly, we undermine all Scripture"),
                                    AnswerChoice(id: "c", text: "It is just a minor detail"),
                                    AnswerChoice(id: "d", text: "Science should interpret Scripture")
                                ],
                                correctAnswer: "b",
                                explanation: "How we interpret Genesis affects our entire approach to Scripture. If we cannot trust the plain meaning of the creation account, we undermine the authority of God's Word."
                            ))
                        ),
                        LessonContent(
                            id: "creation-2-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does believing in a literal six-day creation affect your trust in the rest of Scripture?"
                            ))
                        )
                    ]
                ),

                // LESSON 3: The Trinity in Creation
                Lesson(
                    id: "creation-3",
                    trackId: "doctrine-creation",
                    title: "The Trinity in Creation",
                    description: "See all three Persons of the Trinity active in creation",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "creation-3-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 1:1-3",
                                text: "In the beginning was the Word, and the Word was with God, and the Word was God. He was in the beginning with God. All things were made through him, and without him was not any thing made that was made.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-3-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 1:2",
                                text: "The earth was without form and void, and darkness was over the face of the deep. And the Spirit of God was hovering over the face of the waters.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-3-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "The Triune Creator",
                                text: "Creation was the work of the entire Trinity. The Father planned and commanded (Genesis 1:1). The Son (the Word) executed creation—\"all things were made through him\" (John 1:3). The Spirit was active in creation, \"hovering over the face of the waters\" (Genesis 1:2).\n\nFrom the very beginning, we see the Triune God working together in perfect harmony. The plural language in Genesis 1:26 (\"Let us make man in our image\") hints at the Trinity. Colossians 1:16 confirms that by Christ \"all things were created, in heaven and on earth, visible and invisible.\" The same Jesus who walked on earth is your Creator!"
                            ))
                        ),
                        LessonContent(
                            id: "creation-3-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to John 1:3, what role did Jesus play in creation?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "He had no role—He was created later"),
                                    AnswerChoice(id: "b", text: "All things were made through Him"),
                                    AnswerChoice(id: "c", text: "He only observed the Father creating"),
                                    AnswerChoice(id: "d", text: "He created only living things")
                                ],
                                correctAnswer: "b",
                                explanation: "John 1:3 says all things were made through Jesus (the Word)—nothing was made without Him. He is the Creator!"
                            ))
                        ),
                        LessonContent(
                            id: "creation-3-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What was the Spirit's role in creation according to Genesis 1:2?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "He was absent from creation"),
                                    AnswerChoice(id: "b", text: "He was hovering over the waters, actively present"),
                                    AnswerChoice(id: "c", text: "He only watched"),
                                    AnswerChoice(id: "d", text: "He came after creation was complete")
                                ],
                                correctAnswer: "b",
                                explanation: "The Spirit of God was actively present in creation, hovering over the face of the waters. All three Persons of the Trinity were involved."
                            ))
                        ),
                        LessonContent(
                            id: "creation-3-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does knowing Jesus is your Creator deepen your worship of Him?"
                            ))
                        )
                    ]
                ),

                // LESSON 4: Humanity: The Crown of Creation
                Lesson(
                    id: "creation-4",
                    trackId: "doctrine-creation",
                    title: "Humanity: The Crown of Creation",
                    description: "Discover why humans are uniquely special in God's creation",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "creation-4-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 1:26-27",
                                text: "Then God said, \"Let us make man in our image, after our likeness. And let them have dominion over the fish of the sea and over the birds of the heavens and over every living thing that moves on the earth.\" So God created man in his own image, in the image of God he created him; male and female he created them.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-4-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Psalm 8:4-5",
                                text: "What is man that you are mindful of him, and the son of man that you care for him? Yet you have made him a little lower than the heavenly beings and crowned him with glory and honor.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-4-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Made in God's Image",
                                text: "Humans are the crown of God's creation, made in His image unlike any other creature. God created man perfect and in His own image by a direct act—not through evolution. Being made in God's image gives every human being dignity, value, and purpose.\n\nPsalm 8 marvels at God's care for humanity, noting that we are made \"a little lower than the heavenly beings\" and crowned with \"glory and honor.\" We were created for relationship with God, to reflect His character, and to exercise loving dominion over the earth. This image, though marred by sin, gives every person inherent worth—from conception to natural death."
                            ))
                        ),
                        LessonContent(
                            id: "creation-4-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What makes humans unique from all other creatures?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Humans are just more evolved animals"),
                                    AnswerChoice(id: "b", text: "Humans were directly created in God's image"),
                                    AnswerChoice(id: "c", text: "There is nothing unique about humans"),
                                    AnswerChoice(id: "d", text: "Humans have bigger brains")
                                ],
                                correctAnswer: "b",
                                explanation: "Humans were directly created by God in His image—we are not evolved animals but special creations designed for relationship with God."
                            ))
                        ),
                        LessonContent(
                            id: "creation-4-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Psalm 8, how does God view humanity?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "With indifference"),
                                    AnswerChoice(id: "b", text: "With mindful care, crowning us with glory and honor"),
                                    AnswerChoice(id: "c", text: "As insignificant specks"),
                                    AnswerChoice(id: "d", text: "As problems to solve")
                                ],
                                correctAnswer: "b",
                                explanation: "Psalm 8 says God is \"mindful\" of us and has crowned humanity with \"glory and honor\"—we are precious to our Creator."
                            ))
                        ),
                        LessonContent(
                            id: "creation-4-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does being made in God's image give your life meaning and purpose?"
                            ))
                        )
                    ]
                ),

                // LESSON 5: Creation Reveals God
                Lesson(
                    id: "creation-5",
                    trackId: "doctrine-creation",
                    title: "Creation Reveals God",
                    description: "See how nature points to the Creator",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "creation-5-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 1:20",
                                text: "For his invisible attributes, namely, his eternal power and divine nature, have been clearly perceived, ever since the creation of the world, in the things that have been made. So they are without excuse.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-5-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Psalm 19:1-2",
                                text: "The heavens declare the glory of God, and the sky above proclaims his handiwork. Day to day pours out speech, and night to night reveals knowledge.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-5-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Nature Points to the Creator",
                                text: "Creation is not silent about its Creator! The heavens declare God's glory (Psalm 19:1). The complexity, beauty, and design of nature reveal God's eternal power and divine nature. This is called \"general revelation\"—enough to leave all people without excuse.\n\nRomans 1:20 states clearly that people can perceive God's invisible attributes through what He has made. Everyone knows intuitively that a Creator exists; they are accountable for how they respond to that knowledge. While general revelation cannot save, it points to the One who can. Nature is God's first witness to every human heart."
                            ))
                        ),
                        LessonContent(
                            id: "creation-5-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What can people learn about God from creation?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Nothing—creation is silent about God"),
                                    AnswerChoice(id: "b", text: "His eternal power and divine nature"),
                                    AnswerChoice(id: "c", text: "Only scientists can understand it"),
                                    AnswerChoice(id: "d", text: "That God does not care")
                                ],
                                correctAnswer: "b",
                                explanation: "Romans 1:20 says God's eternal power and divine nature are clearly seen through creation, leaving all people without excuse."
                            ))
                        ),
                        LessonContent(
                            id: "creation-5-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Why are people \"without excuse\" according to Romans 1:20?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Because creation clearly reveals God"),
                                    AnswerChoice(id: "b", text: "Because they have heard the gospel"),
                                    AnswerChoice(id: "c", text: "Because they own Bibles"),
                                    AnswerChoice(id: "d", text: "They actually have an excuse")
                                ],
                                correctAnswer: "a",
                                explanation: "People are without excuse because creation itself clearly reveals God's eternal power and divine nature to everyone."
                            ))
                        ),
                        LessonContent(
                            id: "creation-5-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "When you look at nature, what specifically reveals God's power or character to you?"
                            ))
                        )
                    ]
                ),

                // LESSON 6: Our Responsibility to Creation
                Lesson(
                    id: "creation-6",
                    trackId: "doctrine-creation",
                    title: "Our Responsibility to Creation",
                    description: "Understand our role as stewards of God's earth",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "creation-6-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 1:28",
                                text: "And God blessed them. And God said to them, \"Be fruitful and multiply and fill the earth and subdue it, and have dominion over the fish of the sea and over the birds of the heavens and over every living thing that moves on the earth.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-6-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Psalm 24:1",
                                text: "The earth is the LORD's and the fullness thereof, the world and those who dwell therein.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "creation-6-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Stewards of the Earth",
                                text: "God gave humanity dominion over creation—not to exploit it, but to steward it wisely. We are caretakers, not owners. The earth belongs to the Lord (Psalm 24:1). While creation is not to be worshiped, it is to be respected as God's handiwork.\n\nThis cultural mandate given in Genesis 1:28 has never been revoked. We honor God when we care for what He has made. As stewards, we are accountable to the Owner for how we manage His property. This includes responsible use of resources, care for animal life, and preserving beauty for future generations—all while prioritizing the eternal souls of people over temporal environmental concerns."
                            ))
                        ),
                        LessonContent(
                            id: "creation-6-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What does human \"dominion\" over creation mean?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "We can exploit creation however we want"),
                                    AnswerChoice(id: "b", text: "We are responsible stewards of God's earth"),
                                    AnswerChoice(id: "c", text: "We should worship nature"),
                                    AnswerChoice(id: "d", text: "We have no responsibility toward creation")
                                ],
                                correctAnswer: "b",
                                explanation: "Dominion means responsible stewardship—caring for God's creation as managers, not owners, honoring Him through how we treat His world."
                            ))
                        ),
                        LessonContent(
                            id: "creation-6-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Psalm 24:1, who owns the earth?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Humanity"),
                                    AnswerChoice(id: "b", text: "No one—it belongs to itself"),
                                    AnswerChoice(id: "c", text: "The LORD"),
                                    AnswerChoice(id: "d", text: "Governments")
                                ],
                                correctAnswer: "c",
                                explanation: "The earth is the LORD's—He owns it all. We are merely stewards entrusted with caring for His property."
                            ))
                        ),
                        LessonContent(
                            id: "creation-6-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How can you be a better steward of God's creation in your daily life?"
                            ))
                        )
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK: SATAN
        // ============================================
        Track(
            id: "doctrine-satan",
            name: "Satan",
            description: "Know your enemy—his origin, his schemes, and his ultimate defeat",
            icon: "shield.fill",
            color: "indigo",
            totalLessons: 6,
            completedLessons: 0,
            lessons: [
                // LESSON 1: Satan Is Real
                Lesson(
                    id: "satan-1",
                    trackId: "doctrine-satan",
                    title: "Satan Is Real",
                    description: "Understand that Satan is a real spiritual being",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "satan-1-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 8:44",
                                text: "You are of your father the devil, and your will is to do your father's desires. He was a murderer from the beginning, and does not stand in the truth, because there is no truth in him. When he lies, he speaks out of his own character, for he is a liar and the father of lies.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-1-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "1 Peter 5:8",
                                text: "Be sober-minded; be watchful. Your adversary the devil prowls around like a roaring lion, seeking someone to devour.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-1-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "A Real Enemy",
                                text: "Satan is not a myth, a symbol of evil, or a cartoon character with horns. He is a real spiritual being—a fallen angel who rebelled against God. We believe in the existence of Satan, the adversary of men and the arch-enemy of God.\n\nJesus spoke of him as a real person—\"a murderer from the beginning\" and \"the father of lies.\" Peter warns us to be watchful because the devil \"prowls around like a roaring lion, seeking someone to devour.\" While we should not be obsessed with him, we must take him seriously as our adversary. Denying his existence is one of his greatest tactics."
                            ))
                        ),
                        LessonContent(
                            id: "satan-1-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to the Bible, who is Satan?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "A fictional character"),
                                    AnswerChoice(id: "b", text: "A symbol of human evil"),
                                    AnswerChoice(id: "c", text: "A real fallen angel who opposes God"),
                                    AnswerChoice(id: "d", text: "An equal to God")
                                ],
                                correctAnswer: "c",
                                explanation: "Satan is a real spiritual being—a fallen angel who rebelled against God. He is not fictional, symbolic, or equal to God."
                            ))
                        ),
                        LessonContent(
                            id: "satan-1-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to John 8:44, what two things characterize Satan?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Love and peace"),
                                    AnswerChoice(id: "b", text: "Murder and lying"),
                                    AnswerChoice(id: "c", text: "Power and wisdom"),
                                    AnswerChoice(id: "d", text: "Beauty and intelligence")
                                ],
                                correctAnswer: "b",
                                explanation: "Jesus said Satan was \"a murderer from the beginning\" and \"the father of lies\"—his character is defined by destruction and deception."
                            ))
                        ),
                        LessonContent(
                            id: "satan-1-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does knowing Satan is real affect how you approach spiritual warfare?"
                            ))
                        )
                    ]
                ),

                // LESSON 2: Satan's Fall
                Lesson(
                    id: "satan-2",
                    trackId: "doctrine-satan",
                    title: "Satan's Fall",
                    description: "Learn how Satan became God's enemy",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "satan-2-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Isaiah 14:13-14",
                                text: "You said in your heart, \"I will ascend to heaven; above the stars of God I will set my throne on high; I will sit on the mount of assembly in the far reaches of the north; I will ascend above the heights of the clouds; I will make myself like the Most High.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-2-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Ezekiel 28:15, 17",
                                text: "You were blameless in your ways from the day you were created, till unrighteousness was found in you... Your heart was proud because of your beauty; you corrupted your wisdom for the sake of your splendor.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-2-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Pride Led to Fall",
                                text: "Satan was originally a beautiful, powerful angel created by God. Ezekiel describes him as \"blameless in your ways from the day you were created.\" But pride filled his heart—five times in Isaiah 14, he says \"I will,\" seeking to exalt himself above God's throne.\n\nHis sin was the sin of pride and rebellion—wanting to be \"like the Most High.\" God cast him out of heaven, and he took a third of the angels with him (Revelation 12:4). These fallen angels are now demons who serve Satan. His intent is to supplant God and frustrate His purposes, but he will suffer ultimate defeat."
                            ))
                        ),
                        LessonContent(
                            id: "satan-2-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What was the root sin that caused Satan's fall?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Jealousy of humans"),
                                    AnswerChoice(id: "b", text: "Pride—wanting to be like God"),
                                    AnswerChoice(id: "c", text: "He was created evil"),
                                    AnswerChoice(id: "d", text: "He made an honest mistake")
                                ],
                                correctAnswer: "b",
                                explanation: "Satan's root sin was pride—he wanted to exalt himself above God, to be \"like the Most High.\" This led to his rebellion and fall."
                            ))
                        ),
                        LessonContent(
                            id: "satan-2-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "How was Satan originally created according to Ezekiel 28:15?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Evil from the start"),
                                    AnswerChoice(id: "b", text: "Blameless until unrighteousness was found in him"),
                                    AnswerChoice(id: "c", text: "Weak and insignificant"),
                                    AnswerChoice(id: "d", text: "Already fallen")
                                ],
                                correctAnswer: "b",
                                explanation: "Satan was originally created blameless and beautiful. Sin was not in him until pride corrupted him."
                            ))
                        ),
                        LessonContent(
                            id: "satan-2-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "Pride was Satan's downfall. How can you guard against pride in your own life?"
                            ))
                        )
                    ]
                ),

                // LESSON 3: Satan's Schemes
                Lesson(
                    id: "satan-3",
                    trackId: "doctrine-satan",
                    title: "Satan's Schemes",
                    description: "Recognize the devil's tactics against you",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "satan-3-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 3:1-5",
                                text: "Now the serpent was more crafty than any other beast of the field that the LORD God had made. He said to the woman, \"Did God actually say, 'You shall not eat of any tree in the garden'?\" And the woman said to the serpent, \"We may eat of the fruit of the trees in the garden, but God said, 'You shall not eat of the fruit of the tree that is in the midst of the garden, neither shall you touch it, lest you die.'\" But the serpent said to the woman, \"You will not surely die. For God knows that when you eat of it your eyes will be opened, and you will be like God, knowing good and evil.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-3-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Matthew 4:3",
                                text: "And the tempter came and said to him, \"If you are the Son of God, command these stones to become loaves of bread.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-3-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "The Deceiver's Tactics",
                                text: "Satan's primary weapon is deception. In Eden, he used a three-step strategy: First, he questioned God's Word (\"Did God actually say?\"). Second, he denied it (\"You will not surely die\"). Third, he twisted it (offering false promises of being \"like God\").\n\nHe still uses these tactics today: causing doubt about Scripture, denying its truth, and offering counterfeit fulfillment. In Matthew 4, he even tempted Jesus by misusing Scripture! He is crafty, subtle, and patient. But Jesus defeated him by responding with the true Word of God. We must know Scripture well enough to recognize when it is being twisted."
                            ))
                        ),
                        LessonContent(
                            id: "satan-3-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What was Satan's first tactic in tempting Eve?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Threatening her with harm"),
                                    AnswerChoice(id: "b", text: "Causing doubt about God's Word"),
                                    AnswerChoice(id: "c", text: "Offering her money"),
                                    AnswerChoice(id: "d", text: "Appearing as a monster")
                                ],
                                correctAnswer: "b",
                                explanation: "Satan's first tactic was causing doubt: \"Did God actually say?\" He questioned God's Word before denying and twisting it."
                            ))
                        ),
                        LessonContent(
                            id: "satan-3-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "How did Satan tempt Eve to disobey?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "He threatened her"),
                                    AnswerChoice(id: "b", text: "He questioned, denied, and twisted God's Word"),
                                    AnswerChoice(id: "c", text: "He forced her hand"),
                                    AnswerChoice(id: "d", text: "He appealed to her humility")
                                ],
                                correctAnswer: "b",
                                explanation: "Satan used a progression: questioning God's Word, denying its truth, then twisting it to make sin seem beneficial."
                            ))
                        ),
                        LessonContent(
                            id: "satan-3-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "In what areas of your life do you sense Satan trying to cause doubt about God's Word?"
                            ))
                        )
                    ]
                ),

                // LESSON 4: Satan's Limitations
                Lesson(
                    id: "satan-4",
                    trackId: "doctrine-satan",
                    title: "Satan's Limitations",
                    description: "Understand that Satan is not equal to God",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "satan-4-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Job 1:12",
                                text: "And the LORD said to Satan, \"Behold, all that he has is in your hand. Only against him do not stretch out your hand.\" So Satan went out from the presence of the LORD.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-4-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "1 John 4:4",
                                text: "Little children, you are from God and have overcome them, for he who is in you is greater than he who is in the world.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-4-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "A Limited Enemy",
                                text: "Satan is powerful, but he is NOT equal to God! He is a created being with real limitations. He is not omniscient (all-knowing), omnipresent (everywhere), or omnipotent (all-powerful). He can only do what God permits.\n\nIn Job, Satan had to get God's permission before acting—and even then, he could not cross the boundary God set. This truth is liberating: Satan is on a leash! And \"greater is He who is in you than he who is in the world\" (1 John 4:4). As a believer, the Holy Spirit dwelling in you is infinitely more powerful than any demonic force."
                            ))
                        ),
                        LessonContent(
                            id: "satan-4-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What do we learn about Satan's power from Job 1:12?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Satan is equal to God"),
                                    AnswerChoice(id: "b", text: "Satan can only act within limits God permits"),
                                    AnswerChoice(id: "c", text: "Satan does not need God's permission"),
                                    AnswerChoice(id: "d", text: "Satan is more powerful than God")
                                ],
                                correctAnswer: "b",
                                explanation: "Job 1:12 shows that Satan could only act within the boundaries God set—he is a limited, created being under God's sovereign control."
                            ))
                        ),
                        LessonContent(
                            id: "satan-4-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to 1 John 4:4, why can believers overcome spiritual forces?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "We are stronger than Satan"),
                                    AnswerChoice(id: "b", text: "He who is in us (the Holy Spirit) is greater than he who is in the world"),
                                    AnswerChoice(id: "c", text: "Satan ignores believers"),
                                    AnswerChoice(id: "d", text: "We can negotiate with demons")
                                ],
                                correctAnswer: "b",
                                explanation: "The Holy Spirit living in believers is greater than Satan—we overcome not by our power but by God's power in us."
                            ))
                        ),
                        LessonContent(
                            id: "satan-4-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does knowing Satan is limited encourage you when you feel spiritually attacked?"
                            ))
                        )
                    ]
                ),

                // LESSON 5: Resisting the Devil
                Lesson(
                    id: "satan-5",
                    trackId: "doctrine-satan",
                    title: "Resisting the Devil",
                    description: "Learn how to stand firm against Satan's attacks",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "satan-5-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "James 4:7",
                                text: "Submit yourselves therefore to God. Resist the devil, and he will flee from you.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-5-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Matthew 4:10-11",
                                text: "Then Jesus said to him, \"Be gone, Satan! For it is written, 'You shall worship the Lord your God and him only shall you serve.'\" Then the devil left him, and behold, angels came and were ministering to him.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-5-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Submit and Resist",
                                text: "God has given us everything we need to resist Satan. The key is two-fold: first, submit to God (surrender to His will and ways); then resist the devil. Notice the order—submission to God must come first.\n\nJesus resisted Satan in the wilderness by using Scripture: \"It is written.\" We resist by putting on the full armor of God (Ephesians 6:10-18), especially wielding \"the sword of the Spirit, which is the word of God.\" When we stand firm in faith and God's truth, Satan will flee! He cannot withstand the authority of Christ in believers who are walking in obedience."
                            ))
                        ),
                        LessonContent(
                            id: "satan-5-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to James 4:7, what is the result of resisting the devil?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "He will attack harder"),
                                    AnswerChoice(id: "b", text: "He will flee from you"),
                                    AnswerChoice(id: "c", text: "Nothing will change"),
                                    AnswerChoice(id: "d", text: "He will try to negotiate")
                                ],
                                correctAnswer: "b",
                                explanation: "When we submit to God and resist the devil, he will flee from us! We have authority in Christ to stand against his schemes."
                            ))
                        ),
                        LessonContent(
                            id: "satan-5-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "How did Jesus resist Satan's temptations in Matthew 4?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "By debating philosophy"),
                                    AnswerChoice(id: "b", text: "By quoting Scripture: \"It is written\""),
                                    AnswerChoice(id: "c", text: "By ignoring Satan"),
                                    AnswerChoice(id: "d", text: "By performing miracles")
                                ],
                                correctAnswer: "b",
                                explanation: "Jesus defeated Satan's temptations by quoting Scripture—the Word of God is our primary weapon against the enemy."
                            ))
                        ),
                        LessonContent(
                            id: "satan-5-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "What practical steps can you take to \"submit to God and resist the devil\" this week?"
                            ))
                        )
                    ]
                ),

                // LESSON 6: Satan's Ultimate Defeat
                Lesson(
                    id: "satan-6",
                    trackId: "doctrine-satan",
                    title: "Satan's Ultimate Defeat",
                    description: "Celebrate Christ's victory over the enemy",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "satan-6-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Revelation 20:10",
                                text: "And the devil who had deceived them was thrown into the lake of fire and sulfur where the beast and the false prophet were, and they will be tormented day and night forever and ever.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-6-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Colossians 2:15",
                                text: "He disarmed the rulers and authorities and put them to open shame, by triumphing over them in him.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "satan-6-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "The Enemy Is Already Defeated",
                                text: "The story ends with Satan's total defeat! Jesus already defeated him at the cross—Colossians 2:15 says Christ \"disarmed the rulers and authorities and put them to open shame, by triumphing over them.\" The enemy is already a defeated foe.\n\nHe will suffer ultimate defeat at the hands of the Lord Jesus and will be tormented throughout eternity in the lake of fire (Revelation 20:10). Satan knows his time is short (Revelation 12:12), which is why he rages against God's people. But we are on the winning side—Christ has already won! Live today in light of that certain victory."
                            ))
                        ),
                        LessonContent(
                            id: "satan-6-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What is Satan's ultimate destiny?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "He will be forgiven and restored"),
                                    AnswerChoice(id: "b", text: "He will rule in hell"),
                                    AnswerChoice(id: "c", text: "He will be tormented in the lake of fire forever"),
                                    AnswerChoice(id: "d", text: "He will cease to exist")
                                ],
                                correctAnswer: "c",
                                explanation: "Revelation 20:10 says Satan will be thrown into the lake of fire and tormented forever—total, eternal defeat."
                            ))
                        ),
                        LessonContent(
                            id: "satan-6-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "When did Christ triumph over Satan according to Colossians 2:15?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "At the cross"),
                                    AnswerChoice(id: "b", text: "At the Second Coming"),
                                    AnswerChoice(id: "c", text: "He has not triumphed yet"),
                                    AnswerChoice(id: "d", text: "In the Garden of Eden")
                                ],
                                correctAnswer: "a",
                                explanation: "Colossians 2:15 says Christ triumphed over Satan \"in him\"—referring to the cross. The victory is already won!"
                            ))
                        ),
                        LessonContent(
                            id: "satan-6-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does knowing Satan's ultimate defeat give you confidence as you face spiritual battles today?"
                            ))
                        )
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK: HUMANITY & SIN
        // ============================================
        Track(
            id: "doctrine-man",
            name: "Humanity & Sin",
            description: "Understand what it means to be human and how sin has affected us all",
            icon: "person.2.fill",
            color: "indigo",
            totalLessons: 6,
            completedLessons: 0,
            lessons: [
                // LESSON 1: Created Perfect
                Lesson(
                    id: "man-1",
                    trackId: "doctrine-man",
                    title: "Created Perfect",
                    description: "See how God originally created humanity",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "man-1-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 1:27, 31",
                                text: "So God created man in his own image, in the image of God he created him; male and female he created them... And God saw everything that he had made, and behold, it was very good.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-1-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Ecclesiastes 7:29",
                                text: "See, this alone I found, that God made man upright, but they have sought out many schemes.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-1-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Originally Perfect",
                                text: "God created man perfect, in His own image, by a direct act. This is foundational to understanding the gospel. Adam and Eve were created sinless, in perfect fellowship with God and each other. There was no death, no suffering, no shame. They had meaningful work, a beautiful home, and unbroken relationship with their Creator.\n\nEcclesiastes 7:29 confirms that \"God made man upright\"—humanity's problem is not how we were made but what we have done. We \"sought out many schemes.\" Understanding our original perfection helps us grasp both the tragedy of the Fall and the hope of redemption in Christ."
                            ))
                        ),
                        LessonContent(
                            id: "man-1-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "How did God create the first humans?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Through evolution over millions of years"),
                                    AnswerChoice(id: "b", text: "Perfect, in His image, by a direct act"),
                                    AnswerChoice(id: "c", text: "With flaws and weaknesses"),
                                    AnswerChoice(id: "d", text: "As evolved animals")
                                ],
                                correctAnswer: "b",
                                explanation: "God created humans perfect, in His own image, by a direct act—not through evolution. They were originally sinless and in fellowship with God."
                            ))
                        ),
                        LessonContent(
                            id: "man-1-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Ecclesiastes 7:29, what is humanity's problem?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "We were made flawed"),
                                    AnswerChoice(id: "b", text: "God made us upright, but we sought out many schemes"),
                                    AnswerChoice(id: "c", text: "Evolution made us imperfect"),
                                    AnswerChoice(id: "d", text: "We have no problem")
                                ],
                                correctAnswer: "b",
                                explanation: "God made humanity upright—the problem is not our design but our rebellion. We \"sought out many schemes\" against our Creator."
                            ))
                        ),
                        LessonContent(
                            id: "man-1-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does knowing God's original design was \"very good\" affect how you view human dignity and purpose?"
                            ))
                        )
                    ]
                ),

                // LESSON 2: The Fall
                Lesson(
                    id: "man-2",
                    trackId: "doctrine-man",
                    title: "The Fall",
                    description: "Understand how sin entered the human race",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "man-2-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 5:12",
                                text: "Therefore, just as sin came into the world through one man, and death through sin, and so death spread to all men because all sinned.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-2-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Genesis 3:6-7",
                                text: "So when the woman saw that the tree was good for food, and that it was a delight to the eyes, and that the tree was to be desired to make one wise, she took of its fruit and ate, and she also gave some to her husband who was with her, and he ate. Then the eyes of both were opened, and they knew that they were naked.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-2-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "One Man's Sin Affected All",
                                text: "Subsequently, man sinned against his Creator and thereby brought upon himself and the whole human race physical and spiritual death. When Adam sinned, he was acting as the representative head of the entire human race.\n\nRomans 5:12 explains that sin entered the world through one man (Adam), and death through sin, and so death spread to all men \"because all sinned.\" We all sinned \"in Adam.\" His sin brought physical death (our bodies die) and spiritual death (separation from God) upon all humanity. This is not unfair—it is how representation works. And it is why we need a Second Adam (Christ) to represent us in righteousness."
                            ))
                        ),
                        LessonContent(
                            id: "man-2-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What was the result of Adam's sin for all humanity?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Nothing—each person starts fresh"),
                                    AnswerChoice(id: "b", text: "Physical and spiritual death spread to all"),
                                    AnswerChoice(id: "c", text: "Only Adam was affected"),
                                    AnswerChoice(id: "d", text: "Only physical death resulted")
                                ],
                                correctAnswer: "b",
                                explanation: "Adam's sin brought both physical death (our bodies die) and spiritual death (separation from God) to the entire human race."
                            ))
                        ),
                        LessonContent(
                            id: "man-2-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Romans 5:12, how did death spread to all men?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Through evolution"),
                                    AnswerChoice(id: "b", text: "Through natural aging"),
                                    AnswerChoice(id: "c", text: "Because all sinned in Adam"),
                                    AnswerChoice(id: "d", text: "Death is not real")
                                ],
                                correctAnswer: "c",
                                explanation: "Death spread to all men \"because all sinned\"—we all sinned in Adam as our representative head."
                            ))
                        ),
                        LessonContent(
                            id: "man-2-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does understanding the Fall help you make sense of the brokenness you see in the world?"
                            ))
                        )
                    ]
                ),

                // LESSON 3: Total Depravity
                Lesson(
                    id: "man-3",
                    trackId: "doctrine-man",
                    title: "Total Depravity",
                    description: "See how deeply sin has affected every person",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "man-3-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 3:10-12",
                                text: "As it is written: \"None is righteous, no, not one; no one understands; no one seeks for God. All have turned aside; together they have become worthless; no one does good, not even one.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-3-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 3:23",
                                text: "For all have sinned and fall short of the glory of God.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-3-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Totally Affected by Sin",
                                text: "All men, therefore, are dead in trespasses and sins, and are unable to remedy their lost condition. Total depravity does not mean people are as evil as possible—it means every part of us is affected by sin. Our minds, wills, emotions, and bodies are all tainted.\n\nRomans 3:10-12 delivers the devastating verdict: \"None is righteous\"—\"no one understands\"—\"no one seeks for God\"—\"no one does good.\" This is the human condition apart from God's grace. We are \"dead in trespasses and sins\" (Ephesians 2:1)—spiritually unable to save ourselves. This is why we desperately need a Savior."
                            ))
                        ),
                        LessonContent(
                            id: "man-3-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What does \"total depravity\" mean?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Everyone is as evil as possible"),
                                    AnswerChoice(id: "b", text: "Every part of us is affected by sin and we cannot save ourselves"),
                                    AnswerChoice(id: "c", text: "Most people are basically good"),
                                    AnswerChoice(id: "d", text: "Only bad people are affected by sin")
                                ],
                                correctAnswer: "b",
                                explanation: "Total depravity means every aspect of our being is affected by sin—we are spiritually dead and unable to save ourselves."
                            ))
                        ),
                        LessonContent(
                            id: "man-3-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Romans 3:10-12, how many people are righteous?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Most people"),
                                    AnswerChoice(id: "b", text: "Some religious people"),
                                    AnswerChoice(id: "c", text: "None, not even one"),
                                    AnswerChoice(id: "d", text: "Those who try hard")
                                ],
                                correctAnswer: "c",
                                explanation: "None is righteous, no, not one—this includes everyone apart from the righteousness given through faith in Christ."
                            ))
                        ),
                        LessonContent(
                            id: "man-3-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "Why is understanding our inability to save ourselves essential for appreciating the gospel?"
                            ))
                        )
                    ]
                ),

                // LESSON 4: Born Sinners
                Lesson(
                    id: "man-4",
                    trackId: "doctrine-man",
                    title: "Born Sinners",
                    description: "Understand that we are sinners from birth",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "man-4-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Psalm 51:5",
                                text: "Behold, I was brought forth in iniquity, and in sin did my mother conceive me.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-4-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Ephesians 2:3",
                                text: "Among whom we all once lived in the passions of our flesh, carrying out the desires of the body and the mind, and were by nature children of wrath, like the rest of mankind.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-4-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Sinful from the Start",
                                text: "David acknowledged that his sinful nature was present from his very conception. We are not born innocent and then corrupted; we are born with a bent toward sin. Ephesians 2:3 says we were \"by nature children of wrath\"—sinners by nature, not just by choice.\n\nNo one has to teach a child to lie, be selfish, or throw tantrums—it comes naturally! We are sinners who sin. This is why Jesus told Nicodemus, \"You must be born again\" (John 3:7)—our first birth was tainted by sin, so we need a second birth to receive new life."
                            ))
                        ),
                        LessonContent(
                            id: "man-4-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Psalm 51:5, when does a person become a sinner?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "When they first commit a sin"),
                                    AnswerChoice(id: "b", text: "At puberty"),
                                    AnswerChoice(id: "c", text: "From conception—we are born with a sinful nature"),
                                    AnswerChoice(id: "d", text: "Only when they choose to sin")
                                ],
                                correctAnswer: "c",
                                explanation: "Psalm 51:5 says David was sinful from conception—we are born with a sinful nature, not born innocent and later corrupted."
                            ))
                        ),
                        LessonContent(
                            id: "man-4-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Ephesians 2:3, what were we \"by nature\"?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Children of light"),
                                    AnswerChoice(id: "b", text: "Children of wrath"),
                                    AnswerChoice(id: "c", text: "Basically good"),
                                    AnswerChoice(id: "d", text: "Neutral")
                                ],
                                correctAnswer: "b",
                                explanation: "We were \"by nature children of wrath\"—born into a condition that deserved God's righteous judgment."
                            ))
                        ),
                        LessonContent(
                            id: "man-4-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does this truth help you understand your own struggles with sin?"
                            ))
                        )
                    ]
                ),

                // LESSON 5: The Wages of Sin
                Lesson(
                    id: "man-5",
                    trackId: "doctrine-man",
                    title: "The Wages of Sin",
                    description: "See what our sin truly deserves",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "man-5-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 6:23",
                                text: "For the wages of sin is death, but the free gift of God is eternal life in Christ Jesus our Lord.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-5-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Revelation 21:8",
                                text: "But as for the cowardly, the faithless, the detestable, as for murderers, the sexually immoral, sorcerers, idolaters, and all liars, their portion will be in the lake that burns with fire and sulfur, which is the second death.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-5-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Death Is the Payment",
                                text: "Without the remission of sins through the forgiveness of God and the new birth, all men will endure eternal punishment in the lake of fire. The \"wages\" of sin—what sin earns us—is death. This includes physical death (our bodies die), spiritual death (separation from God now), and eternal death (separation from God forever in the lake of fire).\n\nRevelation 21:8 describes the \"second death\"—eternal punishment in the lake of fire. This is not a scare tactic but a sober reality. Every sin against an infinitely holy God deserves infinite punishment. Only when we grasp the horror of our condition can we truly appreciate the gift that follows: \"but the free gift of God is eternal life in Christ Jesus our Lord.\""
                            ))
                        ),
                        LessonContent(
                            id: "man-5-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What are the \"wages of sin\" according to Romans 6:23?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Temporary suffering"),
                                    AnswerChoice(id: "b", text: "Death—physical, spiritual, and eternal"),
                                    AnswerChoice(id: "c", text: "Nothing serious"),
                                    AnswerChoice(id: "d", text: "Good works can balance out our sins")
                                ],
                                correctAnswer: "b",
                                explanation: "The wages (earned payment) of sin is death—every sin deserves eternal separation from God. This is why we need a Savior."
                            ))
                        ),
                        LessonContent(
                            id: "man-5-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What is the \"second death\" according to Revelation 21:8?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Physical death"),
                                    AnswerChoice(id: "b", text: "Temporary punishment"),
                                    AnswerChoice(id: "c", text: "The lake of fire—eternal separation from God"),
                                    AnswerChoice(id: "d", text: "Reincarnation")
                                ],
                                correctAnswer: "c",
                                explanation: "The second death is the lake of fire—eternal conscious punishment for those who die without Christ."
                            ))
                        ),
                        LessonContent(
                            id: "man-5-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does the seriousness of sin make you appreciate the gift of salvation even more?"
                            ))
                        )
                    ]
                ),

                // LESSON 6: The Need for New Birth
                Lesson(
                    id: "man-6",
                    trackId: "doctrine-man",
                    title: "The Need for New Birth",
                    description: "Understand why we must be born again",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "man-6-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 3:3",
                                text: "Jesus answered him, \"Truly, truly, I say to you, unless one is born again he cannot see the kingdom of God.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-6-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 3:5-7",
                                text: "Jesus answered, \"Truly, truly, I say to you, unless one is born of water and the Spirit, he cannot enter the kingdom of God. That which is born of the flesh is flesh, and that which is born of the Spirit is spirit. Do not marvel that I said to you, 'You must be born again.'\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "man-6-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "You Must Be Born Again",
                                text: "Jesus told Nicodemus—a religious, moral man—that he must be born again. Being religious is not enough. Being moral is not enough. Being Jewish (or any heritage) is not enough. You must be born again.\n\nOur first birth left us spiritually dead; we need a second birth to receive spiritual life. Jesus emphasized: \"That which is born of the flesh is flesh, and that which is born of the Spirit is spirit.\" This new birth is not something we achieve but something God does in us when we trust Christ. It is the work of the Holy Spirit, who regenerates and sanctifies believing men. Without being born again, we cannot see or enter God's kingdom."
                            ))
                        ),
                        LessonContent(
                            id: "man-6-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Why did Jesus say we \"must be born again\"?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Being religious is enough"),
                                    AnswerChoice(id: "b", text: "Our first birth left us spiritually dead; we need new spiritual life"),
                                    AnswerChoice(id: "c", text: "It was just a suggestion"),
                                    AnswerChoice(id: "d", text: "Good people do not need new birth")
                                ],
                                correctAnswer: "b",
                                explanation: "We must be born again because our first birth left us spiritually dead in sin—we need God to give us new spiritual life."
                            ))
                        ),
                        LessonContent(
                            id: "man-6-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Who was Nicodemus, and why is his encounter with Jesus significant?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "A notorious sinner who needed saving"),
                                    AnswerChoice(id: "b", text: "A religious teacher—showing even \"good\" people need new birth"),
                                    AnswerChoice(id: "c", text: "A Roman soldier"),
                                    AnswerChoice(id: "d", text: "An atheist")
                                ],
                                correctAnswer: "b",
                                explanation: "Nicodemus was a Pharisee and teacher—a religious, moral man. Jesus told him he needed new birth, showing that religion alone cannot save."
                            ))
                        ),
                        LessonContent(
                            id: "man-6-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "Have you been born again? What evidence of new life do you see in yourself?"
                            ))
                        )
                    ]
                )
            ]
        ),

        // ============================================
        // TRACK: SALVATION
        // ============================================
        Track(
            id: "doctrine-salvation",
            name: "Salvation",
            description: "Discover how God saves lost sinners through faith in Jesus Christ",
            icon: "gift.fill",
            color: "indigo",
            totalLessons: 8,
            completedLessons: 0,
            lessons: [
                // LESSON 1: Salvation Made Possible
                Lesson(
                    id: "salvation-1",
                    trackId: "doctrine-salvation",
                    title: "Salvation Made Possible",
                    description: "See how Christ's sacrifice made salvation available",
                    order: 1,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-1-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 5:8",
                                text: "But God shows his love for us in that while we were still sinners, Christ died for us.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-1-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 3:16",
                                text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-1-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Christ Died for Sinners",
                                text: "We believe that the salvation of lost and sinful men is made possible by the substitutionary sacrifice of Jesus Christ for sinners. We could never save ourselves—our best efforts are filthy rags before a holy God (Isaiah 64:6).\n\nBut God, in His amazing love, sent His Son to die for sinners—\"while we were still sinners\"! This is not love responding to our worthiness but love initiating our rescue. John 3:16 captures this: God \"so loved\" that He \"gave.\" Jesus took the punishment we deserved so that we could receive the forgiveness we do not deserve. This is the gospel."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-1-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "How is salvation made possible?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Through our good works"),
                                    AnswerChoice(id: "b", text: "Through Christ's substitutionary death for sinners"),
                                    AnswerChoice(id: "c", text: "Through religious rituals"),
                                    AnswerChoice(id: "d", text: "By being born into a Christian family")
                                ],
                                correctAnswer: "b",
                                explanation: "Salvation is made possible by Christ dying in our place—He took the punishment for our sins on the cross."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-1-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Romans 5:8, when did Christ die for us?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "After we became good"),
                                    AnswerChoice(id: "b", text: "While we were still sinners"),
                                    AnswerChoice(id: "c", text: "When we earned it"),
                                    AnswerChoice(id: "d", text: "After we asked for help")
                                ],
                                correctAnswer: "b",
                                explanation: "Christ died for us \"while we were still sinners\"—God's love initiated our rescue before we did anything to deserve it."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-1-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "What does it mean to you that Christ died for you while you were still a sinner?"
                            ))
                        )
                    ]
                ),

                // LESSON 2: Faith Alone
                Lesson(
                    id: "salvation-2",
                    trackId: "doctrine-salvation",
                    title: "Faith Alone",
                    description: "Understand that salvation is received by faith, not works",
                    order: 2,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-2-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Ephesians 2:8-9",
                                text: "For by grace you have been saved through faith. And this is not your own doing; it is the gift of God, not a result of works, so that no one may boast.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-2-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 10:9-10",
                                text: "Because, if you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved. For with the heart one believes and is justified, and with the mouth one confesses and is saved.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-2-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "By Grace Through Faith",
                                text: "Salvation is obtained by faith apart from works. It is not earned by being good, attending church, being baptized, or any religious activity. It is a free gift received when we trust in Christ.\n\nNotice the key words in Ephesians 2:8-9: \"by grace\"—unmerited favor; \"through faith\"—trusting in Christ; \"gift of God\"—free and unearned; \"not a result of works\"—nothing we do contributes; \"so that no one may boast\"—God gets all glory. Romans 10:9-10 confirms that belief in the heart is what saves, not external actions. Faith is the empty hand that receives what God freely offers."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-2-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What role do works play in obtaining salvation?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Works are necessary to earn salvation"),
                                    AnswerChoice(id: "b", text: "Works have no role—salvation is by faith alone"),
                                    AnswerChoice(id: "c", text: "Faith plus works equals salvation"),
                                    AnswerChoice(id: "d", text: "Only certain works count")
                                ],
                                correctAnswer: "b",
                                explanation: "Salvation is by grace through faith, not by works. Good works are the result of salvation, not the means of obtaining it."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-2-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Why does Ephesians 2:9 say salvation is not by works?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "So that no one may boast"),
                                    AnswerChoice(id: "b", text: "Because works do not matter"),
                                    AnswerChoice(id: "c", text: "So people can be lazy"),
                                    AnswerChoice(id: "d", text: "It does not say this")
                                ],
                                correctAnswer: "a",
                                explanation: "Salvation is not by works \"so that no one may boast\"—God alone deserves glory for our salvation."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-2-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "Why is it important that salvation is not based on our works?"
                            ))
                        )
                    ]
                ),

                // LESSON 3: Repentance
                Lesson(
                    id: "salvation-3",
                    trackId: "doctrine-salvation",
                    title: "Repentance",
                    description: "Learn what it means to truly turn to God",
                    order: 3,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-3-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Acts 20:21",
                                text: "Testifying both to Jews and to Greeks of repentance toward God and of faith in our Lord Jesus Christ.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-3-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Acts 16:31",
                                text: "And they said, \"Believe in the Lord Jesus, and you will be saved, you and your household.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-3-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Turning to God",
                                text: "Salvation is received by a sinner when he repents toward God and places his trust in the person and work of the Lord Jesus as his own personal Savior. Repentance means a change of mind that leads to a change of direction.\n\nActs 20:21 links \"repentance toward God\" with \"faith in our Lord Jesus Christ\"—these are two sides of the same coin. A sinner turns from trusting in themselves to trusting in Christ. True repentance is not just feeling sorry for sin; it is agreeing with God about sin and turning to Him for salvation. You cannot turn toward Christ without turning away from self-reliance."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-3-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What is biblical repentance?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Just feeling sorry for getting caught"),
                                    AnswerChoice(id: "b", text: "A change of mind that turns from sin to God"),
                                    AnswerChoice(id: "c", text: "Promising never to sin again"),
                                    AnswerChoice(id: "d", text: "Making up for past sins")
                                ],
                                correctAnswer: "b",
                                explanation: "Biblical repentance is a change of mind about sin and self that leads to turning to God in faith for salvation."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-3-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Acts 16:31, what must a person do to be saved?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Be baptized first"),
                                    AnswerChoice(id: "b", text: "Believe in the Lord Jesus"),
                                    AnswerChoice(id: "c", text: "Do good works"),
                                    AnswerChoice(id: "d", text: "Join a church")
                                ],
                                correctAnswer: "b",
                                explanation: "The Philippian jailer was told simply: \"Believe in the Lord Jesus, and you will be saved\"—faith is the requirement."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-3-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "What did repentance look like in your own experience of coming to Christ?"
                            ))
                        )
                    ]
                ),

                // LESSON 4: Trusting in Christ
                Lesson(
                    id: "salvation-4",
                    trackId: "doctrine-salvation",
                    title: "Trusting in Christ",
                    description: "See what it means to believe in Jesus as Savior",
                    order: 4,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-4-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 3:16-18",
                                text: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life. For God did not send his Son into the world to condemn the world, but in order that the world might be saved through him. Whoever believes in him is not condemned, but whoever does not believe is condemned already.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-4-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 1:12",
                                text: "But to all who did receive him, who believed in his name, he gave the right to become children of God.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-4-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Believing in Jesus",
                                text: "All who receive the Lord Jesus by faith as Savior are thereby born again and have eternal life. Saving faith is not just believing facts about Jesus—even demons believe He exists (James 2:19). Saving faith is personally trusting in the person and work of Jesus as your own Savior.\n\nJohn 1:12 describes believers as those who \"receive\" Christ—it is a personal transaction. Faith is like sitting in a chair—you are trusting it to hold you, not just believing it exists. John 3:18 makes the stakes clear: \"Whoever believes in him is not condemned, but whoever does not believe is condemned already.\" Faith in Christ is the dividing line between salvation and condemnation."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-4-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What is saving faith?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Just believing Jesus existed"),
                                    AnswerChoice(id: "b", text: "Personally trusting in Jesus' person and work for salvation"),
                                    AnswerChoice(id: "c", text: "Believing you are a good person"),
                                    AnswerChoice(id: "d", text: "Having no doubts")
                                ],
                                correctAnswer: "b",
                                explanation: "Saving faith is personally trusting in Jesus—not just believing facts about Him, but relying on Him alone for salvation."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-4-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to John 3:18, what is the status of those who do not believe?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "They are safe until judgment"),
                                    AnswerChoice(id: "b", text: "They are condemned already"),
                                    AnswerChoice(id: "c", text: "They have time to decide later"),
                                    AnswerChoice(id: "d", text: "They are probably okay")
                                ],
                                correctAnswer: "b",
                                explanation: "Those who do not believe are \"condemned already\"—not waiting for judgment but already under condemnation."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-4-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "Is your faith in Jesus Himself, or are you trusting in something else for your salvation?"
                            ))
                        )
                    ]
                ),

                // LESSON 5: Born Again
                Lesson(
                    id: "salvation-5",
                    trackId: "doctrine-salvation",
                    title: "Born Again",
                    description: "Experience the new birth that salvation brings",
                    order: 5,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-5-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 3:5-6",
                                text: "Jesus answered, \"Truly, truly, I say to you, unless one is born of water and the Spirit, he cannot enter the kingdom of God. That which is born of the flesh is flesh, and that which is born of the Spirit is spirit.\"",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-5-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "2 Corinthians 5:17",
                                text: "Therefore, if anyone is in Christ, he is a new creation. The old has passed away; behold, the new has come.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-5-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "New Birth, New Life",
                                text: "We believe that the Holy Spirit regenerates and sanctifies believing men. When we receive Christ, we are born again—regenerated by the Holy Spirit. This is not a reformation but a transformation. We receive a new nature, new desires, and new life.\n\nSecond Corinthians 5:17 declares: \"If anyone is in Christ, he is a new creation. The old has passed away; behold, the new has come.\" This new birth is instantaneous (it happens the moment we believe), permanent (it cannot be undone), and the work of God alone (we cannot birth ourselves). You are not merely improved—you are made new!"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-5-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What happens when a person is \"born again\"?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "They try harder to be good"),
                                    AnswerChoice(id: "b", text: "They receive new spiritual life from the Holy Spirit"),
                                    AnswerChoice(id: "c", text: "They become physically younger"),
                                    AnswerChoice(id: "d", text: "Nothing really changes")
                                ],
                                correctAnswer: "b",
                                explanation: "Being born again means receiving new spiritual life from the Holy Spirit—a new nature, new desires, and becoming a new creation."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-5-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to 2 Corinthians 5:17, what has happened to someone \"in Christ\"?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "They are slightly improved"),
                                    AnswerChoice(id: "b", text: "They are a new creation—the old has passed away"),
                                    AnswerChoice(id: "c", text: "They are the same but forgiven"),
                                    AnswerChoice(id: "d", text: "They will change eventually")
                                ],
                                correctAnswer: "b",
                                explanation: "In Christ, we are \"a new creation\"—the old has passed away; the new has come. This is radical transformation, not mere improvement."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-5-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "What changes have you noticed in your life since being born again?"
                            ))
                        )
                    ]
                ),

                // LESSON 6: Eternal Life
                Lesson(
                    id: "salvation-6",
                    trackId: "doctrine-salvation",
                    title: "Eternal Life",
                    description: "Receive the promise of everlasting life in Christ",
                    order: 6,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-6-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 5:24",
                                text: "Truly, truly, I say to you, whoever hears my word and believes him who sent me has eternal life. He does not come into judgment, but has passed from death to life.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-6-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 10:28",
                                text: "I give them eternal life, and they will never perish, and no one will snatch them out of my hand.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-6-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Life That Never Ends",
                                text: "Those who believe in Christ have eternal life—not \"will have\" someday, but HAVE right now! John 5:24 uses present tense: \"has eternal life.\" Eternal life is not just living forever; it is knowing God (John 17:3). It begins the moment we believe and continues forever.\n\nJohn 10:28 adds the promise of security: \"they will never perish, and no one will snatch them out of my hand.\" This is Jesus' own promise! We have passed from death to life and will not come into judgment. Our eternity is as secure as Jesus' grip on us—and He never lets go."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-6-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "When does eternal life begin?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "When we die"),
                                    AnswerChoice(id: "b", text: "The moment we believe in Christ"),
                                    AnswerChoice(id: "c", text: "After we prove ourselves worthy"),
                                    AnswerChoice(id: "d", text: "At the final judgment")
                                ],
                                correctAnswer: "b",
                                explanation: "Eternal life begins the moment we believe—Jesus said whoever believes \"HAS\" (present tense) eternal life."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-6-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to John 10:28, what will happen to believers?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "They might perish if they sin too much"),
                                    AnswerChoice(id: "b", text: "They will never perish; no one can snatch them from Christ's hand"),
                                    AnswerChoice(id: "c", text: "They must hold on tightly"),
                                    AnswerChoice(id: "d", text: "They could lose their salvation")
                                ],
                                correctAnswer: "b",
                                explanation: "Jesus promises believers will \"never perish\" and \"no one will snatch them out of my hand\"—our security is in His grip, not ours."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-6-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does the reality of possessing eternal life RIGHT NOW change how you live today?"
                            ))
                        )
                    ]
                ),

                // LESSON 7: Evidence of Salvation
                Lesson(
                    id: "salvation-7",
                    trackId: "doctrine-salvation",
                    title: "Evidence of Salvation",
                    description: "See the fruit that genuine faith produces",
                    order: 7,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-7-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Titus 2:11-14",
                                text: "For the grace of God has appeared, bringing salvation for all people, training us to renounce ungodliness and worldly passions, and to live self-controlled, upright, and godly lives in the present age, waiting for our blessed hope, the appearing of the glory of our great God and Savior Jesus Christ, who gave himself for us to redeem us from all lawlessness and to purify for himself a people for his own possession who are zealous for good works.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-7-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Galatians 5:13",
                                text: "For you were called to freedom, brothers. Only do not use your freedom as an opportunity for the flesh, but through love serve one another.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-7-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Grace That Transforms",
                                text: "We believe that the evidence of salvation is a righteous life, love of the brethren, and continuance in the teachings of the Word of God. While we are not saved BY good works, we are saved FOR good works (Ephesians 2:10). Genuine salvation produces fruit!\n\nTitus 2:11-14 teaches that grace \"trains\" us—it is not a license to sin but power for godliness. Grace teaches us to \"renounce ungodliness\" and live \"self-controlled, upright, and godly lives.\" Galatians 5:13 warns against using freedom as an excuse for sin but calls us to \"serve one another\" in love. These changes do not EARN salvation but EVIDENCE it."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-7-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "What is the relationship between salvation and good works?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Good works earn salvation"),
                                    AnswerChoice(id: "b", text: "Good works are evidence of genuine salvation"),
                                    AnswerChoice(id: "c", text: "Good works are not important"),
                                    AnswerChoice(id: "d", text: "Good works can replace faith")
                                ],
                                correctAnswer: "b",
                                explanation: "Good works do not earn salvation—they are the evidence of genuine salvation. We are saved FOR good works, not BY them."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-7-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Titus 2:11-12, what does grace \"train\" us to do?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Renounce ungodliness and live godly lives"),
                                    AnswerChoice(id: "b", text: "Do whatever we want"),
                                    AnswerChoice(id: "c", text: "Earn more grace"),
                                    AnswerChoice(id: "d", text: "Judge others")
                                ],
                                correctAnswer: "a",
                                explanation: "Grace trains us to \"renounce ungodliness and worldly passions, and to live self-controlled, upright, and godly lives.\""
                            ))
                        ),
                        LessonContent(
                            id: "salvation-7-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "What \"fruit\" in your life gives you assurance that your faith is genuine?"
                            ))
                        )
                    ]
                ),

                // LESSON 8: Eternal Security
                Lesson(
                    id: "salvation-8",
                    trackId: "doctrine-salvation",
                    title: "Eternal Security",
                    description: "Rest in the assurance that salvation cannot be lost",
                    order: 8,
                    xpReward: 50,
                    isCompleted: false,
                    content: [
                        LessonContent(
                            id: "salvation-8-1",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "John 10:27-30",
                                text: "My sheep hear my voice, and I know them, and they follow me. I give them eternal life, and they will never perish, and no one will snatch them out of my hand. My Father, who has given them to me, is greater than all, and no one is able to snatch them out of the Father's hand. I and the Father are one.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-8-1b",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "Romans 8:38-39",
                                text: "For I am sure that neither death nor life, nor angels nor rulers, nor things present nor things to come, nor powers, nor height nor depth, nor anything else in all creation, will be able to separate us from the love of God in Christ Jesus our Lord.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-8-1c",
                            type: .scripture,
                            data: .scripture(ScriptureContent(
                                reference: "1 Peter 1:5",
                                text: "Who by God's power are being guarded through faith for a salvation ready to be revealed in the last time.",
                                version: "ESV"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-8-2",
                            type: .explanation,
                            data: .explanation(ExplanationContent(
                                title: "Kept by God's Power",
                                text: "We believe that all the redeemed, once saved, are kept by God's power and are thus secure in Christ forever. This doctrine is often called \"eternal security\" or \"the perseverance of the saints.\"\n\nJohn 10:27-30 provides a double grip—we are held in both the Son's hand and the Father's hand. Romans 8:38-39 lists everything imaginable and concludes NOTHING can separate us from God's love in Christ. First Peter 1:5 says we are \"guarded by God's power.\" Our security does not depend on our grip on God but on His grip on us. If salvation could be lost, it would not be \"eternal\" life. The God who began the good work will complete it (Philippians 1:6)!"
                            ))
                        ),
                        LessonContent(
                            id: "salvation-8-3",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "Why is the believer eternally secure?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Because we try hard not to sin"),
                                    AnswerChoice(id: "b", text: "Because we are kept by God's power, held in the Father's and Son's hands"),
                                    AnswerChoice(id: "c", text: "Because we never doubt"),
                                    AnswerChoice(id: "d", text: "We are not eternally secure")
                                ],
                                correctAnswer: "b",
                                explanation: "Our security rests on God's power keeping us, not our own efforts. We are held in both Christ's and the Father's hands."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-8-3b",
                            type: .question,
                            data: .question(QuestionContent(
                                question: "According to Romans 8:38-39, what can separate us from God's love in Christ?",
                                type: .multipleChoice,
                                options: [
                                    AnswerChoice(id: "a", text: "Death or life"),
                                    AnswerChoice(id: "b", text: "Angels or rulers"),
                                    AnswerChoice(id: "c", text: "Height or depth"),
                                    AnswerChoice(id: "d", text: "Nothing in all creation")
                                ],
                                correctAnswer: "d",
                                explanation: "NOTHING in all creation can separate us from the love of God in Christ Jesus our Lord—our security is absolute."
                            ))
                        ),
                        LessonContent(
                            id: "salvation-8-4",
                            type: .reflection,
                            data: .reflection(ReflectionContent(
                                prompt: "How does the truth of eternal security affect your daily walk with God and your peace of heart?"
                            ))
                        )
                    ]
                )
            ]
        )
    ]
}
