"""Copy selected UI originals and record practical alpha bounds for Godot.

Run with Pillow installed. No source PNG is resampled or overwritten.
"""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "outputs/ui-assets-2026-10-21"
TARGET = ROOT / "game/assets/ui/design_2026_10"
REFERENCES = ROOT / "docs/design/gui-ux-2026-10-20/references"


def main():
    source_manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    TARGET.mkdir(parents=True, exist_ok=True)
    rows = []
    for asset in source_manifest["assets"]:
        original = SOURCE / asset["file"]
        assert hashlib.sha256(original.read_bytes()).hexdigest() == asset["sha256"], original
        destination = TARGET / original.name
        shutil.copyfile(original, destination)
        with Image.open(original) as image:
            # Generated files contain faint alpha noise far outside their silhouette.
            bounds = image.convert("RGBA").getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
        if asset["id"] == "dialogue_overlay":
            bounds = asset["content_bbox"]  # Preserve the intended soft gradient.
        rows.append({
            "id": asset["id"], "file": original.name,
            "logical_size": asset["logical_size"], "pixel_size": asset["pixel_size"],
            "content_bbox": asset["content_bbox"], "runtime_bbox": list(bounds),
            "sha256": asset["sha256"],
        })
    for character in ["protagonist", "edgar", "iris", "mara2"]:
        shutil.copyfile(REFERENCES / f"character-{character}.png", TARGET / f"character_{character}.png")
    manifest = {"schema_version": 1, "viewport": [1920, 1080],
                "source_manifest": "outputs/ui-assets-2026-10-21/manifest.json",
                "runtime_notes": "Original PNGs preserved. runtime_bbox ignores faint alpha noise; native Godot controls supply all text.",
                "assets": rows}
    (TARGET / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Prepared {len(rows)} UI components and 4 original character layers.")


if __name__ == "__main__":
    main()
