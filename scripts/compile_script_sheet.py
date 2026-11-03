"""Compile read-only connector snapshots, preserving authored values and row origins."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


TABLES = {
    "09_Runtime_Master": ("nodes", "node_id"),
    "10_Route_Edge_Master": ("edges", "edge_id"),
    "11_State_Predicate": ("predicates", "predicate_id"),
    "12_State_Effect": ("effects", "effect_id"),
}


def entered(cell: dict):
    value = cell.get("userEnteredValue", {})
    for key in ("stringValue", "numberValue", "boolValue"):
        if key in value:
            return value[key]
    if "formulaValue" in value:
        resolved = cell.get("effectiveValue", {})
        for key in ("stringValue", "numberValue", "boolValue"):
            if key in resolved:
                return resolved[key]
        raise ValueError("Formula result missing; re-read CellData with effectiveValue")
    return ""


def connect_continuations(records: list[dict]) -> list[dict]:
    """Attach author-approved unnamed lines without changing the source sheet."""
    output = []
    anchor = None
    pending = []

    def flush():
        if not pending:
            return
        if anchor is None:
            raise ValueError("Unnamed line has no preceding authored node")
        destination = (anchor["next_type"], anchor["next_id"])
        for index, raw in enumerate(pending, start=1):
            if not raw.get("ko_KR") or not raw.get("speaker_id"):
                raise ValueError(f"Incomplete unnamed dialogue at row {raw['sheet_row']}")
            if raw.get("next_type") or raw.get("next_id"):
                raise ValueError(f"Unnamed line has an explicit destination; review row {raw['sheet_row']}")
            row = {key: (value if value != "" else anchor.get(key, "")) for key, value in raw.items()}
            row["node_id"] = anchor["node_id"] + "_EXT_%03d" % index
            row["draft_id"] = row["node_id"]
            row["line_id"] = "NONE"
            row["adapter_provenance"] = {"source_row": raw["sheet_row"], "inherited_from": anchor["node_id"], "synthetic_node_id": True}
            row["next_type"] = "line" if index < len(pending) else destination[0]
            row["next_id"] = anchor["node_id"] + "_EXT_%03d" % (index + 1) if index < len(pending) else destination[1]
            output.append(row)
        anchor["next_type"] = "line"
        anchor["next_id"] = pending and anchor["node_id"] + "_EXT_001"
        pending.clear()

    for row in records:
        if row.get("node_id"):
            flush()
            anchor = row
            output.append(row)
        else:
            pending.append(row)
    flush()
    return output


def compile_snapshot(source: dict, allow_continuations: bool = False) -> dict:
    result = {
        "schema_version": 1,
        "source_url": source["spreadsheetUrl"],
        "source_sha256": hashlib.sha256(
            json.dumps(source, ensure_ascii=False, sort_keys=True).encode("utf-8")
        ).hexdigest(),
    }
    for sheet in source["sheets"]:
        title = sheet["properties"]["title"]
        if title not in TABLES:
            continue
        table, identity = TABLES[title]
        if table in result:
            raise ValueError(f"Duplicate source table: {title}")
        blocks = sheet.get("data", [])
        if len(blocks) != 1 or blocks[0].get("startRow", 0) != 2:
            raise ValueError(f"Expected one bounded range beginning on header row 3: {title}")
        block = blocks[0]
        rows = block.get("rowData", [])
        if not rows:
            raise ValueError(f"Missing header: {title}")
        headers = [entered(cell) for cell in rows[0].get("values", [])]
        if identity not in headers or len(headers) != len(set(headers)) or "" in headers:
            raise ValueError(f"Invalid headers: {title}")
        records = []
        seen = set()
        for row_number, row in enumerate(rows[1:], start=4):
            values = [entered(cell) for cell in row.get("values", [])]
            if not any(value != "" for value in values):
                continue
            if len(values) > len(headers):
                raise ValueError(f"Unexpected cells: {title}:{row_number}")
            record = dict(zip(headers, values + [""] * (len(headers) - len(values))))
            key = record[identity]
            continuation = not key and table == "nodes" and allow_continuations
            if not continuation and (not isinstance(key, str) or not key or key in seen):
                raise ValueError(f"Missing/duplicate identity: {title}:{row_number}: {key}")
            seen.add(key)
            record["sheet_row"] = row_number
            records.append(record)
        if table == "nodes" and allow_continuations:
            records = connect_continuations(records)
        identities = [record[identity] for record in records]
        if len(identities) != len(set(identities)):
            raise ValueError(f"Identity collision after normalization: {title}")
        result[table] = records
    if any(table not in result for table, _ in TABLES.values()):
        raise ValueError("Missing runtime master table")
    packages = {row["package_id"] for row in result["nodes"]}
    result["source_package_ids"] = sorted(packages)
    result["package_id"] = next(iter(packages)) if len(packages) == 1 else "MIXED_SOURCE"
    nodes = {row["node_id"] for row in result["nodes"]}
    routes = {row["route_id"] for row in result["edges"]}
    for row in result["nodes"]:
        kind, target = row["next_type"], row["next_id"]
        if kind in {"node", "line"} and target not in nodes:
            raise ValueError(f"Missing node {target} from {row['node_id']}")
        if kind in {"route", "choice"} and target not in routes:
            raise ValueError(f"Missing route {target} from {row['node_id']}")
    for row in result["edges"]:
        kind, target = row["target_type"], row["target_id"]
        if kind == "node" and target not in nodes:
            raise ValueError(f"Missing edge node {target} from {row['edge_id']}")
        if kind == "route" and target not in routes:
            raise ValueError(f"Missing edge route {target} from {row['edge_id']}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--allow-continuations", action="store_true")
    args = parser.parse_args()
    result = compile_snapshot(json.loads(args.source.read_text(encoding="utf-8-sig")), args.allow_continuations)
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if args.output.read_text(encoding="utf-8") != rendered:
            raise SystemExit(f"Stale runtime data: {args.output}")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(json.dumps({"package": result["package_id"], **{
        table: len(result[table]) for table, _ in TABLES.values()
    }}))


if __name__ == "__main__":
    main()
