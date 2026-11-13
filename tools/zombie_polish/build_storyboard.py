from pathlib import Path
import json

from PIL import Image
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

source = Path(__file__).resolve().parent
project = source.parents[1]
report = json.loads((source / "storyboard-results.json").read_text(encoding="utf-8"))
frames = report["frames"]
chapters = [
    ("Arrive unarmed", "Follow the first objective into Reception and pick up the emergency pistol."),
    ("Find supplies", "Recover the fuse and expand your loadout with the marked Benelli M4 case."),
    ("Cross the courtyard", "Face an infected walker and find the control relay at the glazed entrance."),
    ("Prepare and restore", "Buy an upgrade with scrap and install both parts at the substation."),
    ("Secure the route", "Check in with Shaun, then clear the brute from the courtyard."),
    ("Drive to extraction", "Take the wheel and cross the open gate to reach the debrief."),
]
if not report["passed"] or len(frames) != len(chapters) * 2:
    raise RuntimeError("A passing native run with twelve captures is required.")

font_dir = Path("C:/Windows/Fonts")
for alias, filename in (("UI", "segoeui.ttf"), ("Semibold", "seguisb.ttf"), ("Bold", "segoeuib.ttf")):
    pdfmetrics.registerFont(TTFont(alias, str(font_dir / filename)))

out = project / "output/pdf/After-Hours-Gameplay-Storyboard.pdf"
out.parent.mkdir(parents=True, exist_ok=True)
W, H = 1120, 650
BG, PANEL, LINE, INK, MUTED, LIME = map(HexColor,
    ("#101323", "#1B2034", "#333C54", "#F6F7FC", "#AFB8CF", "#E1FA46"))
page = canvas.Canvas(str(out), pagesize=(W, H), pageCompression=1)
page.setTitle("After Hours | Gameplay storyboard")
page.setAuthor("ENSA Games")

def label(x, y, value, font="UI", size=14, color=INK):
    page.setFont(font, size)
    page.setFillColor(color)
    page.drawString(x, y, value)

def rule(y):
    page.setStrokeColor(LINE)
    page.setLineWidth(0.75)
    page.line(36, y, W - 36, y)

def paragraph(x, y, value, width):
    line = ""
    for word in value.split():
        candidate = " ".join(filter(None, [line, word]))
        if line and pdfmetrics.stringWidth(candidate, "UI", 15) > width:
            label(x, y, line, size=15, color=MUTED)
            y -= 21
            line = word
        else:
            line = candidate
    if line:
        label(x, y, line, size=15, color=MUTED)

def panel(frame, x):
    y, width, image_y, image_h = 107, 513, 205, 288.5625
    page.setFillColor(PANEL)
    page.roundRect(x, y, width, image_y + image_h - y, 8, fill=1, stroke=0)
    with Image.open(source / frame["image"]) as image:
        if image.width * 9 != image.height * 16:
            raise RuntimeError(f"Unexpected capture aspect ratio for {frame['id']}")
        page.drawImage(ImageReader(image.convert("RGB")), x, image_y, width, image_h)
    number, title = frame["title"].split(" / ", 1)
    label(x + 17, 174, number, "Bold", 15, LIME)
    label(x + 48, 172, title, "Semibold", 23)
    paragraph(x + 17, 146, frame["detail"], width - 34)

for i, (title, subtitle) in enumerate(chapters):
    page.setFillColor(BG)
    page.rect(0, 0, W, H, fill=1, stroke=0)
    page.setFillColor(LIME)
    page.rect(36, 616, 17, 3, fill=1, stroke=0)
    label(63, 612, "ENSA GAMES  /  ZOMBIE RPG", "Semibold", 13, LIME)
    page.setFont("Semibold", 13)
    page.setFillColor(MUTED)
    page.drawRightString(W - 36, 612, "AFTER HOURS  /  ZB-2026-001")
    label(36, 553, title, "Bold", 43)
    label(38, 524, subtitle, size=17, color=MUTED)
    panel(frames[2 * i], 36)
    panel(frames[2 * i + 1], 571)
    rule(84)
    label(36, 60, f"Native Godot captures  /  {report['checks']} playtest checks passed", "Semibold", 13)
    label(36, 39, "Scripted positioning between chapters. Unrelated enemies held for repeatable captures.", size=12, color=MUTED)
    page.setFont("Semibold", 15)
    page.setFillColor(LIME)
    page.drawRightString(W - 36, 55, f"{i + 1:02}  /  {len(chapters):02}")
    page.showPage()
page.save()
print(out)
