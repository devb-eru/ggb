"""Separate EP02 static references from actual notebook disclosure evidence."""
import argparse
import json
import re
from collections import Counter
from pathlib import Path


def audit(runtime: dict, scripts: Path, observed: dict) -> dict:
    nodes = {row["node_id"]: row for row in runtime["nodes"]}
    routes = {}
    for edge in runtime["edges"]:
        routes.setdefault(edge["route_id"], []).append(edge)
    files = [path for path in scripts.rglob("*.gd") if "tests" not in path.parts]
    sources = {str(path.relative_to(scripts)): path.read_text(encoding="utf-8-sig") for path in files}
    references = {}
    for path, text in sources.items():
        for identity in re.findall(r'"(EP02_[A-Z0-9_]+)"', text):
            if identity in nodes or identity in routes:
                references.setdefault(identity, set()).add(path)
    dynamic = set()
    short_source = sources.get(str(Path("systems") / "ep02_short_reactions.gd"), "")
    if '"EP02_REL_EDGAR_C0_"' in short_source:
        dynamic.update("EP02_REL_EDGAR_C0_" + tier for tier in ("LOW", "MID", "HIGH"))
    modal_source = sources.get(str(Path("systems") / "modal_notebook.gd"), "")
    modal_catalog = scripts.parent / "data/notebook/ep02_modal_versions.json"
    if 'CONTENT.latest_version("NB_MODAL_MIRROR_ROUTE_OPTIONS")' in modal_source and modal_catalog.exists():
        catalog = json.loads(modal_catalog.read_text(encoding="utf-8-sig"))
        versions = catalog["contents"]["NB_MODAL_MIRROR_ROUTE_OPTIONS"]
        dynamic.update(versions[max(versions, key=int)].get("source_sheet_segments", {}).values())
        controller = sources.get(str(Path("chapters") / "black_mirror_controller.gd"), "")
        memory_selector = 'MODAL_NOTES.options("EP02_J3_MEMORY_REPLAY" if replay else "EP02_J3_MEMORY")' in controller
        for selector in ("EP02_DISCARD", "EP02_TRACE", "EP02_J3_RESTORE", "EP02_J3_MEMORY", "EP02_J3_MEMORY_REPLAY"):
            if f'MODAL_NOTES.options("{selector}")' in controller or (memory_selector and selector in ("EP02_J3_MEMORY", "EP02_J3_MEMORY_REPLAY")):
                versions = catalog["contents"].get(f"NB_MODAL_{selector}_OPTIONS", {})
                if versions:
                    dynamic.update(versions[max(versions, key=int)].get("source_sheet_segments", {}).values())
    for stage, count in (("C3", 5), ("C4", 4), ("J3", 3)):
        dynamic.update(f"EP02_{stage}_FB_HINT{level}" for level in range(1, count + 1))
    dynamic.update(f"EP02_C4_SUCCESS_{owner}_001" for owner in ("EDGAR", "MARA1"))
    for diagnostic in ("BODY", "PERSONALITY", "EXTERNAL", "LIFE", "WAKE", "MASK"):
        for suffix in ("FIRST", "REPEAT"):
            dynamic.add(f"EP02_C5_HOT_{diagnostic}_{suffix}")
        identity = f"EP02_C5_{diagnostic}_001"
        if identity in nodes:
            dynamic.add(identity)
    for owner in ("EDGAR", "MARA1", "LUCA", "IRIS", "MARA2", "SUBJECT"):
        dynamic.add(f"EP02_C5_HOT_{owner}_CHANNEL")
        for suffix in ("FIRST", "REPEAT"):
            dynamic.add(f"EP02_C5_CH_{owner}_{suffix}")
    for prefix, count in (("WATER", 6), ("STAB", 2), ("ACTIVE", 3)):
        dynamic.update(f"EP02_C3_UI_{prefix}_ADD_{amount}" for amount in range(1, count + 1))
    mirror_cases = ("PRE", "C0_FIRST", "C0_REPEAT", "C1_DRY", "CF", "C5", "C5_REPEAT", "C3_READY", "C4_DRY_OK", "C4_COMMIT", "RESET_AFTER_FAIL")
    dynamic.update("EP02_OBJ_MIRROR_" + suffix for suffix in mirror_cases)
    dynamic.update(("EP02_C5_CH_SCAN_PROGRESS_1", "EP02_C5_CH_SCAN_PROGRESS_2"))
    object_source = sources.get("systems/ep02_object_surfaces.gd", sources.get("systems\\ep02_object_surfaces.gd", ""))
    objects = set(re.findall(r'"(OBJ_[A-Z0-9_]+)"', object_source))
    for row in nodes.values():
        if row["content_type"] == "DOCUMENT" and row["next_type"] == "end" and row["object_id"] in objects:
            dynamic.add(row["node_id"])
    unknown_dynamic = sorted(dynamic - nodes.keys())
    bound = set()
    pending = list(references) + list(dynamic & nodes.keys())
    visited_routes = set()
    automatic_scenes = {"EP02_SCENE_05", "EP02_SCENE_09", "EP02_SCENE_10", "EP02_SCENE_12"}
    while pending:
        identity = pending.pop()
        if identity in routes and identity not in visited_routes:
            visited_routes.add(identity)
            for edge in routes[identity]:
                if edge["target_type"] in ("node", "route"):
                    pending.append(edge["target_id"])
                elif edge["target_type"] == "scene" and edge["target_id"] in automatic_scenes:
                    entry = next((row["node_id"] for row in nodes.values() if row["scene_id"] == edge["target_id"]), None)
                    if entry:
                        pending.append(entry)
            continue
        if identity not in nodes or identity in bound:
            continue
        bound.add(identity)
        node = nodes[identity]
        if node["next_type"] in ("line", "router", "choice"):
            pending.append(node["next_id"])
        elif node["next_type"] == "scene" and node["next_id"] in automatic_scenes:
            entry = next((row["node_id"] for row in nodes.values() if row["scene_id"] == node["next_id"]), None)
            if entry:
                pending.append(entry)
    displayed = set(observed.get("nodes", [])) & nodes.keys()
    rows = []
    for identity, row in nodes.items():
        rows.append({"node_id": identity, "content_type": row["content_type"], "sheet_row": row["sheet_row"],
                     "location_id": row["location_id"], "object_id": row["object_id"],
                     "static_binding_candidate": identity in bound,
                     "observed_in_gameplay_test": identity in displayed,
                     "direct_files": sorted(references.get(identity, []))})
    return {"warning": "Static references and graph expansion are candidates, not reachability or completion proof. Observed nodes exclude static catalog rendering checks.",
            "total_nodes": len(nodes), "static_candidates": len(bound), "observed_nodes": len(displayed),
            "unbound_by_type": dict(Counter(nodes[identity]["content_type"] for identity in nodes.keys() - bound)),
            "unknown_dynamic_ids": unknown_dynamic, "rows": rows,
            "effects": [{"effect_id": effect["effect_id"], "node_id": effect["node_id"], "state_path": effect["state_path"],
                         "node_has_static_candidate": effect["node_id"] in bound,
                         "node_observed": effect["node_id"] in displayed} for effect in runtime["effects"]]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--scripts", type=Path, required=True)
    parser.add_argument("--observed", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    observed = json.loads(args.observed.read_text(encoding="utf-8-sig")) if args.observed else {}
    report = audit(json.loads(args.runtime.read_text(encoding="utf-8-sig")), args.scripts, observed)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in ("rows", "effects")}, ensure_ascii=False))
