"""Append reviewed player-language projections while retaining verbatim source versions."""
import argparse
import copy
import json
from pathlib import Path


RULES = {
    "EP02_J3_UI_PAGE_LOCKED": ("C5 탁본 정보가 부족하다. 진단면에서 신체와 인격 채널을 먼저 확인한다.", "거울 탁본 정보가 부족하다. 진단면에서 신체와 인격 채널을 먼저 확인한다.", "The mirror tracing is incomplete. Inspect the body and personality channels on the diagnostic panel first."),
    "EP02_SYS_SAVE_CF": ("자동 저장: C4 실패 원인과 수첩 검증 정보", "자동 저장: 거울 청소 실패 원인과 수첩의 검증 정보", "Autosaved: mirror-cleaning failure and verified notebook information"),
    "EP02_J3_FB_SUCCESS": ("J3가 복원되었다. 방향 불신과 세 기준점, 평면도 필요 상태를 기록한다.", "세 번째 페이지가 복원되었다. 탁본의 방향은 아직 믿을 수 없으며, 세 기준점은 평면도로 확인해야 한다.", "The third page is restored. The tracing's orientation remains unverified; compare the three reference points with the floor plan."),
    "EP02_C3_UI_ACQUIRE_LABEL": ("NEUTRAL_CLEANER | 당일 물질 | NORMAL_RESET 시 소실", "중성 세정액 · 오늘 준비한 물질 · 잠들면 초기화", "Neutral cleaner · Prepared today · Reset after sleep"),
    "EP02_C4_FB_FAIL_ANCHOR": ("시작점 바깥이 먼저 굳었다. 수첩에 anchor_missing을 기록했다.", "시작점 바깥이 먼저 굳었다. 맞지 않았던 기준점을 수첩에 기록했다.", "The coating hardened outside the starting point. I recorded the misaligned reference point."),
    "EP02_C4_FB_FAIL_ENTRY": ("진입 압력이 생기지 않았다. entry_missing을 기록했다.", "진입 압력이 생기지 않았다. 신호가 들어가지 못한 지점을 기록했다.", "No entry pressure formed. I recorded where the signal could not enter."),
    "EP02_C4_FB_FAIL_BRANCH": ("갈라진 막이 다시 붙었다. branch_incomplete를 기록했다.", "갈라진 막이 다시 붙었다. 반응하지 않은 분기를 기록했다.", "The split film sealed itself again. I recorded the branch that did not respond."),
    "EP02_C4_FB_FAIL_ORDER": ("반사압이 되돌아와 코팅을 닫았다. branch_order_wrong을 기록했다.", "반사압이 되돌아와 코팅을 닫았다. 어긋난 분기 순서를 기록했다.", "The reflected pressure returned and closed the coating. I recorded the incorrect branch order."),
    "EP02_C4_FB_FAIL_RING": ("마지막 고리가 반대 방향으로 잠겼다. ring_direction_wrong을 기록했다.", "마지막 고리가 반대 방향으로 잠겼다. 고리가 닫히지 않은 방향을 기록했다.", "The final ring locked in the opposite direction. I recorded the direction that did not close it."),
    "EP02_C4_FB_FAIL_TOOL": ("에드가가 도구를 회수했다. tool_confiscated를 기록했다.", "에드가가 도구를 회수했다. 그때의 상황을 수첩에 기록했다.", "Edgar took the tools away. I recorded what happened in the notebook."),
    "EP02_C4_UI_FAIL_LOCK": ("검은 거울 실제 닦기 | 오늘은 잠김 | NORMAL_RESET 필요", "오늘은 거울을 더 닦을 수 없다. 잠든 뒤 다시 시도할 수 있다.", "The mirror cannot be cleaned again today. Try again after sleeping."),
    "EP02_C5_CH_TRACE_DONE": ("C5_MIRROR_TRACING 획득 | 영구 수첩 | 방향 미검증", "거울 회로 탁본을 수첩에 보관했다. 방향은 아직 확인하지 않았다.", "The mirror circuit tracing is stored in the notebook. Its orientation is still unverified."),
    "EP02_J3_UI_COMMIT_DONE": ("journal_stage=3 | 방향 불신·세 기준점·평면도 필요 | 영구", "일지 3단계 복원 완료 · 탁본의 방향과 세 기준점은 평면도로 확인해야 한다.", "Third journal restoration complete. Compare the tracing and three reference points with the floor plan."),
    "EP02_SYS_EXIT_EP02": ("EP02 완료. 다음 목표: 서재의 지하창고 단서 재확인.", "거울의 기록을 정리했다. 다음 목표: 서재의 지하창고 단서 재확인.", "The mirror records are organized. Next: revisit the basement clue in the library."),
    "EP02_SYS_UI_J3_LIMIT": ("J3는 정확한 회전값을 확정하지 않습니다. 평면도 비교는 다음 구간에서 진행합니다.", "이 페이지에서는 정확한 회전값을 확정할 수 없다. 다음에는 평면도와 비교해야 한다.", "This page does not establish the exact rotation. Compare it with the floor plan next."),
    "EP02_OBJ_CHEM_LATE": ("C5 진단 뒤에는 라벨 아래에 LIFE SUPPORT 배관 번호가 희미하게 겹친다.", "진단면을 확인한 뒤에는 라벨 아래에 LIFE SUPPORT 배관 번호가 희미하게 겹친다.", "After inspecting the diagnostic panel, LIFE SUPPORT pipe numbers faintly overlap beneath the labels."),
}


def build(runtime: dict, canonical: dict, previous: dict) -> dict:
    nodes = {row["node_id"]: row for row in runtime["nodes"]}
    result = copy.deepcopy(previous)
    result.setdefault("format_version", 1)
    result.setdefault("contents", {})
    for identity, (expected, korean, english) in RULES.items():
        if nodes[identity]["ko_KR"] != expected or nodes[identity]["en_US"]:
            raise ValueError(f"Source changed; review player-language rule: {identity}")
        content_id = "NB_" + identity
        raw_version = str(runtime["notebook_versions"][content_id])
        raw = canonical["contents"][content_id][raw_version]
        if raw["locales"]["ko-KR"]["body"] != expected or raw["locales"]["en-US"]["body"] != expected:
            raise ValueError(f"Raw catalog does not match source: {identity}")
        updated = copy.deepcopy(raw)
        updated["locales"]["ko-KR"]["body"] = korean
        updated["locales"]["en-US"]["body"] = english
        updated["source_display_policy"] = "reviewed_player_language"
        updated["source_raw_content_version"] = int(raw_version)
        versions = copy.deepcopy(canonical["contents"][content_id])
        for version, row in previous.get("contents", {}).get(content_id, {}).items():
            if version in versions and versions[version] != row:
                raise ValueError(f"Conflicting historical version: {content_id}:{version}")
            versions[version] = row
        if versions[max(versions, key=int)] != updated:
            result["contents"].setdefault(content_id, {})[str(max(map(int, versions)) + 1)] = updated
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--canonical", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    read = lambda path: json.loads(path.read_text(encoding="utf-8-sig"))
    previous = read(args.output) if args.output.exists() else {"format_version": 1, "contents": {}}
    result = build(read(args.runtime), read(args.canonical), previous)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"projected_nodes": len(result["contents"])}))
