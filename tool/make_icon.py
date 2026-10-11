"""앱 아이콘: 남색 바탕 + 해·구름 + 높이가 다른 세 막대(기관별 비교). python -X utf8 tool/make_icon.py"""
from pathlib import Path

from PIL import Image, ImageDraw

S = 1024
root = Path(__file__).resolve().parent.parent


def draw() -> Image.Image:
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, S, S], radius=220, fill=(40, 53, 147))
    d.ellipse([560, 170, 840, 450], fill=(255, 193, 7))  # 해
    white = (255, 255, 255)
    for box in ([200, 300, 520, 620], [380, 220, 700, 540], [560, 330, 820, 590]):  # 구름
        d.ellipse(box, fill=white)
    d.rounded_rectangle([200, 450, 820, 620], radius=80, fill=white)
    for x, h, c in ((250, 150, (66, 165, 245)), (450, 210, (255, 167, 38)), (650, 110, (102, 187, 106))):  # 비교 막대
        d.rounded_rectangle([x, 900 - h, x + 130, 900], radius=24, fill=c)
    return im


icon = draw()
icon.save(root / "store_icon_1024.png")
for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    icon.resize((px, px), Image.LANCZOS).save(root / f"android/app/src/main/res/mipmap-{name}/ic_launcher.png")
ios = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for f in ios.glob("*.png"):
    w = Image.open(f).size[0]
    flat = Image.new("RGB", (S, S), (40, 53, 147))
    flat.paste(icon, mask=icon)
    flat.resize((w, w), Image.LANCZOS).save(f)  # 아이폰 아이콘은 투명 금지
print("ok")
