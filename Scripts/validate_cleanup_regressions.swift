import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Validation failed: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct CleanupValidationRunner {
    static func main() {
        let parsed = BundledCSVSupport.parseLine(#""id";"John 3:16";"He said ""hello""";"John 3:16""#)
        expect(parsed.count == 4, "CSV parser should preserve four columns")
        expect(parsed[1] == "John 3:16", "CSV parser should keep separator-delimited columns")
        expect(BundledCSVSupport.cleanText(#""He said ""hello""""#) == #"He said "hello""#, "CSV cleaner should unescape quoted text")

        expect(JournalPrompts.all.count >= 10, "Journal prompts should include the bundled prompt set")
        let randomPrompts = JournalPrompts.random(count: 4)
        expect(randomPrompts.count == 4, "Journal prompt helper should return the requested number of prompts when enough prompts exist")
        expect(Set(randomPrompts).count == randomPrompts.count, "Journal prompt helper should not duplicate prompts within a sample")

        print("Cleanup validation passed")
    }
}
