#!/usr/bin/env python3
"""Validate exported GGB content Sheet schema v3 CSV files."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path


TOOL_VERSION = "codex-sheet-contract-lint/1.0.0"
RUNTIME_COLUMNS = {
    "package_id", "node_id", "draft_id", "line_id", "approval_status",
    "localization_status", "revision", "scene_id", "content_type", "speaker_id",
    "character_art", "portrait_position", "portrait_state", "direction", "ko_KR",
    "en_US", "next_type", "next_id", "source_file", "source_anchor", "source_commit",
    "source_checksum", "location_id", "object_id", "trigger", "display_condition_id",
    "route_predicate_id", "repeat_policy",
}
ROUTE_COLUMNS = {
    "package_id", "route_id", "edge_id", "edge_order", "predicate_id",
    "target_type", "target_id", "is_fallback", "priority", "validation_status",
}
PREDICATE_COLUMNS = {
    "package_id", "predicate_id", "state_path", "comparator", "typed_value",
    "value_type", "registration_status",
}
EFFECT_COLUMNS = {
    "package_id", "effect_id", "event_id", "node_id", "effect_order", "state_path",
    "operation", "value_type", "typed_value", "writer", "commit_phase",
    "repeat_policy", "registration_status",
}
VOCAB_FIELDS = {
    "approval_status", "localization_status", "content_type", "speaker_id",
    "character_art", "portrait_position", "portrait_state", "next_type", "trigger",
    "location_id", "object_id", "repeat_policy",
}
RESERVED_TARGETS = {
    "", "NONE", "SYS_INTERACTION_END", "SYS_RETURN_TO_PARENT", "SYS_NORMAL_RESET",
    "EP02_ENTRY_C0", "EP03_ENTRY_D0",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.reader(handle))
    header_index = next(
        (index for index, row in enumerate(rows[:5]) if "package_id" in row),
        None,
    )
    if header_index is None:
        return []
    headers = rows[header_index]
    result: list[dict[str, str]] = []
    for values in rows[header_index + 1:]:
        if not any(values):
            continue
        padded = values + [""] * (len(headers) - len(values))
        result.append(dict(zip(headers, padded)))
    return result


def require_columns(rows: list[dict[str, str]], required: set[str], label: str) -> list[str]:
    available = set(rows[0]) if rows else set()
    return [f"{label}: missing column {name}" for name in sorted(required - available)]


def duplicate_errors(rows: list[dict[str, str]], fields: tuple[str, ...], label: str) -> list[str]:
    keys = [tuple(row.get(field, "") for field in fields) for row in rows]
    return [f"{label}: duplicate key {key}" for key, count in Counter(keys).items() if count > 1]


def route_errors(runtime: list[dict[str, str]], routes: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    node_ids = {row["node_id"] for row in runtime}
    route_ids = {row["route_id"] for row in routes}
    scene_ids = {row["scene_id"] for row in runtime}

    for row in runtime:
        target = row.get("next_id", "")
        target_type = row.get("next_type", "")
        if target in RESERVED_TARGETS:
            continue
        valid = (
            target_type == "line" and target in node_ids
            or target_type in {"choice", "hub", "router"} and target in route_ids
            or target_type == "scene" and target in scene_ids
            or target_type in {"end", "episode_exit"}
        )
        if not valid:
            errors.append(f"runtime: unresolved {target_type} target {target} from {row['node_id']}")

    route_graph: dict[str, list[dict[str, str]]] = defaultdict(list)
    targeted_nodes: set[str] = set()
    scene_entries: dict[str, str] = {}
    for row in runtime:
        scene_entries.setdefault(row["scene_id"], row["node_id"])
        if row.get("next_type") == "line" and row.get("next_id") in node_ids:
            targeted_nodes.add(row["next_id"])
    for edge in routes:
        route_graph[edge["route_id"]].append(edge)
        target = edge["target_id"]
        target_type = edge["target_type"]
        valid = (
            target_type == "node" and target in node_ids
            or target_type == "route" and target in route_ids
            or target_type == "scene" and target in scene_ids
            or target_type in {"system", "episode_exit"}
        )
        if not valid:
            errors.append(f"route: unresolved {target_type} target {target} from {edge['edge_id']}")
        if target_type == "node" and target in node_ids:
            targeted_nodes.add(target)

    memo: dict[str, bool] = {}

    def can_exit(route_id: str, visiting: frozenset[str] = frozenset()) -> bool:
        if route_id in memo:
            return memo[route_id]
        if route_id in visiting:
            return False
        next_visiting = visiting | {route_id}
        result = any(
            edge["target_type"] != "route"
            or can_exit(edge["target_id"], next_visiting)
            for edge in route_graph.get(route_id, [])
        )
        memo[route_id] = result
        return result

    for route_id in sorted(route_ids):
        if not can_exit(route_id):
            errors.append(f"route: no terminating edge reachable from {route_id}")

    roots = [row["node_id"] for row in runtime if row["node_id"] not in targeted_nodes]
    if runtime:
        roots.append(runtime[0]["node_id"])
    seen: set[tuple[str, str]] = set()
    stack = [("node", node_id) for node_id in roots]
    runtime_by_id = {row["node_id"]: row for row in runtime}
    while stack:
        kind, item_id = stack.pop()
        if (kind, item_id) in seen:
            continue
        seen.add((kind, item_id))
        if kind == "node":
            row = runtime_by_id.get(item_id)
            if row is None:
                continue
            if row["next_type"] == "line":
                stack.append(("node", row["next_id"]))
            elif row["next_type"] in {"choice", "hub", "router"}:
                stack.append(("route", row["next_id"]))
            elif row["next_type"] == "scene" and row["next_id"] in scene_entries:
                stack.append(("node", scene_entries[row["next_id"]]))
        else:
            for edge in route_graph.get(item_id, []):
                if edge["target_type"] == "node":
                    stack.append(("node", edge["target_id"]))
                elif edge["target_type"] == "route":
                    stack.append(("route", edge["target_id"]))
                elif edge["target_type"] == "scene" and edge["target_id"] in scene_entries:
                    stack.append(("node", scene_entries[edge["target_id"]]))
    for node_id in sorted(node_ids):
        if ("node", node_id) not in seen:
            errors.append(f"runtime: unreachable node {node_id}")
    return errors


def namespace_errors(
    runtime: list[dict[str, str]], routes: list[dict[str, str]]
) -> list[str]:
    errors: list[str] = []
    allowed = {"SYS_NORMAL_RESET"}
    for field, rows in (
        ("node_id", runtime),
        ("scene_id", runtime),
        ("route_id", routes),
    ):
        packages_by_id: dict[str, set[str]] = defaultdict(set)
        for row in rows:
            packages_by_id[row[field]].add(row["package_id"])
        for item_id, packages in packages_by_id.items():
            if len(packages) > 1 and item_id not in allowed:
                errors.append(f"namespace: cross-package {field} collision {item_id}")
    return errors


def state_errors(
    predicates: list[dict[str, str]],
    effects: list[dict[str, str]],
    registry: dict,
) -> list[str]:
    errors: list[str] = []
    paths = registry.get("paths", {})
    for row in predicates:
        if row.get("registration_status") == "PROPOSED":
            errors.append(f"predicate: PROPOSED {row['predicate_id']}")
        if row.get("state_path") not in paths:
            errors.append(f"predicate: unregistered path {row.get('state_path')}")
    for row in effects:
        if row.get("registration_status") == "PROPOSED":
            errors.append(f"effect: PROPOSED {row['effect_id']}")
        spec = paths.get(row.get("state_path"))
        if spec is None:
            errors.append(f"effect: unregistered path {row.get('state_path')}")
        elif spec.get("writer") != row.get("writer"):
            errors.append(f"effect: writer mismatch {row['effect_id']}")
        if row.get("operation") not in {"set", "increment", "add", "remove"}:
            errors.append(f"effect: invalid operation {row.get('operation')}")
    return errors


def vocabulary_errors(runtime: list[dict[str, str]], vocab: dict) -> list[str]:
    errors: list[str] = []
    for row_number, row in enumerate(runtime, start=4):
        for field in VOCAB_FIELDS:
            if row.get(field, "") not in set(vocab.get(field, [])):
                errors.append(f"runtime row {row_number}: invalid {field}={row.get(field, '')}")
    return errors


def provenance_errors(runtime: list[dict[str, str]]) -> list[str]:
    required = ("source_file", "source_anchor", "source_commit", "source_checksum")
    return [
        f"runtime row {index}: missing source evidence"
        for index, row in enumerate(runtime, start=4)
        if any(not row.get(field) for field in required)
    ]


def ko_kr_errors(runtime: list[dict[str, str]], baseline: list[dict[str, str]]) -> list[str]:
    expected = {(row["package_id"], row["node_id"]): row.get("ko_KR", "") for row in baseline}
    actual = {(row["package_id"], row["node_id"]): row.get("ko_KR", "") for row in runtime}
    keys = set(expected) | set(actual)
    return [f"ko_KR mismatch: {key}" for key in sorted(keys) if expected.get(key) != actual.get(key)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--routes", required=True, type=Path)
    parser.add_argument("--predicates", required=True, type=Path)
    parser.add_argument("--effects", required=True, type=Path)
    parser.add_argument("--state-registry", required=True, type=Path)
    parser.add_argument("--vocab", required=True, type=Path)
    parser.add_argument("--baseline-runtime", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    runtime = read_csv(args.runtime)
    routes = read_csv(args.routes)
    predicates = read_csv(args.predicates)
    effects = read_csv(args.effects)
    registry = json.loads(args.state_registry.read_text(encoding="utf-8"))
    vocab = json.loads(args.vocab.read_text(encoding="utf-8"))

    errors: list[str] = []
    errors += require_columns(runtime, RUNTIME_COLUMNS, "runtime")
    errors += require_columns(routes, ROUTE_COLUMNS, "routes")
    errors += require_columns(predicates, PREDICATE_COLUMNS, "predicates")
    errors += require_columns(effects, EFFECT_COLUMNS, "effects")
    if not errors:
        errors += duplicate_errors(runtime, ("package_id", "node_id"), "runtime")
        errors += duplicate_errors(routes, ("package_id", "edge_id"), "routes")
        errors += duplicate_errors(predicates, ("package_id", "predicate_id"), "predicates")
        errors += duplicate_errors(effects, ("package_id", "effect_id"), "effects")
        errors += route_errors(runtime, routes)
        errors += namespace_errors(runtime, routes)
        errors += state_errors(predicates, effects, registry)
        errors += vocabulary_errors(runtime, vocab)
        errors += provenance_errors(runtime)
        if args.baseline_runtime:
            errors += ko_kr_errors(runtime, read_csv(args.baseline_runtime))

    result = {
        "tool_version": TOOL_VERSION,
        "result": "PASS" if not errors else "FAIL",
        "error_count": len(errors),
        "errors": errors,
        "counts": {
            "runtime": len(runtime),
            "routes": len(routes),
            "predicates": len(predicates),
            "effects": len(effects),
        },
    }
    payload = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(payload, encoding="utf-8")
    else:
        sys.stdout.write(payload)
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
