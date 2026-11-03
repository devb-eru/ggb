"""Compare controlled runtime tables from two read-only Sheet snapshots."""
import argparse
import json
from pathlib import Path

from compile_script_sheet import compile_snapshot


def compare(previous, fresh):
    keys = {"nodes": "node_id", "edges": "edge_id", "predicates": "predicate_id", "effects": "effect_id"}
    report = {}
    for table, key in keys.items():
        old = {row[key]: row for row in previous[table]}
        new = {row[key]: row for row in fresh[table]}
        changed = []
        for identity in sorted(old.keys() & new.keys()):
            fields = {field: {"previous": old[identity].get(field), "fresh": new[identity].get(field)}
                      for field in old[identity].keys() | new[identity].keys()
                      if old[identity].get(field) != new[identity].get(field)}
            if fields:
                changed.append({"id": identity, "package": new[identity].get("package_id"), "fields": fields})
        report[table] = {"previous_count": len(old), "fresh_count": len(new),
                         "added": [new[identity] for identity in sorted(new.keys() - old.keys())],
                         "removed": [old[identity] for identity in sorted(old.keys() - new.keys())], "changed": changed}
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--previous", type=Path, required=True)
    parser.add_argument("--fresh", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    read = lambda path: json.loads(path.read_text(encoding="utf-8-sig"))
    result = compare(compile_snapshot(read(args.previous), allow_continuations=True),
                     compile_snapshot(read(args.fresh), allow_continuations=True))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({table: {"previous": row["previous_count"], "fresh": row["fresh_count"],
                              "added": len(row["added"]), "removed": len(row["removed"]), "changed": len(row["changed"])}
                      for table, row in result.items()}, ensure_ascii=False))
