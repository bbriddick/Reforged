from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT_PATH = OUTPUT_DIR / "reforged-app-summary.pdf"


def register_fonts() -> None:
    fonts_dir = ROOT / "Reforged" / "Resources" / "Fonts"
    pdfmetrics.registerFont(TTFont("LibreBaskerville", str(fonts_dir / "LibreBaskerville.ttf")))
    pdfmetrics.registerFont(TTFont("Roboto", str(fonts_dir / "Roboto.ttf")))
    pdfmetrics.registerFont(TTFont("Roboto-Italic", str(fonts_dir / "Roboto-Italic.ttf")))


def bullet_paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(f"&bull;&nbsp;{text}", style)


def build_pdf() -> Path:
    register_fonts()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    doc = SimpleDocTemplate(
        str(OUTPUT_PATH),
        pagesize=letter,
        leftMargin=0.55 * inch,
        rightMargin=0.55 * inch,
        topMargin=0.5 * inch,
        bottomMargin=0.45 * inch,
        title="Reforged App Summary",
        author="Codex",
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "Title",
        parent=styles["Title"],
        fontName="LibreBaskerville",
        fontSize=20,
        leading=24,
        textColor=colors.HexColor("#1F2937"),
        spaceAfter=5,
        alignment=TA_LEFT,
    )
    subtitle_style = ParagraphStyle(
        "Subtitle",
        parent=styles["BodyText"],
        fontName="Roboto-Italic",
        fontSize=8.5,
        leading=10.5,
        textColor=colors.HexColor("#5B6470"),
        spaceAfter=10,
    )
    section_style = ParagraphStyle(
        "Section",
        parent=styles["Heading2"],
        fontName="Roboto",
        fontSize=10,
        leading=12,
        textColor=colors.HexColor("#8B5E34"),
        spaceBefore=0,
        spaceAfter=4,
    )
    body_style = ParagraphStyle(
        "Body",
        parent=styles["BodyText"],
        fontName="Roboto",
        fontSize=8.5,
        leading=10.6,
        textColor=colors.HexColor("#24303F"),
        spaceAfter=0,
    )
    bullet_style = ParagraphStyle(
        "Bullet",
        parent=body_style,
        leftIndent=0,
        firstLineIndent=0,
        bulletIndent=0,
        spaceAfter=2.2,
    )
    compact_style = ParagraphStyle(
        "Compact",
        parent=body_style,
        fontSize=8.1,
        leading=10.0,
    )

    left_column = [
        Paragraph("What It Is", section_style),
        Paragraph(
            "Reforged is a gamified iOS Bible reading, study, and Scripture memory app built with SwiftUI. "
            "It combines reading, learning tracks, and spaced-repetition practice inside a progression system.",
            body_style,
        ),
        Spacer(1, 6),
        Paragraph("Who It's For", section_style),
        Paragraph(
            "Primary persona: believers who want a structured daily habit for Bible reading, study, and memorization.",
            body_style,
        ),
        Spacer(1, 6),
        Paragraph("What It Does", section_style),
        bullet_paragraph("Reads 5 Bible translations: ESV, KJV, CSB, NKJV, and NASB.", bullet_style),
        bullet_paragraph("Plays ESV audio with playback speed and skip controls.", bullet_style),
        bullet_paragraph("Supports search, highlights, notes, and tap-for-Strong's word study.", bullet_style),
        bullet_paragraph("Runs Scripture memory in 6 practice modes with SM-2 review scheduling.", bullet_style),
        bullet_paragraph("Delivers doctrine and devotional learning tracks with lessons, quizzes, and reflections.", bullet_style),
        bullet_paragraph("Adds XP, levels, streaks, streak freezes, badges, and daily insights.", bullet_style),
        bullet_paragraph("Syncs profile and progress with CloudKit and surfaces streak status in a widget.", bullet_style),
    ]

    right_column = [
        Paragraph("How It Works", section_style),
        bullet_paragraph(
            "App shell: `ReforgedApp` launches `ContentView`, which shows onboarding first and then the main navigation.",
            compact_style,
        ),
        bullet_paragraph(
            "State and storage: `AppState` is the central `@MainActor` observable object for user profile, tracks, memory verses, and daily insight; it persists data to `UserDefaults`.",
            compact_style,
        ),
        bullet_paragraph(
            "Sync path: when Apple Sign In and CloudKit are available, `AppState` syncs profile, memory verses, highlights, notes, and track progress through `CloudKitSyncService`.",
            compact_style,
        ),
        bullet_paragraph(
            "Bible data path: KJV content is bundled locally; ESV content and audio come from `ESVService`; CSB, NKJV, and NASB come from `ApiBibleService`; both cache chapters on device.",
            compact_style,
        ),
        bullet_paragraph(
            "Study and sharing: word-study uses original-language and Strong's services plus bundled lexicon files; share cards use bundled backgrounds and `UnsplashService`.",
            compact_style,
        ),
        bullet_paragraph(
            "Extension path: `ReforgedWidget` reads shared app-group `UserDefaults` to calculate and display the current reading streak.",
            compact_style,
        ),
        Spacer(1, 6),
        Paragraph("How To Run", section_style),
        bullet_paragraph("Open `Reforged.xcodeproj` in Xcode.", bullet_style),
        bullet_paragraph("Select the `Reforged` scheme and an iOS 16.0+ simulator or device.", bullet_style),
        bullet_paragraph("Build and run, or use the repo command: `xcodebuild -project Reforged.xcodeproj -scheme Reforged -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.", compact_style),
        bullet_paragraph("Extra local setup steps or secret-management instructions: Not found in repo.", bullet_style),
    ]

    table = Table(
        [[left_column, right_column]],
        colWidths=[3.58 * inch, 3.52 * inch],
        hAlign="LEFT",
    )
    table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("BACKGROUND", (0, 0), (0, 0), colors.HexColor("#F7F1E8")),
                ("BACKGROUND", (1, 0), (1, 0), colors.HexColor("#F8FAFC")),
                ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#D6DCE5")),
                ("INNERGRID", (0, 0), (-1, -1), 0.6, colors.HexColor("#D6DCE5")),
                ("LEFTPADDING", (0, 0), (-1, -1), 14),
                ("RIGHTPADDING", (0, 0), (-1, -1), 14),
                ("TOPPADDING", (0, 0), (-1, -1), 12),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
            ]
        )
    )

    story = [
        Paragraph("Reforged", title_style),
        Paragraph("One-page repo-based product summary", subtitle_style),
        table,
    ]

    doc.build(story)
    return OUTPUT_PATH


if __name__ == "__main__":
    path = build_pdf()
    print(path)
