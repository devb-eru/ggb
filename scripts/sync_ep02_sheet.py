"""Create EP02 runtime and authored notebook definitions from unchanged Sheets."""
import argparse
import copy
import json
from pathlib import Path

from compile_script_sheet import compile_snapshot
from sync_ep01_sheet import NAMES, EN_NAMES


def build(source: dict) -> tuple[dict, dict]:
    runtime = compile_snapshot(source, allow_continuations=True)
    nodes = {row["node_id"]: row for row in runtime["nodes"]}
    contents = {}
    for identity, node in nodes.items():
        content_id = "NB_" + identity
        row = {
            "producer_id": "EP02_SHEET", "source_file": "data/dialogue/sheets/ep02_runtime.json",
            "source_symbol": identity, "event_id": node["scene_id"], "node_ids": [identity],
            "action_or_variant": "sheet_line", "speaker_id": node["speaker_id"],
            "location_source": "history_context:actual_room",
            "entry_kind": "document_segment" if node["content_type"] == "DOCUMENT" else "dialogue",
            "disclosure_owner": "actual_display_or_choice_press", "mapping_status": "AUTHORED_ID",
            "owner": "development/content", "visible_segment_ids": ["body"], "protection_reasons": [],
            "variables": {"body": {}}, "localization_keys": {"body": content_id + ":body"}, "locales": {},
        }
        for locale, names in (("ko-KR", NAMES), ("en-US", EN_NAMES)):
            text = node["ko_KR"] if locale == "ko-KR" else node["en_US"] or node["ko_KR"]
            row["locales"][locale] = {"title": "거울의 기록" if locale == "ko-KR" else "Mirror record",
                                       "summary": "확인한 말과 기록" if locale == "ko-KR" else "Observed words and records",
                                       "speaker": names[node["speaker_id"]], "body": text}
        contents[content_id] = {"1": row}
    routes = {}
    declared_choices = {row["next_id"] for row in runtime["nodes"] if row["next_type"] == "choice"}
    runtime["choice_routes"] = sorted(declared_choices)
    runtime["conditional_choice_routes"] = []
    for edge in runtime["edges"]:
        routes.setdefault(edge["route_id"], []).append(edge)
    for route, edges in routes.items():
        choices = sorted((e for e in edges if e["target_type"] == "node"), key=lambda e: int(e["edge_order"]))
        if not choices or not all(nodes[e["target_id"]]["content_type"] == "CHOICE" for e in choices):
            continue
        if route not in declared_choices:
            runtime["conditional_choice_routes"].append(route)
        content_id = "NB_" + route
        row = copy.deepcopy(contents["NB_" + choices[0]["target_id"]]["1"])
        segments = [f"option_{index}" for index in range(len(choices))]
        row.update({"source_symbol": route, "event_id": route, "node_ids": [route], "speaker_id": "SYSTEM",
                    "entry_kind": "options_presented", "action_or_variant": "options", "visible_segment_ids": segments,
                    "default_segments": segments.copy(), "cancel_index": -1,
                    "variables": {key: {} for key in segments},
                    "localization_keys": {key: content_id + ":" + key for key in segments}, "choices": []})
        for locale in row["locales"]:
            row["locales"][locale].pop("body", None)
            row["locales"][locale]["speaker"] = "표시된 선택지" if locale == "ko-KR" else "Displayed choices"
        for index, edge in enumerate(choices):
            selected_id = content_id + "_SELECT_" + str(index)
            selected = copy.deepcopy(contents["NB_" + edge["target_id"]]["1"])
            selected.update({"source_symbol": route, "event_id": route, "node_ids": [route],
                             "speaker_id": "SYSTEM", "entry_kind": "choice_confirmed"})
            for locale in row["locales"]:
                row["locales"][locale][segments[index]] = selected["locales"][locale]["body"]
                selected["locales"][locale]["speaker"] = "선택한 문구" if locale == "ko-KR" else "Selected option"
            contents[selected_id] = {"1": selected}
            row["choices"].append({"content_id": selected_id, "kind": "confirm"})
        contents[content_id] = {"1": row}
    runtime["notebook_versions"] = {identity: 1 for identity in contents}
    return runtime, {"format_version": 1, "contents": contents}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    runtime, notebook = build(json.loads(args.source.read_text(encoding="utf-8-sig")))
    for relative, data in (("game/data/dialogue/sheets/ep02_runtime.json", runtime), ("game/data/notebook/ep02_sheet_v1.json", notebook)):
        path = args.output / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"nodes": len(runtime["nodes"]), "notebook_definitions": len(notebook["contents"])}))
