import UIKit
import SwiftUI

// MARK: - Export Service

@MainActor
final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - Public API

    func exportAsPDF(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> URL? {
        let pageRect  = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4
        let margin: CGFloat = 50
        let contentRect = CGRect(
            x: margin, y: margin,
            width: pageRect.width - margin * 2,
            height: pageRect.height - margin * 2
        )

        let content     = buildPDFAttributedString(journalEntries: journalEntries, bibleNotes: bibleNotes)
        let framesetter = CTFramesetterCreateWithAttributedString(content)
        var charOffset  = 0
        let total       = content.length
        let tempURL     = tmpURL("Reforged Notes.pdf")
        let renderer    = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: tempURL) { ctx in
                while charOffset < total {
                    ctx.beginPage()

                    let path  = CGPath(rect: contentRect, transform: nil)
                    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(charOffset, 0), path, nil)

                    if let gc = UIGraphicsGetCurrentContext() {
                        gc.saveGState()
                        gc.translateBy(x: 0, y: pageRect.height)
                        gc.scaleBy(x: 1.0, y: -1.0)
                        CTFrameDraw(frame, gc)
                        gc.restoreGState()
                    }

                    let visible = CTFrameGetVisibleStringRange(frame)
                    if visible.length == 0 { break }
                    charOffset = visible.location + visible.length
                }
            }
            return tempURL
        } catch {
            return nil
        }
    }

    func exportAsText(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> URL? {
        let content = buildTextContent(journalEntries: journalEntries, bibleNotes: bibleNotes)
        let url     = tmpURL("Reforged Notes.txt")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { return nil }
    }

    func exportAsDocx(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> URL? {
        let files: [(String, Data)] = [
            ("[Content_Types].xml", docxContentTypes.data(using: .utf8)!),
            ("_rels/.rels",        docxRels.data(using: .utf8)!),
            ("word/_rels/document.xml.rels", docxWordRels.data(using: .utf8)!),
            ("word/document.xml",  buildDocxBody(journalEntries: journalEntries, bibleNotes: bibleNotes).data(using: .utf8)!)
        ]
        let zipData = makeZip(files: files)
        let url = tmpURL("Reforged Notes.docx")
        do {
            try zipData.write(to: url)
            return url
        } catch { return nil }
    }

    func exportAsZip(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> URL? {
        var files: [(String, Data)] = []

        for (i, entry) in journalEntries.enumerated() {
            let dateStr = formattedDate(isoDate(entry.date)) ?? "Entry \(i+1)"
            let safeName = dateStr.replacingOccurrences(of: "/", with: "-")
            let content  = buildEntryText(entry)
            if let data = content.data(using: .utf8) {
                files.append(("Journal/\(safeName).txt", data))
            }
        }

        for note in bibleNotes {
            let safeName = note.reference.replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: " ", with: "_")
            let content  = buildNoteText(note)
            if let data = content.data(using: .utf8) {
                files.append(("Bible Notes/\(safeName).txt", data))
            }
        }

        if files.isEmpty { return nil }

        let zipData = makeZip(files: files)
        let url = tmpURL("Reforged Notes.zip")
        do {
            try zipData.write(to: url)
            return url
        } catch { return nil }
    }

    // MARK: - Content Builders

    private func buildPDFAttributedString(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let navy   = UIColor(red: 26/255, green: 42/255, blue: 74/255, alpha: 1)
        let gold   = UIColor(red: 184/255, green: 134/255, blue: 11/255, alpha: 1)

        func add(_ text: String, font: UIFont, color: UIColor = .label) {
            result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
        }

        add("My Reforged Notes\n", font: .systemFont(ofSize: 26, weight: .bold), color: navy)
        add("Exported \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))\n\n",
            font: .systemFont(ofSize: 12), color: .secondaryLabel)

        if !journalEntries.isEmpty {
            add("Journal Reflections\n", font: .systemFont(ofSize: 18, weight: .bold))
            add(String(repeating: "─", count: 40) + "\n\n", font: .systemFont(ofSize: 11), color: .secondaryLabel)

            for entry in journalEntries {
                let dateStr = formattedDate(isoDate(entry.date)) ?? entry.date
                add("\(dateStr)\n", font: .systemFont(ofSize: 13, weight: .semibold))

                if !entry.allLinkedVerses.isEmpty {
                    add("Verses: \(entry.allLinkedVerses.joined(separator: " · "))\n",
                        font: .systemFont(ofSize: 11), color: gold)
                }
                if let prompt = entry.prompt {
                    add("Prompt: \(prompt)\n", font: .systemFont(ofSize: 11), color: .secondaryLabel)
                }
                add("\n\(entry.renderedContentText)\n\n", font: .systemFont(ofSize: 13))
                add(String(repeating: "─", count: 40) + "\n\n", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            }
        }

        if !bibleNotes.isEmpty {
            add("\nBible Notes\n", font: .systemFont(ofSize: 18, weight: .bold))
            add(String(repeating: "─", count: 40) + "\n\n", font: .systemFont(ofSize: 11), color: .secondaryLabel)

            for note in bibleNotes {
                add("\(note.reference)\n", font: .systemFont(ofSize: 13, weight: .semibold), color: gold)
                add("\(formattedDate(isoDate(note.updatedAt)) ?? note.updatedAt)\n",
                    font: .systemFont(ofSize: 11), color: .secondaryLabel)
                if !note.crossReferences.isEmpty {
                    add("Cross-refs: \(note.crossReferences.joined(separator: " · "))\n",
                        font: .systemFont(ofSize: 11), color: .secondaryLabel)
                }
                add("\n\(note.content)\n\n", font: .systemFont(ofSize: 13))
                add(String(repeating: "─", count: 40) + "\n\n", font: .systemFont(ofSize: 11), color: .secondaryLabel)
            }
        }

        return result
    }

    private func buildTextContent(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> String {
        var lines = [
            "REFORGED — MY NOTES",
            "Exported \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))",
            String(repeating: "=", count: 50),
            ""
        ]

        if !journalEntries.isEmpty {
            lines += ["JOURNAL REFLECTIONS", String(repeating: "-", count: 50)]
            for entry in journalEntries { lines += buildEntryLines(entry) }
        }

        if !bibleNotes.isEmpty {
            lines += ["", "BIBLE NOTES", String(repeating: "-", count: 50)]
            for note in bibleNotes { lines += buildNoteLines(note) }
        }

        return lines.joined(separator: "\n")
    }

    private func buildEntryText(_ entry: JournalEntry) -> String {
        buildEntryLines(entry).joined(separator: "\n")
    }

    private func buildNoteText(_ note: VerseNote) -> String {
        buildNoteLines(note).joined(separator: "\n")
    }

    private func buildEntryLines(_ entry: JournalEntry) -> [String] {
        var lines: [String] = [""]
        lines.append("Date: \(formattedDate(isoDate(entry.date)) ?? entry.date)")
        if !entry.allLinkedVerses.isEmpty {
            lines.append("Verses: \(entry.allLinkedVerses.joined(separator: ", "))")
        }
        if let p = entry.prompt { lines.append("Prompt: \(p)") }
        lines += ["", entry.renderedContentText, String(repeating: "-", count: 30)]
        return lines
    }

    private func buildNoteLines(_ note: VerseNote) -> [String] {
        var lines: [String] = [""]
        lines.append("Reference: \(note.reference)")
        lines.append("Date: \(formattedDate(isoDate(note.updatedAt)) ?? note.updatedAt)")
        if !note.crossReferences.isEmpty {
            lines.append("Cross-refs: \(note.crossReferences.joined(separator: ", "))")
        }
        lines += ["", note.content, String(repeating: "-", count: 30)]
        return lines
    }

    // MARK: - DOCX Builder

    private var docxContentTypes: String { """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
    }

    private var docxRels: String { """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private var docxWordRels: String { """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
        """
    }

    private func buildDocxBody(journalEntries: [JournalEntry], bibleNotes: [VerseNote]) -> String {
        var paras = ""

        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
        }

        func para(_ text: String, bold: Bool = false, sz: Int = 24, color: String = "000000") -> String {
            let b = bold ? "<w:b/>" : ""
            return """
            <w:p><w:r><w:rPr>\(b)<w:sz w:val="\(sz)"/><w:color w:val="\(color)"/></w:rPr><w:t xml:space="preserve">\(esc(text))</w:t></w:r></w:p>
            """
        }

        func blank() -> String { "<w:p/>" }

        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        paras += para("My Reforged Notes", bold: true, sz: 52, color: "1A2A4A")
        paras += para("Exported \(dateStr)", sz: 20, color: "888888")
        paras += blank()

        if !journalEntries.isEmpty {
            paras += para("Journal Reflections", bold: true, sz: 36)
            paras += blank()

            for entry in journalEntries {
                let dateText = formattedDate(isoDate(entry.date)) ?? entry.date
                paras += para(dateText, bold: true, sz: 26)

                if !entry.allLinkedVerses.isEmpty {
                    paras += para("Verses: \(entry.allLinkedVerses.joined(separator: " · "))", sz: 20, color: "B8860B")
                }
                if let p = entry.prompt {
                    paras += para("Prompt: \(p)", sz: 20, color: "888888")
                }
                paras += blank()
                for line in entry.renderedContentText.components(separatedBy: "\n") {
                    paras += para(line)
                }
                paras += blank()
                paras += para(String(repeating: "─", count: 36), sz: 18, color: "CCCCCC")
                paras += blank()
            }
        }

        if !bibleNotes.isEmpty {
            paras += para("Bible Notes", bold: true, sz: 36)
            paras += blank()

            for note in bibleNotes {
                paras += para(note.reference, bold: true, sz: 26, color: "B8860B")
                paras += para(formattedDate(isoDate(note.updatedAt)) ?? note.updatedAt, sz: 20, color: "888888")
                if !note.crossReferences.isEmpty {
                    paras += para("Cross-refs: \(note.crossReferences.joined(separator: " · "))", sz: 20, color: "888888")
                }
                paras += blank()
                for line in note.content.components(separatedBy: "\n") {
                    paras += para(line)
                }
                paras += blank()
                paras += para(String(repeating: "─", count: 36), sz: 18, color: "CCCCCC")
                paras += blank()
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>\(paras)</w:body>
        </w:document>
        """
    }

    // MARK: - ZIP Archive (pure Swift, no compression)

    private func makeZip(files: [(String, Data)]) -> Data {
        var archive = Data()
        var centralDir = Data()
        var offsets = [Int]()

        for (name, data) in files {
            offsets.append(archive.count)
            let nameData = name.data(using: .utf8)!
            let crc = crc32(data)

            archive += [0x50, 0x4B, 0x03, 0x04]       // Local file signature
            archive += u16(20)                          // Version needed
            archive += u16(0)                           // Flags
            archive += u16(0)                           // Compression: stored
            archive += u16(0); archive += u16(0)        // Mod time/date
            archive += u32(crc)
            archive += u32(UInt32(data.count))
            archive += u32(UInt32(data.count))
            archive += u16(UInt16(nameData.count))
            archive += u16(0)                           // Extra field length
            archive += nameData
            archive += data
        }

        let cdStart = archive.count

        for (i, (name, data)) in files.enumerated() {
            let nameData = name.data(using: .utf8)!
            let crc = crc32(data)

            centralDir += [0x50, 0x4B, 0x01, 0x02]     // Central dir signature
            centralDir += u16(20); centralDir += u16(20)
            centralDir += u16(0); centralDir += u16(0)
            centralDir += u16(0); centralDir += u16(0)
            centralDir += u32(crc)
            centralDir += u32(UInt32(data.count))
            centralDir += u32(UInt32(data.count))
            centralDir += u16(UInt16(nameData.count))
            centralDir += u16(0); centralDir += u16(0)
            centralDir += u16(0); centralDir += u16(0)
            centralDir += u32(0)
            centralDir += u32(UInt32(offsets[i]))
            centralDir += nameData
        }

        archive += centralDir

        // End of central directory
        archive += [0x50, 0x4B, 0x05, 0x06]
        archive += u16(0); archive += u16(0)
        archive += u16(UInt16(files.count))
        archive += u16(UInt16(files.count))
        archive += u32(UInt32(centralDir.count))
        archive += u32(UInt32(cdStart))
        archive += u16(0)

        return archive
    }

    private func u16(_ v: UInt16) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8(v >> 8)]
    }

    private func u32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)]
    }

    private func crc32(_ data: Data) -> UInt32 {
        var table = [UInt32](repeating: 0, count: 256)
        for i: UInt32 in 0..<256 {
            var c = i
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
            table[Int(i)] = c
        }
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }

    // MARK: - Helpers

    private func tmpURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func isoDate(_ s: String) -> Date? {
        ISO8601DateFormatter().date(from: s)
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }
}

