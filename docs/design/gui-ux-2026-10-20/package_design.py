"""Build the local review gallery and check its static links; no game files changed."""
from pathlib import Path
import hashlib
import html
import json
import re
import struct
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent
BOARDS = [
    ("08", "대화 · 주인공과 고정 HUD", "08-gameplay-layout-v4.png",
     "좌상단 메뉴·현 위치, 오른쪽 인벤토리, 좌하단 수첩. 대화 중 인벤토리는 같은 자리에서 어둡게 표시합니다."),
    ("01", "수첩 · 발견한 자료를 읽고 비교하기", "01-notebook-v3.png",
     "밝은 펼친 책, 보라색 리본, 왼쪽 종이 책갈피 네 탭과 목록→원본→관찰→비교 흐름. 그림 속 도형은 배치 예시입니다."),
    ("11", "지도 · 손그림 평면도", "11-map.png",
     "현재 위치는 검은 점. 오른쪽 목록과 하단 리스트 없이 벽·문·복도로 공간을 표현합니다. 방 연결은 배치 예시입니다."),
    ("10", "대화 · 말하기, 관찰, 선택, 기록", "10-dialogue-states-v3.png",
     "마라 2·에드가·이리스 스탠딩을 참고한 화면입니다. 선택 대기에서는 자동 진행이 멈춥니다. 상단 말하기/관찰/대화 선택 표지는 보드 설명용입니다."),
    ("09", "탐색 · 물건을 직접 사용하기", "09-direct-interaction-v2.png",
     "Rusty Lake 조작 참조: 대상 클릭→가까이 보기→아이템 선택 후 대상 클릭→결과 확인. 열쇠와 서랍은 조작 예시입니다."),
    ("02", "자료 비교 · 두 칸과 A/B 전환", "02-compare-v2.png",
     "비교는 읽기 전용. 화면이 좁거나 글자가 클 때 한 칸으로 전환합니다. 실제 200% 실행 캡처는 아닙니다."),
    ("04", "퍼즐 · 작업, 복원, 도움, 재시도", "04-puzzles-v3.png",
     "실제 근거를 크게 보여 주고 실행과 열람을 구분합니다. 그림·조각은 정답이 아닌 배치 샘플입니다."),
    ("05", "메뉴 · 시작, 저장, 일시정지, 복구", "05-menus-v3.png",
     "왼쪽 로고·세로 메뉴와 오른쪽 주인공. 세 슬롯과 빈 슬롯, 손상 저장의 복구를 구별합니다."),
    ("06", "설정 · 읽기와 입력 미리보기", "06-settings-v5.png",
     "언어·글자·움직임·감각 자막, 키 충돌과 화면 설정 되돌리기. 인물 표시는 발견 후 상태 예시입니다."),
    ("07", "후반 · 출처 대조와 동등한 선택", "07-late-game-v2.png",
     "후반 내용 포함. 두 절차의 확실/불확실 정보를 같은 위계로 보여 주고 가운데 수첩에서 검토합니다."),
]


def build_gallery():
    links = "".join(f'<a href="#board-{i}">{i} {html.escape(title.split(" · ")[0])}</a>'
                    for i, title, _, _ in BOARDS)
    sections = []
    for i, title, name, caption in BOARDS:
        src = "images/" + name
        panel = (f'<section id="board-{i}"><div class="heading"><span>{i}</span><h2>{title}</h2>'
                 f'<a href="{src}" target="_blank">원본 크기 ↗</a></div>'
                 f'<p>{caption}</p><a href="{src}" target="_blank">'
                 f'<img src="{src}" alt="{title}" loading="lazy"></a></section>')
        if i == "07":
            panel = '<details><summary>후반·엔딩 설계 펼치기</summary>' + panel + '</details>'
        sections.append(panel)
    cast = "".join(f'<figure><a href="references/character-{slug}.png" target="_blank">'
                   f'<img src="references/character-{slug}.png" alt="{name}" loading="lazy"></a>'
                   f'<figcaption>{name} · 사용자 제공 원본</figcaption></figure>'
                   for slug, name in [("mara2", "마라 2"), ("iris", "이리스"),
                                      ("edgar", "에드가"), ("protagonist", "주인공")])
    page = """<!doctype html><html lang="ko"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>GGB · GUI/UX 시안</title>
<style>
:root{color-scheme:dark;font-family:"Malgun Gothic",sans-serif;background:#14121b;color:#eee5da}
*{box-sizing:border-box}body{margin:0}a{color:#d9c2ed;text-underline-offset:4px}a:focus-visible,summary:focus-visible{outline:3px double white;outline-offset:4px}
header,main{max-width:1400px;margin:auto;padding:32px}header{padding-top:50px}
.eyebrow{color:#b9a8c7;font-size:13px;letter-spacing:.2em}h1{font-size:clamp(30px,5vw,64px);margin:12px 0}h2{font-size:24px;margin:0}
p{line-height:1.8;color:#c8bfce}.actions{display:flex;gap:18px;flex-wrap:wrap;margin:24px 0}.actions a{padding:13px 18px;border:1px solid #796380;border-radius:3px;text-decoration:none}
.actions a:first-child{background:#e6dcd0;color:#292332}nav{display:flex;flex-wrap:wrap;gap:10px 20px;padding:18px 0;border-top:1px solid #42384a}
section{margin-bottom:48px;scroll-margin-top:20px}.heading{display:flex;align-items:center;gap:16px;flex-wrap:wrap}.heading>span{color:#b398c6;font-family:Georgia;font-size:30px}.heading a{margin-left:auto;font-size:14px}
section>p{margin:12px 0 18px}section>a>img{width:100%;height:auto;display:block;border:1px solid #514455;border-radius:3px}
.cast{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}.cast figure{margin:0;background:#211c29;padding:16px}.cast img{width:100%;height:350px;object-fit:contain}.cast figcaption{font-size:13px;color:#c7bfce;text-align:center}
details{border:1px solid #514455;padding:20px;margin-bottom:40px}summary{cursor:pointer;font-size:20px}details section{margin:24px 0 0}
footer{color:#a499b0;font-size:13px;border-top:1px solid #42384a;padding:24px 0;line-height:1.8}
@media(max-width:650px){header,main{padding:20px}.cast{grid-template-columns:repeat(2,1fr)}.cast img{height:240px}h2{font-size:20px}}
</style>
<header><p class="eyebrow">GGB / ART DIRECTION / 2026.10.20</p><h1>읽고, 발견하고, 다시 연결하기.</h1>
<p>실제 캐릭터 스탠딩과 책 오브젝트의 선·명암을 기준으로 맞춘 GUI·UX 시안입니다.<br>이미지로 방향을 결정하는 검토본이며, 게임 적용 전입니다.</p>
<div class="actions"><a href="title-preview.html">커서에 반응하는 시작 화면 열기 →</a><a href="README.md">설계 설명</a><a href="screen-spec.md">46개 화면·상태 설계</a><a href="art-direction.md">그림체·배치 기준</a></div>
<nav>""" + links + "</nav></header><main>" + "".join(sections) + """
<section><div class="heading"><h2>그림체 기준 · 실제 스탠딩</h2></div><p>입력 순서와 인물명을 그대로 유지했습니다. 아래는 생성본이 아닌 제공된 원본입니다.</p><div class="cast">""" + cast + """</div></section>
<footer>생성: 내장 image_gen · 원본 참고: 사용자 제공 이미지 및 현재 프로젝트. 생성 화면의 문장·도형은 최종 런타임 데이터가 아닙니다.<br>
<a href="review.md">검토 범위</a> · <a href="validation.json">파일 검사</a> · <a href="final-direction-prompts.json">핵심 생성 프롬프트</a> · <a href="style-pass-prompts.json">그림체 통일 프롬프트</a>
</footer></main><script>
function revealHash(){if(location.hash==='#board-07'){const panel=document.getElementById('board-07');panel.closest('details').open=true;panel.scrollIntoView()}}
addEventListener('hashchange',revealHash);revealHash();
</script></html>"""
    (ROOT / "gallery.html").write_text(page, encoding="utf-8")


def luminance(color):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    return sum(v * weight for v, weight in zip(linear, (.2126, .7152, .0722)))


def validate():
    missing, links = [], []
    # Relative links in authored markdown/html plus literal image paths inside JS/CSS.
    for path in sorted(ROOT.glob("*")):
        if path.suffix not in {".md", ".html"}:
            continue
        text = path.read_text(encoding="utf-8")
        refs = re.findall(r'\]\(([^)]+)\)', text) if path.suffix == ".md" else re.findall(
            r'(?:href|src)=["\']([^"\']+)["\']', text)
        refs += re.findall(r"""["']((?:images|references)/[^"']+\.(?:png|jpg))["']""", text)
        for ref in sorted(set(refs)):
            if ref.startswith(("http:", "https:", "#", "mailto:")):
                continue
            resolved = path.parent / ref.split("#")[0]
            exists = resolved.exists()
            links.append({"source": path.name, "target": ref, "exists": exists})
            if not exists:
                missing.append(f"{path.name}: {ref}")
    images = []
    for path in sorted((ROOT / "images").glob("*.png")):
        data = path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", path
        width, height = struct.unpack(">II", data[16:24])
        images.append({"file": "images/" + path.name, "width": width, "height": height,
                       "sha256": hashlib.sha256(data).hexdigest()})
    prompts = []
    for path in sorted(ROOT.glob("*.json")):
        if path.name == "validation.json":
            continue
        json.loads(path.read_text(encoding="utf-8-sig"))
        prompts.append(path.name)
    colors = [("#25252B", "#F1EADD"), ("#56525A", "#F1EADD"), ("#F5F0E5", "#19191F")]
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "scope": "static artifacts only; not Godot execution or raster-background contrast",
        "selected_boards": ["images/" + b[2] for b in BOARDS],
        "missing_links": missing, "links": links, "png_files": images,
        "json_parse_pass": prompts,
        "candidate_solid_color_contrast": [
            {"foreground": a, "background": b,
             "ratio": round((max(luminance(a), luminance(b)) + .05) /
                            (min(luminance(a), luminance(b)) + .05), 2)}
            for a, b in colors],
    }
    (ROOT / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"selected": len(BOARDS), "png_files": len(images),
                      "local_links": len(links), "missing": missing}, ensure_ascii=False))
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    build_gallery()
    # validation.json is itself linked from the gallery.
    if not (ROOT / "validation.json").exists():
        (ROOT / "validation.json").write_text("{}", encoding="utf-8")
    validate()
