"""Add versioned sheet-authored dry-test text without mutating saved v1 modals."""
import argparse
import copy
import json
from pathlib import Path


IDENTITY = "NB_MODAL_MIRROR_ROUTE_OPTIONS"
SEGMENTS = {
    "dry_start": "EP02_C4_UI_DRY_START",
    "result_anchor_missing": "EP02_C4_FB_ANCHOR_WRONG",
    "result_entry_missing": "EP02_C4_FB_ENTRY_MISSING",
    "result_branch_incomplete": "EP02_C4_FB_BRANCH_ONE",
    "result_branch_order_wrong": "EP02_C4_FB_BRANCH_ORDER",
    "result_ring_direction_wrong": "EP02_C4_FB_RING_CCW",
    "result_success": "EP02_C4_FB_DRY_VALID",
    "result_overlay_no_rot": "EP02_C4_FB_OVERLAY_NO_ROT",
    "result_overlay_ccw": "EP02_C4_FB_OVERLAY_CCW",
    "result_overlay_flipped": "EP02_C4_FB_OVERLAY_FLIPPED",
    "dry_intro": "EP02_C4_DRY_001",
    "dry_entry": "EP02_C4_DRY_002",
    "dry_branches": "EP02_C4_DRY_003",
    "dry_ring": "EP02_C4_DRY_004",
    "dry_success": "EP02_C4_DRY_SUCCESS_001",
    "dry_object_good": "EP02_OBJ_MIRROR_C4_DRY_OK",
    "dry_object_bad": "EP02_OBJ_MIRROR_C4_DRY_BAD",
    "caption_entry": "EP02_CAP_DRY_ENTRY",
    "caption_branches": "EP02_CAP_DRY_BRANCH",
    "caption_ring": "EP02_CAP_DRY_RING",
    "motion_assist": "EP02_SYS_A11Y_MOTION",
}


def build(runtime: dict, base: dict, previous: dict) -> dict:
    nodes = {row["node_id"]: row for row in runtime["nodes"]}
    versions = copy.deepcopy(base["contents"][IDENTITY])
    for version, row in previous.get("contents", {}).get(IDENTITY, {}).items():
        if version in versions and versions[version] != row:
            raise ValueError(f"Conflicting historical modal: {version}")
        versions[version] = row
    updated = copy.deepcopy(versions[max(versions, key=int)])
    updated["source_sheet_segments"] = SEGMENTS.copy()
    updated["text_source"] = "res://data/dialogue/sheets/ep02_runtime.json"
    for segment, identity in SEGMENTS.items():
        if segment not in updated["visible_segment_ids"]:
            updated["visible_segment_ids"].insert(1, segment)
        updated["variables"][segment] = {}
        updated["localization_keys"][segment] = IDENTITY + "_" + segment
        for locale, column in (("ko-KR", "ko_KR"), ("en-US", "en_US")):
            updated["locales"][locale][segment] = nodes[identity][column] or nodes[identity]["ko_KR"]
    narrative = ["dry_start", "dry_intro", "dry_entry", "caption_entry", "dry_branches", "caption_branches", "dry_ring", "caption_ring", "dry_success"]
    updated["visible_segment_ids"] = ["header"] + narrative + [segment for segment in updated["visible_segment_ids"] if segment != "header" and segment not in narrative]
    if "dry_start" not in updated["default_segments"]:
        updated["default_segments"].insert(1, "dry_start")
    result = copy.deepcopy(previous)
    result.setdefault("format_version", 1)
    result.setdefault("contents", {})
    if versions[max(versions, key=int)] != updated:
        version = str(max(map(int, versions)) + 1)
        result["contents"].setdefault(IDENTITY, {})[version] = updated
    discard_id = "NB_MODAL_EP02_DISCARD_OPTIONS"
    discard = copy.deepcopy(base["contents"][IDENTITY]["1"])
    discard.update(event_id="C3", source_symbol="_show_recorded_choice:EP02_DISCARD", cancel_index=0,
                   text_source="res://data/dialogue/sheets/ep02_runtime.json",
                   source_sheet_segments={"prompt": "EP02_C3_UI_DISCARD_CONFIRM"})
    segments = ["header", "prompt", "option_0", "option_1"]
    discard["visible_segment_ids"] = segments
    discard["default_segments"] = segments.copy()
    discard["variables"] = {segment: {} for segment in segments}
    discard["localization_keys"] = {segment: discard_id + "_" + segment for segment in segments}
    for locale, column, title, cancel, confirm in (("ko-KR", "ko_KR", "혼합물 폐기", "취소", "폐기한다"), ("en-US", "en_US", "Discard mixture", "Cancel", "Discard")):
        original = discard["locales"][locale]
        discard["locales"][locale] = {key: original[key] for key in ("title", "summary", "speaker")}
        discard["locales"][locale].update(header=title, prompt=nodes["EP02_C3_UI_DISCARD_CONFIRM"][column] or nodes["EP02_C3_UI_DISCARD_CONFIRM"]["ko_KR"], option_0=cancel, option_1=confirm)
    old_discard = previous.get("contents", {}).get(discard_id, {})
    if not old_discard or old_discard[max(old_discard, key=int)] != discard:
        result["contents"].setdefault(discard_id, {})[str(max(map(int, old_discard), default=0) + 1)] = discard
    trace_id = "NB_MODAL_EP02_TRACE_OPTIONS"
    trace = copy.deepcopy(discard)
    trace.update(event_id="C5_INFO", source_symbol="_show_recorded_choice:EP02_TRACE",
                 source_sheet_segments={"prompt": "EP02_C5_CH_TRACE_PROMPT"})
    trace["localization_keys"] = {segment: trace_id + "_" + segment for segment in segments}
    for locale, column, title, confirm in (("ko-KR", "ko_KR", "회로 탁본 기록", "기록한다"), ("en-US", "en_US", "Record circuit tracing", "Record")):
        trace["locales"][locale].update(header=title, prompt=nodes["EP02_C5_CH_TRACE_PROMPT"][column] or nodes["EP02_C5_CH_TRACE_PROMPT"]["ko_KR"], option_1=confirm)
    old_trace = previous.get("contents", {}).get(trace_id, {})
    if not old_trace or old_trace[max(old_trace, key=int)] != trace:
        result["contents"].setdefault(trace_id, {})[str(max(map(int, old_trace), default=0) + 1)] = trace
    journal_id = "NB_MODAL_EP02_J3_RESTORE_OPTIONS"
    journal = copy.deepcopy(trace)
    journal.update(event_id="J3", source_symbol="_show_recorded_choice:EP02_J3_RESTORE",
                   source_sheet_segments={"prompt": "EP02_J3_UI_COMMIT_PROMPT"})
    journal["localization_keys"] = {segment: journal_id + "_" + segment for segment in segments}
    for locale, column, title in (("ko-KR", "ko_KR", "세 번째 페이지 기록"), ("en-US", "en_US", "Record the third page")):
        journal["locales"][locale].update(header=title, prompt=nodes["EP02_J3_UI_COMMIT_PROMPT"][column] or nodes["EP02_J3_UI_COMMIT_PROMPT"]["ko_KR"])
    old_journal = previous.get("contents", {}).get(journal_id, {})
    if not old_journal or old_journal[max(old_journal, key=int)] != journal:
        result["contents"].setdefault(journal_id, {})[str(max(map(int, old_journal), default=0) + 1)] = journal
    for suffix, follow_ko, follow_en in (("EP02_J3_MEMORY", "눌림을 따라가 본다", "Follow the impression"), ("EP02_J3_MEMORY_REPLAY", "다시 듣는다", "Listen again")):
        memory_id = "NB_MODAL_" + suffix + "_OPTIONS"
        memory = copy.deepcopy(journal)
        memory.update(source_symbol="_show_recorded_choice:" + suffix,
                      source_sheet_segments={"prompt": "EP02_J3_FB_MEMORY"})
        memory["localization_keys"] = {segment: memory_id + "_" + segment for segment in segments}
        for locale, column, title, skip, follow in (("ko-KR", "ko_KR", "페이지 아래의 눌림", "건너뛴다", follow_ko), ("en-US", "en_US", "Impression beneath the page", "Skip", follow_en)):
            memory["locales"][locale].update(header=title, prompt=nodes["EP02_J3_FB_MEMORY"][column] or nodes["EP02_J3_FB_MEMORY"]["ko_KR"], option_0=skip, option_1=follow)
        old_memory = previous.get("contents", {}).get(memory_id, {})
        if not old_memory or old_memory[max(old_memory, key=int)] != memory:
            result["contents"].setdefault(memory_id, {})[str(max(map(int, old_memory), default=0) + 1)] = memory
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fresh-output", action="store_true")
    args = parser.parse_args()
    read = lambda path: json.loads(path.read_text(encoding="utf-8-sig"))
    previous = read(args.output) if args.output.exists() and not args.fresh_output else {"format_version": 1, "contents": {}}
    result = build(read(args.runtime), read(args.base), previous)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"modal_versions": list(result["contents"][IDENTITY])}))
