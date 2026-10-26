"""Compose real Control geometry offline; this is not a Godot GPU screenshot."""
import base64
import html
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
source = Path(sys.argv[1])
data = json.loads(source.read_text())
width, height = data["size"]
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">', '<rect width="100%" height="100%" fill="#0c110e"/>']
for part in data["parts"]:
    x, y, w, h = part["rect"]
    if w <= 0 or h <= 0:
        continue
    if "background" in part:
        svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#{part["background"]}" stroke="#{part["border"]}"/>')
    if "image" in part:
        image = root / "godot" / part["image"].removeprefix("res://")
        if image.is_file():
            mime = "image/svg+xml" if image.suffix == ".svg" else "image/png"
            content = base64.b64encode(image.read_bytes()).decode()
            aspect = "xMidYMid slice" if part.get("stretch") == 6 else "xMidYMid meet"
            svg.append(f'<svg x="{x}" y="{y}" width="{w}" height="{h}" overflow="hidden"><image width="{w}" height="{h}" preserveAspectRatio="{aspect}" href="data:{mime};base64,{content}"/></svg>')
    if not part.get("text"):
        continue
    size = part["fontSize"]
    lines = part["text"].split("\n")
    align = part["alignment"]
    anchor = ["start", "middle", "end"][min(align, 2)]
    tx = x + (w / 2 if align == 1 else w - 12 if align == 2 else 12 if part["kind"] != "Label" else 0)
    ty = y + (h - len(lines) * size * 1.35) / 2 + size if part["centered"] else y + size
    for index, line in enumerate(lines):
        text = html.escape(line)
        svg.append(f'<text x="{tx}" y="{ty + index * size * 1.35}" fill="#{part["color"]}" font-family="Noto Serif CJK SC,Songti SC,serif" font-size="{size}" text-anchor="{anchor}">{text}</text>')
svg.append("</svg>")
target = source.with_suffix(".svg")
target.write_text("\n".join(svg))
subprocess.run(["rsvg-convert", "--unlimited", str(target), "-o", str(source.with_suffix(".png"))], check=True)
print(source.with_suffix(".png"))
