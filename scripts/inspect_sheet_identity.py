"""Report ambiguous source identities without repairing or modifying the Sheet."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

from compile_script_sheet import TABLES, entered


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source = json.loads(args.source.read_text(encoding="utf-8-sig"))
    report = {}
    for sheet in source["sheets"]:
        title = sheet["properties"]["title"]
        if title not in TABLES:
            continue
        table, key = TABLES[title]
        rows = sheet["data"][0]["rowData"]
        headers = [entered(cell) for cell in rows[0].get("values", [])]
        grouped = defaultdict(list)
        missing = []
        count = 0
        for number, row in enumerate(rows[1:], start=4):
            values = [entered(cell) for cell in row.get("values", [])]
            if not any(value != "" for value in values):
                continue
            record = dict(zip(headers, values + [""] * (len(headers) - len(values))))
            record["sheet_row"] = number
            count += 1
            if not record.get(key): missing.append(record)
            else: grouped[record[key]].append(record)
        report[table] = {"count": count, "missing": missing,
                         "duplicates": {identity: records for identity, records in grouped.items() if len(records) > 1}}
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({table: {"count": row["count"], "missing": len(row["missing"]),
                              "duplicates": {identity: [record["sheet_row"] for record in records] for identity, records in row["duplicates"].items()}}
                      for table, row in report.items()}, ensure_ascii=False))
