"""아이폰 시뮬레이터에서 화면을 한 장씩 찍는다(화면 확인·앱스토어 스크린샷).

이 맥의 시뮬레이터는 탭이 앱에 닿지 않아서, 화면마다 SHOT 을 넣어 다시 빌드한다
(lib/ui/debug_shot.dart). 위치는 서울로, 위치 권한은 미리 허용해 둔다.
이 앱 전용 시뮬레이터 UDID 를 준다 — 다른 작업이 쓰는 기기를 건드리지 않게.

    python3 tool/ios_shots.py <저장 폴더> <UDID> [--langs ko,en] [--dark] home settings search satellite@20
    → <저장 폴더>/<언어>[-dark]-<번호>_<화면>.png

keys.json 이 있으면 --dart-define-from-file 로 넣는다(없으면 키가 필요한 기관은 「설정 필요」).
"""
import argparse
import os
import subprocess
import time
from pathlib import Path

APP_ID = 'com.peep.weather'
root = Path(__file__).resolve().parent.parent
ap = argparse.ArgumentParser()
ap.add_argument('out')
ap.add_argument('udid')
ap.add_argument('--langs', default='ko,en')
ap.add_argument('--dark', action='store_true')
ap.add_argument('--lat', default='37.5665,126.9780')
ap.add_argument('shots', nargs='+')
a = ap.parse_args()
out = Path(a.out)
out.mkdir(parents=True, exist_ok=True)
flutter = os.path.expanduser('~/flutter/bin/flutter')


def sim(*args, check=True):
    return subprocess.run(['xcrun', 'simctl', *args], check=check, capture_output=True, text=True)


for n, spec in enumerate(a.shots, 1):
    shot, _, extra = spec.partition('@')
    wait = 30 + int(extra or 0)  # 디버그 빌드 첫 화면 + 기관 응답
    cmd = [flutter, 'build', 'ios', '--simulator', '--debug', f'--dart-define=SHOT={shot}']
    if (root / 'keys.json').exists():
        cmd.append('--dart-define-from-file=keys.json')
    subprocess.run(cmd, cwd=root, check=True, capture_output=True)
    for lang in a.langs.split(','):
        # 다른 작업이 시뮬레이터를 꺼 버릴 때가 있다 → 매번 켜져 있는지 본다
        sim('boot', a.udid, check=False)
        sim('bootstatus', a.udid, '-b')
        sim('ui', a.udid, 'appearance', 'dark' if a.dark else 'light')
        sim('location', a.udid, 'set', a.lat)
        sim('terminate', a.udid, APP_ID, check=False)
        sim('install', a.udid, str(root / 'build/ios/iphonesimulator/Runner.app'))
        sim('privacy', a.udid, 'grant', 'location', APP_ID)
        sim('launch', a.udid, APP_ID, '-AppleLanguages', f'({lang})', '-AppleLocale', lang)
        time.sleep(wait)
        f = out / f"{lang}{'-dark' if a.dark else ''}-{n:02d}_{shot}.png"
        sim('io', a.udid, 'screenshot', '--type=png', str(f))
        print(f)
