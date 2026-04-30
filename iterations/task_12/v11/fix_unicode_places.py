#!/usr/bin/env python3
"""
Repair USGS place names that contain literal '?' substitutions for non-ASCII
characters by cross-referencing GeoNames cities500 (UTF-8) and matching by
country + ascii_name regex + nearest lat/lng to the event.

Inputs:
  - /tmp/geonames/cities500.txt
  - interactive/task_12/src/data/quakes.csv

Outputs:
  - interactive/task_12/src/data/quakes.csv (overwritten with UTF-8 names)
  - iterations/task_12/v11/place_corrections.json (audit trail)
  - iterations/task_12/v11/unmatched.txt (diagnostic — names we could not fix)
"""

import csv
import json
import math
import re
import sys
from pathlib import Path
from collections import defaultdict

ROOT = Path("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")
GEONAMES = Path("/tmp/geonames/cities500.txt")
QUAKES = ROOT / "interactive/task_12/src/data/quakes.csv"
RAW_QUAKES = ROOT / "data/task_12/usgs_quakes_1980_2025_m5.csv"
AUDIT_DIR = ROOT / "iterations/task_12/v11"

# USGS country/region label → ISO2 country code.
# Covers all unique trailing tokens observed in our broken-place set.
COUNTRY_TO_ISO = {
    "Iran": "IR",
    "India": "IN",
    "Iraq": "IQ",
    "Turkey": "TR",
    "Japan": "JP",
    "Afghanistan": "AF",
    "Pakistan": "PK",
    "Bangladesh": "BD",
    "Nepal": "NP",
    "Yemen": "YE",
    "Saudi Arabia": "SA",
    "Oman": "OM",
    "Egypt": "EG",
    "Libya": "LY",
    "Sudan": "SD",
    "Ethiopia": "ET",
    "Eritrea": "ER",
    "Tonga": "TO",
    "Samoa": "WS",
    "American Samoa": "AS",
    "North Macedonia": "MK",
    "Romania": "RO",
    "Croatia": "HR",
    "Slovenia": "SI",
    "Bosnia and Herzegovina": "BA",
    "Serbia": "RS",
    "Greece": "GR",
    "Cyprus": "CY",
    "Poland": "PL",
    "Russia": "RU",
    "Vietnam": "VN",
    "Myanmar": "MM",
    "Spain": "ES",
    "Argentina": "AR",
    "Chile": "CL",
    "Mexico": "MX",
    "Hawaii": "US",  # USGS labels Hawaii events with "Hawaii" not "USA"
    "Israel": "IL",
    "Malta": "MT",
    "Azerbaijan": "AZ",
    "Kazakhstan": "KZ",
    "North Korea": "KP",
    "South Korea": "KR",
    "Turkmenistan": "TM",
    "Uzbekistan": "UZ",
    "Kyrgyzstan": "KG",
    "Tajikistan": "TJ",
    "Lebanon": "LB",
    "Syria": "SY",
    "Algeria": "DZ",
    "Tunisia": "TN",
    "Morocco": "MA",
    "Albania": "AL",
    "Bulgaria": "BG",
    "Hungary": "HU",
    "Czech Republic": "CZ",
    "Slovakia": "SK",
    "Ukraine": "UA",
    "Belarus": "BY",
    "Georgia": "GE",
    "Armenia": "AM",
    "Mongolia": "MN",
    "China": "CN",
    "Taiwan": "TW",
    "Indonesia": "ID",
    "Philippines": "PH",
    "Thailand": "TH",
    "Laos": "LA",
    "Cambodia": "KH",
    "Malaysia": "MY",
    "Bhutan": "BT",
    "Sri Lanka": "LK",
    "Maldives": "MV",
    "Brazil": "BR",
    "Peru": "PE",
    "Colombia": "CO",
    "Ecuador": "EC",
    "Venezuela": "VE",
    "Bolivia": "BO",
    "Paraguay": "PY",
    "Uruguay": "UY",
}

# Country names sometimes appear inside region phrases (e.g. "Nicobar Islands,
# India region"). Map those tail tokens explicitly.
REGION_TAIL_TO_ISO = {
    "India region": "IN",
    "Iran region": "IR",
    "Pakistan region": "PK",
}


def country_iso(country_token: str) -> str | None:
    if country_token in COUNTRY_TO_ISO:
        return COUNTRY_TO_ISO[country_token]
    if country_token in REGION_TAIL_TO_ISO:
        return REGION_TAIL_TO_ISO[country_token]
    return None


# Manual overrides for cases the GeoNames matcher cannot resolve cleanly.
# Keyed by the broken city token (not the whole place string).
# Reason: "As Sulaymānīyah" lives in GeoNames as the primary "Sulaymaniyah" (no
# "As " prefix); none of its alternates carry the "As " prefix verbatim either,
# so the regex can't match. This is the only such case in our data.
MANUAL_CITY_OVERRIDES = {
    "As Sulaym?n?yah": "As Sulaymānīyah",
}


# Index GeoNames by (iso, ascii_name) → list of {name, lat, lon, alt_names}
def load_geonames():
    by_country = defaultdict(list)
    with GEONAMES.open(encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 9:
                continue
            utf8 = parts[1]
            ascii_name = parts[2]
            try:
                lat = float(parts[4])
                lon = float(parts[5])
            except ValueError:
                continue
            iso = parts[8]
            alt = parts[3]
            by_country[iso].append({
                "utf8": utf8,
                "ascii": ascii_name,
                "lat": lat,
                "lon": lon,
                "alt": alt,
            })
    return by_country


# Parse a USGS place string into (offset_prefix, city, country_token).
# - "79 km ESE of Kh?sh, Iran" → ("79 km ESE of ", "Kh?sh", "Iran")
# - "?alabja, Iraq"           → ("",                  "?alabja", "Iraq")
# - "Nicobar Islands, India region" → ("", "Nicobar Islands", "India region")
OFFSET_RE = re.compile(r"^(\d+ km [NSEW]+ of )(.*)$")


def parse_place(place: str):
    m = OFFSET_RE.match(place)
    if m:
        prefix, rest = m.group(1), m.group(2)
    else:
        prefix, rest = "", place
    if "," not in rest:
        return prefix, rest, None
    city, _, country = rest.rpartition(", ")
    return prefix, city.strip(), country.strip()


def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def build_pattern(broken_city: str) -> re.Pattern:
    """Convert a broken city name to a regex pattern: '?' → '.', escape rest."""
    # Escape regex specials, then unescape the literal \? back to '.'
    escaped = re.escape(broken_city)
    pattern = escaped.replace(r"\?", ".")
    return re.compile(f"^{pattern}$", re.IGNORECASE)


def match_one(broken_city: str, country_token: str | None,
              event_lat: float, event_lon: float,
              by_country) -> str | None:
    """
    Find the GeoNames entry whose ascii_name matches the broken city pattern,
    is in the right country, and is closest to the event lat/lng.
    Returns the UTF-8 name, or None if no confident match.
    """
    if "?" not in broken_city:
        return broken_city  # already clean

    if broken_city in MANUAL_CITY_OVERRIDES:
        return MANUAL_CITY_OVERRIDES[broken_city]

    iso = country_iso(country_token) if country_token else None
    pat = build_pattern(broken_city)

    def matched_name(c):
        """Return the best UTF-8 form of the name from c that matches `pat`,
        or None if no field matches.
        Preference order:
          1. utf8 (primary)  — keeps the city's canonical name
          2. ascii (also returns utf8)  — same city, unambiguous match
          3. alternates  — returns the matching alternate verbatim
        """
        if pat.match(c["utf8"]):
            return c["utf8"]
        if pat.match(c["ascii"]):
            return c["utf8"]
        for alt in c["alt"].split(","):
            alt = alt.strip()
            if alt and pat.match(alt):
                return alt
        return None

    candidates = []  # list of (city, name_to_use) tuples
    if iso and iso in by_country:
        for c in by_country[iso]:
            name = matched_name(c)
            if name:
                candidates.append((c, name))
    # Fallback: search all countries — only if name is distinctive enough
    if not candidates and len(broken_city) >= 5:
        for cs in by_country.values():
            for c in cs:
                name = matched_name(c)
                if name:
                    candidates.append((c, name))
    if not candidates:
        return None

    # Pick the closest by haversine distance to the event.
    best_c, best_name = min(
        candidates,
        key=lambda cn: haversine(event_lat, event_lon, cn[0]["lat"], cn[0]["lon"]),
    )
    # Require it to be reasonably close — within 500 km. USGS picks the nearest
    # named locality, so if the closest match is far, it's probably the wrong one.
    dist_km = haversine(event_lat, event_lon, best_c["lat"], best_c["lon"])
    if dist_km > 500:
        return None
    return best_name


def main():
    print("Loading GeoNames...", file=sys.stderr)
    by_country = load_geonames()
    print(f"  loaded {sum(len(v) for v in by_country.values()):,} cities across {len(by_country)} countries",
          file=sys.stderr)

    # First pass: collect all unique (broken_city, country, lat, lon) → fix decisions.
    # We process each row of the CSV. If the same broken city in the same
    # country appears for multiple events, each gets its own nearest-city
    # lookup, so they may resolve differently in edge cases — that's correct.
    rows = []
    fixed_count = 0
    unfixed_count = 0
    place_corrections = {}  # broken_place_string → fixed_place_string (for audit)
    unmatched = []

    print(f"Processing {QUAKES}...", file=sys.stderr)
    with QUAKES.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            place = row.get("place", "")
            if "?" in place:
                prefix, city, country = parse_place(place)
                try:
                    lat = float(row["latitude"])
                    lon = float(row["longitude"])
                except (TypeError, ValueError, KeyError):
                    rows.append(row)
                    unfixed_count += 1
                    continue
                fixed_city = match_one(city, country, lat, lon, by_country)
                if fixed_city and fixed_city != city:
                    new_place = f"{prefix}{fixed_city}, {country}" if country else f"{prefix}{fixed_city}"
                    row["place"] = new_place
                    place_corrections[place] = new_place
                    fixed_count += 1
                elif "?" in (fixed_city or city):
                    unfixed_count += 1
                    if place not in place_corrections:
                        unmatched.append(place)
                else:
                    # No improvement; keep as-is.
                    unfixed_count += 1
                    if place not in place_corrections:
                        unmatched.append(place)
            rows.append(row)

    print(f"  fixed: {fixed_count:,}    still has '?': {unfixed_count:,}", file=sys.stderr)

    # Write back the CSV
    with QUAKES.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    # Audit trail
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    with (AUDIT_DIR / "place_corrections.json").open("w", encoding="utf-8") as f:
        json.dump(place_corrections, f, ensure_ascii=False, indent=2, sort_keys=True)
    with (AUDIT_DIR / "unmatched.txt").open("w", encoding="utf-8") as f:
        for p in sorted(set(unmatched)):
            f.write(p + "\n")

    print(f"Wrote {QUAKES}", file=sys.stderr)
    print(f"Audit: {AUDIT_DIR / 'place_corrections.json'} ({len(place_corrections)} unique fixes)", file=sys.stderr)
    print(f"Audit: {AUDIT_DIR / 'unmatched.txt'} ({len(set(unmatched))} unique unmatched)", file=sys.stderr)


if __name__ == "__main__":
    main()
