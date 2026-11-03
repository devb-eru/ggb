"""Apply CNT-EP00 values while EP01 owns overlapping sleep/morning content."""
import argparse
import copy
import json
from pathlib import Path

from compile_script_sheet import compile_snapshot
from sync_ep01_sheet import NAMES, EN_NAMES, preserve_versions


RESPONSE_KEYS = ("P3_A_AUTHOR", "P3_A_LOCKED", "P4_A_FATHER_TEA")


def build(source: dict, project: Path, output: Path, baseline: dict | None = None) -> dict:
    runtime = compile_snapshot(source)
    nodes = {row["node_id"]: row for row in runtime["nodes"] if row["package_id"] == "CNT-EP00"}
    render_fields = ("speaker_id", "character_art", "portrait_position", "portrait_state")
    render_overrides = {}
    if baseline is not None:
        original_nodes = {row["node_id"]: row for row in compile_snapshot(baseline)["nodes"] if row["package_id"] == "CNT-EP00"}
        for identity, row in nodes.items():
            changes = {field: row[field] for field in render_fields if identity not in original_nodes or row[field] != original_nodes[identity][field]}
            if changes: render_overrides[identity] = changes
    else:
        previous_runtime = output / "game/data/dialogue/sheets/prologue_runtime.json"
        if previous_runtime.exists(): render_overrides = json.loads(previous_runtime.read_text(encoding="utf-8" )).get("prologue_render_overrides", {})
    aliases = {}
    sequences = {}
    templates = {}
    for key in RESPONSE_KEYS:
        sequence = sorted((identity for identity in nodes if identity.startswith(key + "_")), key=lambda identity: int(identity.rsplit("_", 1)[1]))
        if not sequence:
            sequences[key] = [key]
            continue
        if sequence != [key + "_%03d" % index for index in range(1, len(sequence) + 1)]:
            raise ValueError(f"Noncontiguous response sequence: {key}")
        if key.startswith("P3_"):
            for index, identity in enumerate(sequence):
                expected = sequence[index + 1] if index + 1 < len(sequence) else "P3_PROMPT"
                if (nodes[identity]["next_type"], nodes[identity]["next_id"]) != ("line", expected):
                    raise ValueError(f"Unexpected response destination: {identity}")
        sequences[key] = sequence
        aliases[key] = sequence[0]
        templates.update({identity: key for identity in sequence})
        for identity in sequence:
            if baseline is None: render_overrides.setdefault(identity, {field: nodes[identity][field] for field in render_fields})
    relative = Path("game/data/dialogue/prologue/prologue_text.tres")
    raw = ((output / relative) if (output / relative).exists() else (project / relative)).read_text(encoding="utf-8")
    prefix, payload = raw.split("localized_text = ", 1)
    # Godot string literals may contain actual newlines inside this dictionary.
    texts = json.loads(payload, strict=False)
    changed = []
    effective_nodes = dict(nodes)
    effective_nodes.update({key: nodes[value] for key, value in aliases.items()})
    for identity, row in effective_nodes.items():
        if identity not in texts["ko-KR"]:
            if identity not in templates: raise ValueError(f"Unconnected prologue text ID: {identity}")
        old_korean = texts["ko-KR"].get(identity)
        english = row["en_US"] or (texts["en-US"].get(identity, row["ko_KR"]) if old_korean == row["ko_KR"] else row["ko_KR"])
        if old_korean != row["ko_KR"] or texts["en-US"].get(identity) != english:
            changed.append(identity)
            texts["ko-KR"][identity] = row["ko_KR"]
            texts["en-US"][identity] = english
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(prefix + "localized_text = " + json.dumps(texts, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    registry_relative = Path("game/data/registries/text_registry.json")
    registry_path = output / registry_relative
    registry = json.loads((registry_path if registry_path.exists() else project / registry_relative).read_text(encoding="utf-8"))
    for identity, template in templates.items():
        definition = copy.deepcopy(registry["entries"][template])
        definition["speaker_id"] = nodes[identity]["speaker_id"].removeprefix("SERVANT_")
        registry["entries"][identity] = definition
    registry_path.parent.mkdir(parents=True, exist_ok=True)
    registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    relative = Path("game/data/notebook/prologue_v1.json")
    catalog = json.loads((project / relative).read_text(encoding="utf-8"))
    if (output / relative).exists():
        previous = json.loads((output / relative).read_text(encoding="utf-8"))
        for identity, definitions in previous["contents"].items():
            target = catalog["contents"].setdefault(identity, {})
            for version, definition in definitions.items():
                if version in target and target[version] != definition:
                    raise ValueError(f"Conflicting historical prologue: {identity}:{version}")
                target[version] = definition
    desired = {"format_version": 1, "contents": {}}
    for identity, definitions in list(catalog["contents"].items()):
        old = definitions[max(definitions, key=int)]
        updated = copy.deepcopy(old)
        for segment, text_id in old["localization_keys"].items():
            if text_id in changed:
                updated["locales"]["ko-KR"][segment] = texts["ko-KR"][text_id]
                updated["locales"]["en-US"][segment] = texts["en-US"][text_id]
        desired["contents"][identity] = {"1": updated}
    for text_id, template in templates.items():
        identity = "NB_PR_" + text_id
        definitions = catalog["contents"]["NB_PR_" + template]
        updated = copy.deepcopy(definitions[max(definitions, key=int)])
        row = nodes[text_id]
        updated.update(source_text_id=text_id, source_symbol=text_id, speaker_id=row["speaker_id"],
                       localization_keys={"body": text_id}, source_sheet_row=row["sheet_row"])
        for locale, names in (("ko-KR", NAMES), ("en-US", EN_NAMES)):
            updated["locales"][locale]["body"] = texts[locale][text_id]
            actor = row["speaker_id"].removeprefix("SERVANT_")
            if actor == "LUCA": actor = "LUKA"
            updated["locales"][locale]["speaker"] = texts[locale].get("UI_SPEAKER_" + actor, names[row["speaker_id"]])
        desired["contents"][identity] = {"1": updated}
    merged, bindings = preserve_versions(desired, catalog)
    versions = {identity: version for identity, version in bindings.items() if version > 1 or identity not in catalog["contents"]}
    (output / relative).write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    runtime["overlap_owner"] = "EP01"
    runtime["prologue_aliases"] = aliases
    runtime["prologue_response_sequences"] = sequences
    runtime["prologue_render_overrides"] = render_overrides
    source_path = output / "game/data/dialogue/sheets/prologue_runtime.json"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text(json.dumps(runtime, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # One existing source binding map covers both EP01 lines and prologue menus.
    path = output / "game/data/dialogue/chapter_one/ep01_runtime.json"
    ep01 = json.loads(path.read_text(encoding="utf-8"))
    ep01["notebook_versions"].update(versions)
    path.write_text(json.dumps(ep01, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"source_url": runtime["source_url"], "source_sha256": runtime["source_sha256"],
            "overlap_owner": "EP01", "nodes_checked": len(nodes), "changed_text_ids": changed,
            "notebook_versions": versions, "aliases": aliases, "response_sequences": sequences}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--baseline-source", type=Path)
    args = parser.parse_args()
    result = build(json.loads(args.source.read_text(encoding="utf-8-sig")), args.project, args.output,
                   json.loads(args.baseline_source.read_text(encoding="utf-8-sig")) if args.baseline_source else None)
    (args.output / "prologue_sync_manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
