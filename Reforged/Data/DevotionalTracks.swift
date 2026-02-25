import Foundation

// MARK: - Devotional Tracks

extension LearningTracks {

    static let devotionalTracks: [Track] = [
    // MARK: - Christian Community
    Track(
        id: "devotional-christian-community",
        name: "Christian Community",
        description: "Learn how to encourage, counsel, and live in unity with fellow believers",
        icon: "person.2.fill",
        color: "coral",
        totalLessons: 3,
        completedLessons: 0,
        lessons: [
            // MARK: Lesson 1 - Counseling in the Church Corridor
            Lesson(
                id: "dev-cc-1",
                trackId: "devotional-christian-community",
                title: "Counseling in the Church Corridor",
                description: "Learn how to encourage different people in different ways",
                order: 1,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-cc-1-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "1 Thessalonians 5:14",
                            text: "And we urge you, brothers, admonish the idle, encourage the fainthearted, help the weak, be patient with them all.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-1-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Encouragement Counseling",
                            text: "Every Christian should be engaged in encouragement counseling. The best encouragement counseling uses different tones of conversation. This ministry happens in the foyer, standing beside your car outside, and during Sunday afternoon lunches. It is characterized by spiritual admonishment, encouragement, support, and patience."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-1-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Different People, Different Approaches",
                            text: "Paul encouraged the Thessalonian believers to encourage each other in certain ways for certain types of difficulties. For the lazy and unruly, the believers were to admonish, warn, or advise. For the discouraged, the believers were to encourage and comfort them. For the weak or sick folk, the believers were to cleave to and support them. All of these counseling sessions have different conversation tones."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-1-4",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "According to 1 Thessalonians 5:14, what approach should we use with those who are \"fainthearted\" (discouraged)?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "Admonish and warn them"),
                                AnswerChoice(id: "b", text: "Encourage and comfort them"),
                                AnswerChoice(id: "c", text: "Leave them alone"),
                                AnswerChoice(id: "d", text: "Correct their doctrine")
                            ],
                            correctAnswer: "b",
                            explanation: "Paul instructs believers to encourage (or comfort) those who are fainthearted or discouraged. For the unruly, an admonishment approach is recommended. For the discouraged, a comforting approach is recommended. For the sick, a faithful-friend approach is recommended."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-1-5",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Daily Application",
                            text: "In the 21st century local church, believers interact with hurting, disobedient, and discouraged believers on a weekly or daily basis. The counseling approach and attitude must be appropriate for each individual. Not one approach works in every counseling situation. As we interact with believers on a day-to-day basis, let us be encouragers, admonishers, comforters, supporters, and advisors."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-1-6",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "Think of someone in your life who needs encouragement. What approach does their situation call for\u{2014}admonishment, comfort, or faithful support? How can you minister to them this week?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 2 - Assembly of Citizens
            Lesson(
                id: "dev-cc-2",
                trackId: "devotional-christian-community",
                title: "Assembly of Citizens",
                description: "Understand the purpose and priority of gathering with believers",
                order: 2,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-cc-2-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Acts 2:46",
                            text: "And day by day, attending the temple together and breaking bread in their homes, they received their food with glad and generous hearts.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-2-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "The Meaning of Ekklesia",
                            text: "The Greek word \u{1F10}\u{03BA}\u{03BA}\u{03BB}\u{03B7}\u{03C3}\u{03AF}\u{03B1} (ekklesia) is a descriptive word meaning \"assembly\" or \"an assembly of the citizens regularly summoned.\" The Christian use of the word is used in the context of a gathered assembly of believers over 22 times throughout the New Testament. When the word is used in its Christian sense, it describes the called-out assembly that gathers on Sunday morning\u{2014}a gathered group of believers meeting together for the glory of God and the proclamation of the Gospel."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-2-3",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Acts 7:38",
                            text: "This is the one who was in the congregation in the wilderness with the angel who spoke to him at Mount Sinai, and with our fathers. He received living oracles to give to us.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-2-4",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "What is the primary focus of the church as described in Acts?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "Political activism"),
                                AnswerChoice(id: "b", text: "Praising God and the glory of Christ"),
                                AnswerChoice(id: "c", text: "Entertainment and social events"),
                                AnswerChoice(id: "d", text: "Building wealth")
                            ],
                            correctAnswer: "b",
                            explanation: "Throughout Acts, the focus of the church is \"Praising God\" and \"the glory of Christ\" (Acts 2:46; 2 Cor. 8:23). This remains the priority for believers gathering together today."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-2-5",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "2 Corinthians 8:23",
                            text: "As for Titus, he is my partner and fellow worker for your benefit. And as for our brothers, they are messengers of the churches, the glory of Christ.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-2-6",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "The Priority of Gathering",
                            text: "As a Christian, throughout the seasons of life, gathering with believers is critical for spiritual health. Purposing to live our lives in unity with our brothers in Christ should be the priority. The early church gathered daily, attending the temple together and breaking bread in their homes with glad and generous hearts."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-2-7",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "How can you prioritize gathering with believers in your current season of life? What might need to change to make fellowship a higher priority?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 3 - The Mission of the Church
            Lesson(
                id: "dev-cc-3",
                trackId: "devotional-christian-community",
                title: "The Mission of the Church",
                description: "Discover the threefold mission God has given His church",
                order: 3,
                xpReward: 60,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-cc-3-1",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Why Do We Gather?",
                            text: "In communities around the world, people are gathering together. Some gather around a sport such as basketball or football. Others gather around a sale such as an auction or community yard sale. Still others come together for speeches and information. But Christians gather for a different purpose\u{2014}a unifying goal and mission: to glorify God, evangelize the lost, and edify the saints."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-2",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Hebrews 10:25",
                            text: "Not neglecting to meet together, as is the habit of some, but encouraging one another, and all the more as you see the Day drawing near.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Mission #1: Glorify God Through Worship",
                            text: "The mission of the church is to glorify God through worship of Him. As Christians gather around the world, there must be a purpose for meeting. If we were coming together as just friends, why would we not watch football? There must be a unifying purpose of gathering. As we gather, we should approach God\'s throne for the purpose of praise and worship. Praise is the desire of God from His creatures. As Psalm 117:1 states, all nations should praise the Lord. Believers are called upon to display God\'s glory through their display of God\'s grace in their lives."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-4",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Revelation 5:12",
                            text: "Saying with a loud voice, \"Worthy is the Lamb who was slain, to receive power and wealth and wisdom and might and honor and glory and blessing!\"",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-5",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Mission #2: Evangelize the Lost Through Outreach",
                            text: "The church\'s outreach method outlined in Acts is through missionaries. Acts outlines Paul\'s missionary team\'s outreaches throughout Asia. At the beginning of his first missionary journey, he was chosen by the Lord and sent out by the church at Antioch. God is the one choosing and calling those saints to glorify Himself on the foreign field, but the church is the tool God uses to send workers to spread the Gospel. Once Paul\'s mission was complete, they returned to Antioch\u{2014}establishing accountability of missionaries to their sending churches. Mission work is a collective effort by God\'s people."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-6",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Matthew 28:19-20",
                            text: "Go therefore and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, teaching them to observe all that I have commanded you. And behold, I am with you always, to the end of the age.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-7",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Mission #3: Edify the Saints Through Discipleship",
                            text: "In Matthew\'s account of the Great Commission, Jesus says outreach to the world should include discipleship. This command extends past the apostles to every believer, as Jesus promises \"I am with you always, to the end of the age.\" When we see Jesus\' example of making disciples, He clearly taught them for several years from the Word of God. Following His example, the church should clearly proclaim the Word of God doctrinally, applicably, and clearly to those in the local church community."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-8",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "What are the three aspects of the church\'s mission?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "Build buildings, raise money, grow membership"),
                                AnswerChoice(id: "b", text: "Glorify God, evangelize the lost, edify the saints"),
                                AnswerChoice(id: "c", text: "Preach, pray, sing"),
                                AnswerChoice(id: "d", text: "Study, fellowship, serve")
                            ],
                            correctAnswer: "b",
                            explanation: "The ultimate mission of the church is to glorify God through worship, evangelize the lost through outreach, and edify the saints through discipleship. The church today must forsake activities that do not accomplish God\'s goal of glorification and focus on the mission He has commanded."
                        ))
                    ),
                    LessonContent(
                        id: "dev-cc-3-9",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "Which aspect of the church\'s mission\u{2014}glorifying God, evangelizing, or edifying\u{2014}do you need to be more involved in? What is one step you can take this week?"
                        ))
                    )
                ]
            )
        ]
    ),
    // MARK: - Foundations of Faith
    Track(
        id: "devotional-foundations",
        name: "Foundations of Faith",
        description: "Explore core truths about God\'s nature and our hope in Him",
        icon: "anchor.fill",
        color: "blue",
        totalLessons: 3,
        completedLessons: 0,
        lessons: [
            // MARK: Lesson 1 - The Honesty of God
            Lesson(
                id: "dev-ff-1",
                trackId: "devotional-foundations",
                title: "The Honesty of God",
                description: "Discover why God\'s inability to lie secures your salvation",
                order: 1,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-ff-1-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Titus 1:2",
                            text: "In hope of eternal life, which God, who never lies, promised before the ages began.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-1-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "The Christian\'s Secure Hope",
                            text: "The Christian\'s hope of redemption and eternal life relies on the honesty of God. Paul\'s greeting in his letter to Titus contains the high-impact phrase \"God, who never lies.\" This phrase affirms that God not only does not lie, but He cannot lie. This is a reassuring concept because God has promised eternal life and forgiveness of sin through Christ\'s death on the cross. If God lied or deceived humanity in promising redemption, then we would have no hope of a secure eternity."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-1-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Cannot Lie vs. Never Lies",
                            text: "There is discussion over God\'s nature concerning lying. The KJV uses the phrase \"cannot lie\" but the ESV uses \"never lies.\" If God is pure, holy, and will always stay the same, He cannot lie and never will because of His preexisting, unchanging holy nature. The word \"cannot\" emphasizes that lying is impossible for God given His nature\u{2014}not just that He chooses not to lie."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-1-4",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "Why is it significant that God \"cannot lie\" (as opposed to simply choosing not to lie)?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "It means God is limited"),
                                AnswerChoice(id: "b", text: "It shows lying is impossible given His unchanging holy nature"),
                                AnswerChoice(id: "c", text: "It means God has rules to follow"),
                                AnswerChoice(id: "d", text: "It is not significant")
                            ],
                            correctAnswer: "b",
                            explanation: "God\'s inability to lie flows from His unchanging holy nature. He is pure and holy and will always stay the same\u{2014}therefore lying is not merely avoided, but impossible for Him. This gives us complete confidence in His promises."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-1-5",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Eternal Security in God\'s Honesty",
                            text: "God has promised that because of His inability to lie, we can have secure confidence in eternal life. This concept is critical to the eternal security of the believer. When unbelievers place their faith in Jesus Christ because of His finished work on the cross of Calvary, they can be assured that they will live with Christ in heaven forever. They find this assurance through God\'s unchanging nature. The unchanging honesty of God secures the believer in their salvation."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-1-6",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "How does knowing that God cannot lie affect your confidence in the promises of Scripture? What promise do you need to trust more fully today?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 2 - The Comforting Work of the Holy Spirit
            Lesson(
                id: "dev-ff-2",
                trackId: "devotional-foundations",
                title: "The Comforting Work of the Holy Spirit",
                description: "Understand your relationship with God as His child",
                order: 2,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-ff-2-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Galatians 4:6",
                            text: "And because you are sons, God has sent the Spirit of his Son into our hearts, crying, \"Abba! Father!\"",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-2-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Heirs According to the Promise",
                            text: "God promised to Abraham that the nations would be blessed through his seed. He also promised that his seed would be blessed. Galatians outlines that those who are in Christ are Abraham\'s seed and \"heirs according to the promise\" (Gal. 3:29). While this state of sonship does not immediately bring too much comfort initially, it places the son into the family of God."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-2-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "The Spirit in Our Hearts",
                            text: "God sent His Son into the world to redeem those people in bondage under the law. He then placed those who would believe in Him into a right relationship with God and gave them certain blessings. The blessing of the Holy Spirit was promised by Jesus (John 14:26) and fulfilled at Pentecost. Because of this placement as a child of God, the Christian has access to the Spirit of Jesus. Not only is He always with us, but He is placed \"into our hearts.\""
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-2-4",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "John 14:26",
                            text: "But the Helper, the Holy Spirit, whom the Father will send in my name, he will teach you all things and bring to your remembrance all that I have said to you.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-2-5",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "Complete the verse: \"And because you are sons, God has sent the Spirit of his Son into our hearts, crying...\"",
                            type: .fillBlank,
                            options: nil,
                            correctAnswer: "Abba Father",
                            explanation: "\"Abba\" is an Aramaic term meaning \"father\" with the intimacy of \"papa.\" Through the Holy Spirit, we have personal, familial access to God as our Father."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-2-6",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Abba, Father",
                            text: "The term \"Abba\" is Aramaic for \"father\" and best gives the idea of \"papa\"\u{2014}a filial term. This ministry of the Holy Spirit gives the child of God access to God the Father. The Holy Spirit gives the Christian the relationship with their Father as a child in the family in a personal way. Christians today must be comforted with the security that their fatherly relationship with their Heavenly Father provides. Share this Hope of all hopes with your neighbor today!"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-2-7",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "How does it change your prayer life to think of God as your \"Abba\" (Papa, Father)? How can you share this hope with someone this week?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 3 - Sermon on the Mount Life Preparation
            Lesson(
                id: "dev-ff-3",
                trackId: "devotional-foundations",
                title: "Sermon on the Mount Life Preparation",
                description: "Apply kingdom principles to everyday Christian living",
                order: 3,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-ff-3-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Matthew 5:9",
                            text: "Blessed are the peacemakers, for they shall be called sons of God.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "A Futuristic Passage with Present Application",
                            text: "The Sermon on the Mount is a great example of a futuristic passage that is applicable to everyday Christian living and preparation for a future life in the Millennial Kingdom. Most modern dispensationalists teach that the Sermon on the Mount was a passage directed towards Israel as a presentation of the Kingdom of God\u{2014}an offer of the Millennial Kingdom that the Jews rejected along with their Messiah."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-3",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Matthew 5:3-11",
                            text: "Blessed are the poor in spirit, for theirs is the kingdom of heaven. Blessed are those who mourn, for they shall be comforted. Blessed are the meek, for they shall inherit the earth...",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-4",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Principles for Today",
                            text: "Because the modern Christian is not Israeli, nor are they living in the Millennial Kingdom, some might think these standards of living will not work in the sin-cursed world. This problem is solved when the Christian realizes that Jesus was offering principles of godly living that can be applied to daily living. A quick example is Matthew 5:9\u{2014}the command is not a verse awarding a place in heaven based on good works. The principle Jesus was emphasizing was the spirit of peacemaking."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-5",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "What is the primary application of the Beatitudes for Christians today?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "Following these commands earns salvation"),
                                AnswerChoice(id: "b", text: "They are only for Israel in the future kingdom"),
                                AnswerChoice(id: "c", text: "They are principles of godly living we can apply now"),
                                AnswerChoice(id: "d", text: "They are outdated and no longer relevant")
                            ],
                            correctAnswer: "c",
                            explanation: "While the full realization of the Kingdom awaits the future, the Beatitudes offer principles of godly living that believers can apply to daily life now as we prepare for Christ\'s return."
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-6",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "2 Corinthians 13:11",
                            text: "Finally, brothers, rejoice. Aim for restoration, comfort one another, agree with one another, live in peace; and the God of love and peace will be with you.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-7",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Preparing for Harmonious Relationships",
                            text: "As we continue our lives striving to follow the Spirit our Lord left behind, we must strive to prepare our lifestyle for harmonious relationships with our fellow man. Paul echoes this in 2 Corinthians 13:11: \"Be of good comfort, be of one mind, live in peace; and the God of love and peace shall be with you.\""
                        ))
                    ),
                    LessonContent(
                        id: "dev-ff-3-8",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "In what relationship or situation can you actively be a peacemaker this week? How can you apply the spirit of the Beatitudes to your daily life?"
                        ))
                    )
                ]
            )
        ]
    ),
    // MARK: - Faithful Living
    Track(
        id: "devotional-faithful-living",
        name: "Faithful Living",
        description: "Practical wisdom for living out your faith with integrity",
        icon: "safari.fill",
        color: "green",
        totalLessons: 4,
        completedLessons: 0,
        lessons: [
            // MARK: Lesson 1 - The Testimony of a Christian
            Lesson(
                id: "dev-fl-1",
                trackId: "devotional-faithful-living",
                title: "The Testimony of a Christian",
                description: "Learn how obedience and wisdom define a faithful life",
                order: 1,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-fl-1-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Romans 16:19",
                            text: "For your obedience is known to all, so that I rejoice over you, but I want you to be wise as to what is good and innocent as to what is evil.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-1-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "A Testimony of Obedience",
                            text: "In the eyes of theological liberals, fundamentalists have been known for ignorance, intolerance, and for having a reactionary mentality. Fundamentalists should instead hold fast to obeying the Scripture and be discerning of false teaching by immersing themselves in the truth of God\'s Word. The Roman believers had a particular testimony\u{2014}it was evident that they were obedient to the Scripture. Despite having battled dissension and false doctrine, the believers remained strong in their personal lives."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-1-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Wise to Good, Innocent to Evil",
                            text: "Paul acknowledged their hard work in living godly lives in an impure world, but he also challenged them: to live godly, obedient lives in this world, they must also be wise to good and innocent to evil. Instead of dwelling on the evil surrounding them, they were to focus on what is good and truthful. Instead of filling their minds with false teaching, a wise Christian will become wise to the doctrine and faithful teaching in Scripture."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-1-4",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "According to Romans 16:19, what two qualities should characterize Christians?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "Wealthy and powerful"),
                                AnswerChoice(id: "b", text: "Wise to good and innocent to evil"),
                                AnswerChoice(id: "c", text: "Popular and influential"),
                                AnswerChoice(id: "d", text: "Quiet and hidden")
                            ],
                            correctAnswer: "b",
                            explanation: "Paul calls believers to be \"wise as to what is good\"\u{2014}deeply knowledgeable about truth\u{2014}while remaining \"innocent as to what is evil\"\u{2014}not immersed in or deceived by evil."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-1-5",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Discerning Truth from Error",
                            text: "Believers who want to maintain the unity of the church and reject false teaching must be discerning of the truth and error they ingest. Instead of filling our minds with \"TikTok theology,\" we must immerse ourselves in the truth of God\'s Word. If we want to reject the stereotype of intolerance, we must also have a clear testimony of obedience to God\'s Word."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-1-6",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "What are you filling your mind with? How can you become more \"wise to good\" and \"innocent to evil\" in your media consumption and relationships?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 2 - The Way of the Wicked
            Lesson(
                id: "dev-fl-2",
                trackId: "devotional-faithful-living",
                title: "The Way of the Wicked",
                description: "Understand why Scripture describes wickedness as utter darkness",
                order: 2,
                xpReward: 50,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-fl-2-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 4:19",
                            text: "The way of the wicked is like deep darkness; they do not know over what they stumble.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Walking in Darkness",
                            text: "\"I can\'t see anything! This is great! Hey friend, why don\'t you join us? We\'re having a great time. OH! Excuse me, I almost fell. I tripped over something\u{2026}Boy, we can\'t really see where we are going.\" The way of the wicked is sheer darkness. They are in denial of God; walking towards a certain end; carrying those around them with them. This idea is prevalent in the biblical book of Proverbs."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "An Abomination to the Lord",
                            text: "The way of the wicked is like walking through a cave without a lamp: utter, gloomy darkness. They are blind toward the fear of the Lord and the knowledge of Him. The wicked are living in total depravity\u{2014}a gloom that will bring them to a certain end. Not only is the way of the wicked not joyful, but it is an abomination to the Lord. Not just their way, but the very thoughts of the wicked are an abomination (Prov. 15:9, 26). This fact alone should make any decent person utterly avoid the path of the wicked."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-4",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 15:9",
                            text: "The way of the wicked is an abomination to the LORD, but he loves him who pursues righteousness.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-5",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "According to Proverbs, what is the way of the wicked compared to?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "A well-lit highway"),
                                AnswerChoice(id: "b", text: "Deep darkness where they stumble"),
                                AnswerChoice(id: "c", text: "A narrow path"),
                                AnswerChoice(id: "d", text: "A garden")
                            ],
                            correctAnswer: "b",
                            explanation: "Proverbs 4:19 says the way of the wicked is like deep darkness\u{2014}they cannot even see what causes them to stumble. In contrast, \"the path of the righteous is like the light of dawn\" (Prov. 4:18)."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-6",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Deceit and Violence",
                            text: "There are two main characteristics of the way of the wicked: it is deceitful and violent. First, they deceive themselves and others. Their counsel is deceitful, likely for their own gain. They sow deceit and are seduced by their own seductiveness\u{2014}\"Oh, what a bitter web.\" Second, their path leads to violence both for themselves and those around them. Proverbs uses words like blood, violence, evil, and grave to describe the wickeds\' end."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-7",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 12:5",
                            text: "The thoughts of the righteous are just; the counsels of the wicked are deceitful.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-2-8",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "Are there any areas of your life where you\'re walking in darkness rather than in the light? What steps can you take to pursue righteousness instead?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 3 - The Righteous vs. The Wicked
            Lesson(
                id: "dev-fl-3",
                trackId: "devotional-faithful-living",
                title: "The Righteous vs. The Wicked",
                description: "Explore the stark contrast between blessing and cursing in Proverbs",
                order: 3,
                xpReward: 55,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-fl-3-1",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 10:7",
                            text: "The memory of the righteous is a blessing, but the name of the wicked will rot.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-2",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Cursing vs. Blessing",
                            text: "In Proverbs, the concept of \"versus\" is very prominent through antithetical parallelism\u{2014}contrasting the hope of the righteous with the wicked to show the results of contrasting lifestyles. For the righteous there is joy, but for the wicked there is only the hope of perishing. Proverbs displays cursing for the wicked and blessing for the righteous at four levels: logical, providential, spiritual, and eternal."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-3",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 3:33",
                            text: "The LORD\'s curse is on the house of the wicked, but he blesses the dwelling of the righteous.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-4",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "A Lasting Legacy",
                            text: "After the wicked are dead, their name will be like putrid carrion, but the righteous will be blessing others even after their death. The righteous person\'s good works not only follow them, but live behind them. As one commentator put it, \"The good man helps to make others holy whilst he is lying in the grave.\" The wicked cover violence with their mouths and conceal themselves, but the righteous have nothing to hide\u{2014}their mouth is an open spring of pure thoughts."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-5",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "According to Proverbs, what happens to the legacy of the righteous vs. the wicked?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "Both are forgotten equally"),
                                AnswerChoice(id: "b", text: "The righteous are forgotten, the wicked remembered"),
                                AnswerChoice(id: "c", text: "The righteous are a blessing, the wicked name rots"),
                                AnswerChoice(id: "d", text: "Neither matters after death")
                            ],
                            correctAnswer: "c",
                            explanation: "Proverbs 10:7 teaches that the memory of the righteous is a blessing\u{2014}their legacy endures\u{2014}while the name of the wicked will rot and be forgotten in disgrace."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-6",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 10:3",
                            text: "The LORD does not let the righteous go hungry, but he thwarts the craving of the wicked.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-7",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Life vs. Death",
                            text: "Another contrast between the righteous and the wicked is life vs. death. The wicked receive Sheol, utter destruction, or the place where the dead live. Their reward is punishment, and their fear will destroy them. In contrast, the righteous will have life rather than death and security rather than whirlwind. \"The righteous shall never be removed: but the wicked shall not inhabit the earth\" (Prov. 10:30)."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-8",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 11:23",
                            text: "The desire of the righteous ends only in good; the expectation of the wicked in wrath.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-3-9",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "What kind of legacy are you building? How can the wisdom of Proverbs shape your daily choices toward righteousness and lasting blessing?"
                        ))
                    )
                ]
            ),
            // MARK: Lesson 4 - The End of the Wicked
            Lesson(
                id: "dev-fl-4",
                trackId: "devotional-faithful-living",
                title: "The End of the Wicked",
                description: "Learn why the wise authors of Proverbs urge choosing righteousness",
                order: 4,
                xpReward: 60,
                isCompleted: false,
                content: [
                    LessonContent(
                        id: "dev-fl-4-1",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "The Purpose of Proverbs",
                            text: "Throughout Proverbs, the wise authors strive to convince their readers to choose the wise and righteous path. The basic premise is that the wicked will fall and be destroyed; however, the righteous will be lifted through wisdom from God. This path of having a good relationship with God does not necessarily mean the righteous never fall, but it does mean that the righteous will have a good end. Because of the genre of the book, these statements should be viewed as proverbs\u{2014}general rules of wisdom."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-2",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 1:25-27",
                            text: "Because you have ignored all my counsel and would have none of my reproof, I also will laugh at your calamity; I will mock when terror strikes you, when terror strikes you like a storm and your calamity comes like a whirlwind, when distress and anguish come upon you.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-3",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "Sudden Desolation",
                            text: "The end of the wicked is desolation. The Hebrew word for \"desolation\" in Proverbs contains the idea of a tempest, storm, or waste. Combined with the words \"sudden fear,\" it paints the picture of a sudden, destructive, damaging, frightening end for the wicked person. The wicked lust after their desires, but they end in wrath. The Hebrew word for \"expectation\" (tiqvah) means hope, desire, or \"the thing that I long for.\" Wickedness is frustrating to the wicked person\u{2014}the way of the transgressor is hard (Prov. 13:15)."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-4",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 2:22",
                            text: "But the wicked will be cut off from the land, and the treacherous will be rooted out of it.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-5",
                        type: .question,
                        data: .question(QuestionContent(
                            question: "What happens to the \"hope\" of the wicked when they die, according to Proverbs?",
                            type: .multipleChoice,
                            options: [
                                AnswerChoice(id: "a", text: "It is fulfilled"),
                                AnswerChoice(id: "b", text: "It perishes with them"),
                                AnswerChoice(id: "c", text: "It is passed to their children"),
                                AnswerChoice(id: "d", text: "It does not matter")
                            ],
                            correctAnswer: "b",
                            explanation: "Proverbs 11:7 says, \"When a wicked man dies, his expectation shall perish: and the hope of unjust men perishes.\" The wicked lose everything when they die\u{2014}their hopes and desires come to nothing."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-6",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 11:7",
                            text: "When the wicked dies, his hope will perish, and the expectation of wealth perishes too.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-7",
                        type: .explanation,
                        data: .explanation(ExplanationContent(
                            title: "No Escape from Judgment",
                            text: "Proverbs shows the wicked person\'s destruction of hope, stable foundation, and future. Even if wicked \"men clasp one another\'s hands in strong confederacy,\" they will not go without God\'s punishment (Prov. 11:21). The wicked are submitted to a shortened life: \"The fear of the LORD prolongs days, but the years of the wicked shall be shortened\" (Prov. 10:27). The wicked are shown to have a bitter end\u{2014}an enormously acrimonious life and death, horrendous and untimely, quite unlike the end of the righteous."
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-8",
                        type: .scripture,
                        data: .scripture(ScriptureContent(
                            reference: "Proverbs 10:27-28",
                            text: "The fear of the LORD prolongs life, but the years of the wicked will be short. The hope of the righteous brings joy, but the expectation of the wicked will perish.",
                            version: "ESV"
                        ))
                    ),
                    LessonContent(
                        id: "dev-fl-4-9",
                        type: .reflection,
                        data: .reflection(ReflectionContent(
                            prompt: "What is your hope built upon? How does the warning of Proverbs about the end of the wicked motivate you to pursue wisdom and righteousness?"
                        ))
                    )
                ]
            )
        ]
    )
]
}
