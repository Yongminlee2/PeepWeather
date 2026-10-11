"""앱 아이콘: 앱 첫 화면의 하늘 카드처럼 남색→파랑 바탕, 해와 구름, 그 아래 기관별 범위 띠와 가운데 선.
안드로이드 적응형 아이콘(전경/배경 분리)과 예전 방식 PNG, 아이폰 아이콘, 스토어용 1024 를 함께 만든다.

    python -X utf8 tool/make_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
S = 1024 * 4  # 4배로 그려 줄여서 가장자리를 매끄럽게
TOP, BOTTOM = (0x24, 0x50, 0x8A), (0x4A, 0x80, 0xB4)


def gradient(size: int) -> Image.Image:
    g = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        g.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return g.resize((size, size))


def foreground() -> Image.Image:
    """투명 바탕 위 그림. 적응형 아이콘 안전 영역(가운데 66/108) 안에 들어가게."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = S / 1024

    def circle(cx, cy, r, fill):
        d.ellipse([(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k], fill=fill)

    circle(600, 360, 112, (255, 196, 61, 255))  # 해
    white = (255, 255, 255, 255)
    for cx, cy, r in ((410, 500, 100), (520, 440, 130), (640, 500, 96)):  # 구름
        circle(cx, cy, r, white)
    d.rounded_rectangle([310 * k, 480 * k, 736 * k, 600 * k], radius=60 * k, fill=white)

    # 기관별 범위 띠(옅은 하늘색)와 가운데 선(흰색) — 앱 그래프를 줄인 모양
    xs = [300, 380, 460, 540, 620, 724]
    mid = [700, 676, 690, 660, 668, 640]
    band = list(zip(xs, [m - 34 for m in mid])) + list(zip(reversed(xs), [m + 34 for m in reversed(mid)]))
    d.polygon([(x * k, y * k) for x, y in band], fill=(156, 195, 230, 210))
    d.line([(x * k, y * k) for x, y in zip(xs, mid)], fill=white, width=int(18 * k), joint="curve")
    for x, y in zip(xs, mid):
        circle(x, y, 16, white)
    return im.resize((1024, 1024), Image.LANCZOS)


def full(fg: Image.Image, radius: int | None, zoom: float = 1.0) -> Image.Image:
    """바탕+그림 한 장. radius 가 있으면 둥근 사각형으로 자른다. zoom 은 그림을 키우는 배율."""
    base = gradient(1024).convert("RGBA")
    if zoom != 1.0:
        n = round(1024 * zoom)
        big = fg.resize((n, n), Image.LANCZOS)
        o = (n - 1024) // 2
        fg = big.crop((o, o, o + 1024, o + 1024))
    base.alpha_composite(fg)
    if radius is None:
        return base
    mask = Image.new("L", (1024 * 4, 1024 * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 1024 * 4, 1024 * 4], radius=radius * 4, fill=255)
    out = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask.resize((1024, 1024), Image.LANCZOS))
    return out


fg = foreground()
res = root / "android/app/src/main/res"

# 스토어 1024(투명 없이)
full(fg, None, zoom=1.3).convert("RGB").save(root / "store/icon_1024.png")

# 예전 방식(안드로이드 7 이하): 둥근 사각형 PNG
for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    full(fg, 220, zoom=1.3).resize((px, px), Image.LANCZOS).save(res / f"mipmap-{name}/ic_launcher.png")

# 적응형 아이콘(안드로이드 8+): 전경 PNG(108dp) + 바탕은 그라데이션 drawable
for name, px in (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)):
    fg.resize((px, px), Image.LANCZOS).save(res / f"mipmap-{name}/ic_launcher_foreground.png")
(res / "mipmap-anydpi-v26").mkdir(exist_ok=True)
(res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
""",
    encoding="utf-8",
)
(res / "drawable/ic_launcher_background.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient android:angle="270" android:startColor="#FF24508A" android:endColor="#FF4A80B4" />
</shape>
""",
    encoding="utf-8",
)

# 아이폰: 투명 금지, 꽉 찬 사각형(모서리는 iOS 가 자른다)
flat = full(fg, None, zoom=1.3).convert("RGB")
for f in (root / "ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("*.png"):
    w = Image.open(f).size[0]
    flat.resize((w, w), Image.LANCZOS).save(f)

# 미리보기(확인용, 둥근 사각형과 동그라미 마스크)
prev = Image.new("RGBA", (1100, 540), (238, 243, 248, 255))
prev.alpha_composite(full(fg, 220, zoom=1.3).resize((500, 500), Image.LANCZOS), (20, 20))
circ = full(fg, None).resize((500, 500), Image.LANCZOS)
m = Image.new("L", (500, 500), 0)
ImageDraw.Draw(m).ellipse([0, 0, 500, 500], fill=255)
prev.paste(circ, (580, 20), m)
prev.convert("RGB").save(root / "store/icon_preview.png")
print("ok")
