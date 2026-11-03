"""Version EP02 hint disclosures without rewriting historical definitions."""
import argparse
import copy
import json
from pathlib import Path


def build(runtime: dict, base: dict, previous: dict) -> dict:
    nodes = {row["node_id"]: row for row in runtime["nodes"]}
    result = copy.deepcopy(previous)
    result.setdefault("format_version", 1)
    result.setdefault("contents", {})
    for stage, count in (("C3", 5), ("C4", 4), ("J3", 3)):
        for level in range(1, count + 1):
            identity = f"NB_HINT_{stage}_H{level}"
            source_id = f"EP02_{stage}_FB_HINT{level}"
            versions = copy.deepcopy(base["contents"].get(identity, {}))
            for version, row in previous.get("contents", {}).get(identity, {}).items():
                if version in versions and versions[version] != row:
                    raise ValueError(f"Conflicting historical hint: {identity}:{version}")
                versions[version] = copy.deepcopy(row)
            if versions:
                updated = copy.deepcopy(versions[max(versions, key=int)])
            else:
                updated = copy.deepcopy(base["contents"]["NB_HINT_C3_H1"]["1"])
                updated.update(event_id=stage, node_ids=[stage], action_or_variant=f"requested_H{level}", text_key=f"{stage}:{level - 1}")
                for locale in updated["locales"]:
                    updated["locales"][locale]["title"] = f"일지 복원 - H{level}" if locale == "ko-KR" else f"Journal restoration - H{level}"
                updated["localization_keys"] = {"body": identity + "_BODY"}
                updated["localization_key"] = identity + "_BODY"
            source = nodes[source_id]
            updated.update(text_source="res://data/dialogue/sheets/ep02_runtime.json",
                           source_sheet_segments={"body": source_id})
            updated["locales"]["ko-KR"]["body"] = source["ko_KR"]
            updated["locales"]["en-US"]["body"] = source["en_US"] or source["ko_KR"]
            if not versions or versions[max(versions, key=int)] != updated:
                version = str(max(map(int, versions), default=0) + 1)
                result["contents"].setdefault(identity, {})[version] = updated
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--catalog", type=Path, action="append", default=[])
    parser.add_argument("--fresh-output", action="store_true", help="Rebuild an unpublished companion from canonical catalogs")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    previous = json.loads(args.output.read_text(encoding="utf-8-sig")) if args.output.exists() and not args.fresh_output else {"format_version": 1, "contents": {}}
    base = json.loads(args.base.read_text(encoding="utf-8-sig"))
    for path in args.catalog:
        catalog = json.loads(path.read_text(encoding="utf-8-sig"))
        for identity, versions in catalog["contents"].items():
            target = base["contents"].setdefault(identity, {})
            for version, row in versions.items():
                if version in target and target[version] != row:
                    raise ValueError(f"Conflicting canonical definition: {identity}:{version}")
                target[version] = row
    result = build(json.loads(args.runtime.read_text(encoding="utf-8-sig")), base, previous)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"hint_ids": len(result["contents"]), "versions": sum(len(rows) for rows in result["contents"].values())}))
