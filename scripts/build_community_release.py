#!/usr/bin/env python3
# Created by Dukes
"""
Build community_map.json.gz + merged manifest.json for GitHub Release speedlimits-v1.

Reads compact map tiles from tiles/*.json.gz (same layout the Worker commits).
Emits SpeedLimitLocation JSON (snake_case) expected by SpeedLimitPackageManager.

When MERGE_INTO_REGIONAL_PACKS is not "0", downloads each regional .json.gz from the
current release and applies speed/name/type overrides by matching segment_id. Existing
app builds prefer regional packs before "Community map" alphabetically; patching
regionals makes approved edits visible without an app update. URLs and filenames stay
the same (--clobber upload).
"""

from __future__ import annotations

import gzip
import json
import math
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
TILES_DIR = REPO_ROOT / "tiles"
DIST_DIR = REPO_ROOT / "dist"

DEFAULT_MANIFEST_URL = (
    "https://github.com/DukesR8/Camera-Database/releases/download/speedlimits-v1/manifest.json"
)


def load_json_gz(path: Path) -> dict:
    with gzip.open(path, "rb") as f:
        return json.loads(f.read().decode("utf-8"))


def segment_id_from_compact(obj: dict) -> int:
    sid = obj.get("id") or ""
    if isinstance(sid, str) and sid.startswith("cs:"):
        try:
            return int(sid.split(":", 1)[1], 10)
        except ValueError:
            pass
    return abs(hash(str(sid))) % (2**31 - 1) or 1


def compact_to_downloaded_segment(obj: dict) -> dict | None:
    c = obj.get("c")
    if not isinstance(c, list) or len(c) < 1:
        return None
    f = int(obj.get("f") or 0)
    r = int(obj.get("r") or 0)
    fwd = f if f > 0 else None
    rev = r if r > 0 else None
    if fwd is None and rev is None:
        return None
    t = obj.get("t")
    road_type = int(t) if t is not None else None
    return {
        "segment_id": segment_id_from_compact(obj),
        "road_name": str(obj.get("n") or ""),
        "road_type": road_type,
        "speed_limit_forward": fwd,
        "speed_limit_reverse": rev,
        "coordinates": c,
    }


def bounds_from_coords(segments: list[dict]) -> dict:
    min_lat = math.inf
    max_lat = -math.inf
    min_lon = math.inf
    max_lon = -math.inf
    for seg in segments:
        for pt in seg.get("coordinates") or []:
            if not isinstance(pt, (list, tuple)) or len(pt) < 2:
                continue
            lon, lat = float(pt[0]), float(pt[1])
            min_lat = min(min_lat, lat)
            max_lat = max(max_lat, lat)
            min_lon = min(min_lon, lon)
            max_lon = max(max_lon, lon)
    if not math.isfinite(min_lat):
        return {"min_lat": 0.0, "max_lat": 0.0, "min_lon": 0.0, "max_lon": 0.0}
    return {
        "min_lat": min_lat,
        "max_lat": max_lat,
        "min_lon": min_lon,
        "max_lon": max_lon,
    }


def fetch_release_manifest(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "DukesR8-release-builder"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_bytes(url: str, timeout: int = 600) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "DukesR8-release-builder"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def release_assets_base(manifest_url: str) -> str:
    return manifest_url.rsplit("/", 1)[0]


def local_tile_keys() -> list[str]:
    """Return sorted tile keys that actually exist as .json.gz files on disk."""
    return sorted(p.stem for p in TILES_DIR.glob("*.json.gz"))


def collect_segment_overrides() -> dict[int, dict]:
    """
    Stable segment_id -> override fields from editor tiles (no duplicate-id bumping).
    Last tile wins for the same id.
    """
    overrides: dict[int, dict] = {}
    tile_keys = local_tile_keys()
    for key in tile_keys:
        gz_path = TILES_DIR / f"{key}.json.gz"
        try:
            tile = load_json_gz(gz_path)
        except Exception as e:
            print(f"warn: overrides skip {gz_path.name}: {e}", file=sys.stderr)
            continue
        for obj in tile.get("s") or []:
            if not isinstance(obj, dict):
                continue
            seg = compact_to_downloaded_segment(obj)
            if not seg:
                continue
            sid = int(segment_id_from_compact(obj))
            overrides[sid] = {
                "speed_limit_forward": seg["speed_limit_forward"],
                "speed_limit_reverse": seg["speed_limit_reverse"],
                "road_name": seg["road_name"],
                "road_type": seg["road_type"],
            }
    return overrides


def merge_overrides_into_location(loc: dict, overrides: dict[int, dict]) -> int:
    n = 0
    for seg in loc.get("segments") or []:
        if not isinstance(seg, dict):
            continue
        raw_sid = seg.get("segment_id")
        if raw_sid is None:
            continue
        sid = int(raw_sid)
        o = overrides.get(sid)
        if o is None:
            continue
        if o.get("speed_limit_forward") is not None:
            seg["speed_limit_forward"] = o["speed_limit_forward"]
        if o.get("speed_limit_reverse") is not None:
            seg["speed_limit_reverse"] = o["speed_limit_reverse"]
        if o.get("road_name") is not None and str(o["road_name"]):
            seg["road_name"] = o["road_name"]
        if o.get("road_type") is not None:
            seg["road_type"] = o["road_type"]
        n += 1
    return n


def write_location_gz(loc: dict, path: Path) -> int:
    raw = json.dumps(loc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    with gzip.open(path, "wb", mtime=0) as gz:
        gz.write(raw)
    return path.stat().st_size


def patch_regional_packs(
    packages: list[dict],
    community_id: str,
    overrides: dict[int, dict],
    base_url: str,
) -> None:
    if not overrides:
        print("No segment overrides in tiles — skipping regional pack merge.")
        return

    for pkg in packages:
        pid = pkg.get("id") or ""
        if pid == community_id:
            continue
        fn = pkg.get("filename") or ""
        if not fn.endswith(".json.gz"):
            continue
        seg_count = int(pkg.get("segmentCount") or 0)
        if seg_count <= 0:
            continue

        url = f"{base_url}/{fn}"
        try:
            blob = fetch_bytes(url)
            loc = json.loads(gzip.decompress(blob).decode("utf-8"))
        except urllib.error.HTTPError as e:
            print(f"warn: skip regional {fn}: HTTP {e.code}", file=sys.stderr)
            continue
        except Exception as e:
            print(f"warn: skip regional {fn}: {e}", file=sys.stderr)
            continue

        updated = merge_overrides_into_location(loc, overrides)
        if updated == 0:
            continue
        out_path = DIST_DIR / fn
        gz_size = write_location_gz(loc, out_path)
        pkg["fileSizeMB"] = round(gz_size / 1_048_576.0, 4)
        print(f"Patched {updated} segment(s) in {fn} ({gz_size} bytes)")


def main() -> int:
    manifest_url = os.environ.get("SOURCE_MANIFEST_URL", DEFAULT_MANIFEST_URL)
    merge_regionals = os.environ.get("MERGE_INTO_REGIONAL_PACKS", "1").strip() not in (
        "0",
        "false",
        "no",
    )
    pkg_id = os.environ.get("COMMUNITY_PACKAGE_ID", "community_map")
    pkg_name = os.environ.get("COMMUNITY_PACKAGE_NAME", "Community map")
    country = os.environ.get("COMMUNITY_COUNTRY", "CA")
    filename = os.environ.get("COMMUNITY_FILENAME", "community_map.json.gz")
    loc_id = os.environ.get("COMMUNITY_LOCATION_ID", pkg_id)

    manifest_path = TILES_DIR / "manifest.json"
    if not manifest_path.is_file():
        print("tiles/manifest.json not found — nothing to build.", file=sys.stderr)
        return 1

    with open(manifest_path, "r", encoding="utf-8") as f:
        tile_manifest = json.load(f)

    overrides = collect_segment_overrides() if merge_regionals else {}

    tile_keys = local_tile_keys()
    manifest_tile_count = len(tile_manifest.get("tiles") or {})
    if len(tile_keys) < manifest_tile_count:
        print(
            f"Processing {len(tile_keys)} local tile(s) "
            f"({manifest_tile_count - len(tile_keys)} hosted in R2 only)"
        )

    seen_ids: set[int] = set()
    segments: list[dict] = []
    for key in tile_keys:
        gz_path = TILES_DIR / f"{key}.json.gz"
        try:
            tile = load_json_gz(gz_path)
        except Exception as e:
            print(f"warn: skip {gz_path.name}: {e}", file=sys.stderr)
            continue
        for obj in tile.get("s") or []:
            if not isinstance(obj, dict):
                continue
            seg = compact_to_downloaded_segment(obj)
            if not seg:
                continue
            sid = seg["segment_id"]
            while sid in seen_ids:
                sid = (sid + 1) % (2**31 - 1) or 1
            seen_ids.add(sid)
            seg["segment_id"] = sid
            segments.append(seg)

    bounds = bounds_from_coords(segments)
    loc = {
        "id": loc_id,
        "name": pkg_name,
        "source": "dukesr8.space community editor",
        "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "bounds": bounds,
        "total_segments": len(segments),
        "segments": segments,
    }

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    pack_path = DIST_DIR / filename
    raw = json.dumps(loc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    with gzip.open(pack_path, "wb", mtime=0) as gz:
        gz.write(raw)

    gz_size = pack_path.stat().st_size
    file_size_mb = round(gz_size / 1_048_576.0, 4)

    try:
        release_manifest = fetch_release_manifest(manifest_url)
    except Exception as e:
        print(f"Failed to download release manifest from {manifest_url}: {e}", file=sys.stderr)
        return 1

    packages = [p for p in (release_manifest.get("packages") or []) if p.get("id") != pkg_id]
    pkg_entry = {
        "id": pkg_id,
        "name": pkg_name,
        "country": country,
        "filename": filename,
        "fileSizeMB": file_size_mb,
        "segmentCount": len(segments),
        "bounds": {
            "latMin": bounds["min_lat"],
            "latMax": bounds["max_lat"],
            "lonMin": bounds["min_lon"],
            "lonMax": bounds["max_lon"],
        },
    }
    packages.append(pkg_entry)

    if merge_regionals and overrides:
        base = release_assets_base(manifest_url)
        patch_regional_packs(packages, pkg_id, overrides, base)

    release_manifest["packages"] = packages
    release_manifest["totalPackages"] = len(packages)
    release_manifest["generated"] = loc["fetched_at"]
    release_manifest["version"] = int(release_manifest.get("version") or 1)

    out_manifest = DIST_DIR / "manifest.json"
    with open(out_manifest, "w", encoding="utf-8") as f:
        json.dump(release_manifest, f, indent=2)
        f.write("\n")

    print(f"Wrote {pack_path} ({gz_size} bytes, {len(segments)} segments)")
    print(f"Wrote {out_manifest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
