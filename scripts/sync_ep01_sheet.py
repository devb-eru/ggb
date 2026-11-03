"""Compile an authenticated Google Sheets CellData snapshot into EP01 runtime data.

The source is a connector read, never a generated View. Korean cells are copied
verbatim; empty English cells explicitly fall back to Korean until translated.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from compile_script_sheet import entered

ROOT = Path(__file__).resolve().parents[1]
TABLES = {"09_Runtime_Master": "nodes", "10_Route_Edge_Master": "edges",
          "11_State_Predicate": "predicates", "12_State_Effect": "effects"}
NAMES = {"SUBJECT": "주인공", "SYSTEM": "SYSTEM", "DOCUMENT": "기록",
         "SERVANT_EDGAR": "에드가", "SERVANT_MARA1": "마라 1", "SERVANT_MARA2": "마라 2",
         "SERVANT_LUCA": "루카", "SERVANT_IRIS": "이리스"}
EN_NAMES = {"SUBJECT": "Protagonist", "SYSTEM": "SYSTEM", "DOCUMENT": "Record",
            "SERVANT_EDGAR": "Edgar", "SERVANT_MARA1": "Mara 1", "SERVANT_MARA2": "Mara 2",
            "SERVANT_LUCA": "Luca", "SERVANT_IRIS": "Iris"}


def cell_value(cell: dict):
    return entered(cell)


def compile_snapshot(source: dict) -> tuple[dict, dict]:
    result = {"schema_version": 1, "package_id": "CNT-EP01", "source_url": source["spreadsheetUrl"],
              "source_sha256": hashlib.sha256(json.dumps(source, ensure_ascii=False, sort_keys=True).encode()).hexdigest()}
    for sheet in source["sheets"]:
        name = sheet["properties"]["title"]
        if name not in TABLES:
            continue
        data = sheet["data"][0]
        rows = data["rowData"]
        headers = [cell_value(c) for c in rows[0]["values"]]
        records = []
        for index, row in enumerate(rows[1:]):
            values = [cell_value(c) for c in row.get("values", [])]
            if not any(v != "" for v in values):
                continue
            record = dict(zip(headers, values + [""] * (len(headers) - len(values))))
            record["sheet_row"] = data.get("startRow", 2) + index + 2
            records.append(record)
        result[TABLES[name]] = records
    for table, key in (("nodes", "node_id"), ("edges", "edge_id"), ("predicates", "predicate_id"), ("effects", "effect_id")):
        ids = [r[key] for r in result[table]]
        if any(not x for x in ids) or len(ids) != len(set(ids)):
            raise ValueError(f"Invalid {table} identities")
    nodes = {r["node_id"]: r for r in result["nodes"]}
    contents = {}
    for node in result["nodes"]:
        node_id = node["node_id"]
        variables = {k: "int" for k in re.findall(r"\{([A-Za-z][A-Za-z0-9_]*)\}", node["ko_KR"])}
        locales = {}
        for locale, text in (("ko-KR", node["ko_KR"]), ("en-US", node["en_US"] or node["ko_KR"])):
            names = NAMES if locale == "ko-KR" else EN_NAMES
            locales[locale] = {"title": "저택의 기록" if locale == "ko-KR" else "Mansion record", "summary": "확인한 말과 기록" if locale == "ko-KR" else "Observed words and records", "speaker": names[node["speaker_id"]], "body": text}
        contents["NB_" + node_id] = {"1": {
            "producer_id": "EP01_SHEET", "source_file": "data/dialogue/chapter_one/ep01_runtime.json",
            "source_symbol": node_id, "event_id": node["scene_id"], "node_ids": [node_id],
            "action_or_variant": "sheet_line", "speaker_id": node["speaker_id"],
            "location_source": "history_context:actual_room", "entry_kind": "document_segment" if node["content_type"] == "DOCUMENT" else "dialogue",
            "disclosure_owner": "actual_display_or_choice_press", "mapping_status": "AUTHORED_ID",
            "owner": "development/content", "visible_segment_ids": ["body"],
            "protection_reasons": [], "variables": {"body": variables},
            "localization_keys": {"body": "NB_" + node_id + ":body"}, "locales": locales,
        }}
    # Modal choice definitions are authored as a single disclosed options record.
    routes = {}
    for edge in result["edges"]:
        if (edge["route_id"].startswith("EP01_CHOICE_") or edge["route_id"] == "EP01_HUB_DAILY_HALL") and edge["target_type"] == "node":
            routes.setdefault(edge["route_id"], []).append(edge)
    for route, edges in routes.items():
        edges.sort(key=lambda r: int(r["edge_order"]))
        labels = [nodes[e["target_id"]]["ko_KR"] for e in edges]
        row = json.loads(json.dumps(contents["NB_" + edges[0]["target_id"]]["1"]))
        row.update({"source_symbol": route, "event_id": route, "node_ids": [route],
                    "action_or_variant": "options", "speaker_id": "SYSTEM", "entry_kind": "options_presented",
                    "visible_segment_ids": [f"option_{i}" for i in range(len(labels))]})
        row["variables"] = {k: {} for k in row["visible_segment_ids"]}
        row["localization_keys"] = {k: "NB_" + route + ":" + k for k in row["visible_segment_ids"]}
        row["choices"] = [{"content_id": "NB_" + route + f"_SELECT_{i}", "kind": "confirm"} for i in range(len(edges))]
        row["default_segments"] = row["visible_segment_ids"].copy()
        row["cancel_index"] = -1
        for locale in row["locales"]:
            ko = locale == "ko-KR"
            row["locales"][locale] = {"title": "대답" if ko else "Reply", "summary": "제시된 선택지" if ko else "Displayed choices", "speaker": "표시된 선택지" if ko else "Displayed choices",
                                      **{f"option_{i}": label for i, label in enumerate(labels)}}
        contents["NB_" + route] = {"1": row}
        for i, edge in enumerate(edges):
            selected = json.loads(json.dumps(contents["NB_" + edge["target_id"]]["1"]))
            selected.update({"node_ids": [route], "event_id": route, "entry_kind": "choice_confirmed", "speaker_id": "SYSTEM"})
            for locale in selected["locales"]:
                selected["locales"][locale]["speaker"] = "선택한 문구" if locale == "ko-KR" else "Selected option"
            contents[row["choices"][i]["content_id"]] = {"1": selected}
    for mode, route, prompt_id, choice_ids in (
        ("EP01_SLEEP", "EP01_CHOICE_SLEEP_FIRST", "EP01_SLEEP_FIRST_CHOICE_001", ["confirm", "cancel"]),
        ("EP01_MORNING", "EP01_CHOICE_MORNING_FIRST", "EP01_RESET_FIRST_004", ["same", "date", "quiet"]),
    ):
        options = copy.deepcopy(contents["NB_" + route]["1"])
        options.update({"event_id": mode, "node_ids": [mode], "visible_segment_ids": ["prompt"] + choice_ids})
        options["default_segments"] = options["visible_segment_ids"].copy()
        options["variables"] = {key: {} for key in options["visible_segment_ids"]}
        options["localization_keys"] = {key: "NB_PR_" + mode + ":" + key for key in options["visible_segment_ids"]}
        options.pop("choices", None)
        options.pop("cancel_index", None)
        for locale, values in options["locales"].items():
            source_values = contents["NB_" + route]["1"]["locales"][locale]
            values["prompt"] = nodes[prompt_id]["en_US"] or nodes[prompt_id]["ko_KR"] if locale == "en-US" else nodes[prompt_id]["ko_KR"]
            for index, choice_id in enumerate(choice_ids): values[choice_id] = source_values[f"option_{index}"]
            for index in range(len(choice_ids)): values.pop(f"option_{index}", None)
        contents["NB_PR_" + mode + "_OPTIONS"] = {"1": options}
        for index, choice_id in enumerate(choice_ids):
            selected = copy.deepcopy(contents["NB_" + route + f"_SELECT_{index}"]["1"])
            selected.update({"event_id": mode, "node_ids": [mode]})
            contents["NB_PR_" + mode + "_SELECT_" + choice_id.upper()] = {"1": selected}
    # Keep previously observed marks immutable; newly written sentence marks use v3.
    previous_marks = json.loads((ROOT / "game/data/notebook/self_mark_v2.json").read_text(encoding="utf-8"))
    sentence = copy.deepcopy(previous_marks["contents"]["NB_CH1_NOTE_A1_SENTENCE"]["2"])
    body = "아빠는 어디에?\n" + nodes["EP01_A1_SENTENCE_001"]["ko_KR"]
    sentence["source_symbol"] = "act/mark:ep01_sheet_v3"
    sentence["localization_keys"]["body"] = "NB_CH1_NOTE_A1_SENTENCE_V3"
    for locale in sentence["locales"]:
        sentence["locales"][locale]["body"] = body
        sentence["visual"]["text_runs"][locale] = [{"point": [-3.5, -1], "text": "아빠는"}, {"point": [-3.5, 0.5], "text": "어디에?"}]
        sentence["visual"]["description"][locale] = "아빠는 어디에?"
    contents["NB_CH1_NOTE_A1_SENTENCE"] = {"3": sentence}
    return result, {"format_version": 1, "contents": contents}


def add_hall_menu_variants(notebook: dict) -> None:
    route = "NB_EP01_CHOICE_EDGAR_HALL"
    original = notebook["contents"][route]["1"]
    for mask in range(4):
        indices = [index for index in range(2) if mask & (1 << index)] + [2]
        row = copy.deepcopy(original)
        identity = route + "_VISIBLE_" + str(mask)
        row["choices"] = [copy.deepcopy(original["choices"][index]) for index in indices]
        row["visible_segment_ids"] = [f"option_{index}" for index in range(len(indices))]
        row["default_segments"] = row["visible_segment_ids"].copy()
        row["variables"] = {key: {} for key in row["visible_segment_ids"]}
        row["localization_keys"] = {key: identity + ":" + key for key in row["visible_segment_ids"]}
        for locale, values in row["locales"].items():
            for key in list(values):
                if key.startswith("option_"): del values[key]
            for index, source_index in enumerate(indices):
                values[f"option_{index}"] = original["locales"][locale][f"option_{source_index}"]
        notebook["contents"][identity] = {"1": row}


def preserve_versions(notebook: dict, previous: dict) -> tuple[dict, dict]:
    """Keep every observed definition immutable; publish changed definitions anew."""
    merged = copy.deepcopy(previous)
    versions = {}
    for content_id, definitions in notebook["contents"].items():
        authored = definitions[max(definitions, key=int)]
        retained = merged["contents"].setdefault(content_id, {})
        matching = [int(version) for version, row in retained.items() if row == authored]
        if matching:
            version = max(matching)
        else:
            version = max((int(v) for v in retained), default=0) + 1
            retained[str(version)] = copy.deepcopy(authored)
        versions[content_id] = version
    return merged, versions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--previous-catalog", type=Path, required=True)
    args = parser.parse_args()
    runtime, notebook = compile_snapshot(json.loads(args.source.read_text(encoding="utf-8-sig")))
    add_hall_menu_variants(notebook)
    previous = json.loads(args.previous_catalog.read_text(encoding="utf-8-sig"))
    notebook, runtime["notebook_versions"] = preserve_versions(notebook, previous)
    outputs = {ROOT / "game/data/dialogue/chapter_one/ep01_runtime.json": runtime,
               ROOT / "game/data/notebook/ep01_sheet_v1.json": notebook}
    for path, data in outputs.items():
        text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                raise SystemExit(f"Stale generated file: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
    print(json.dumps({"nodes": len(runtime["nodes"]), "edges": len(runtime["edges"]),
                      "predicates": len(runtime["predicates"]), "effects": len(runtime["effects"]), "check": args.check}))


if __name__ == "__main__":
    main()
