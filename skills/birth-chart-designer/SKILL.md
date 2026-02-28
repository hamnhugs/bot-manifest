---
name: birth-chart-designer
description: "Generate beautiful multi-page natal birth chart PDFs from chart data. Use when a user provides a birth chart (text file, structured data, or birth details) and wants a professionally designed infographic PDF. Produces a 5-page PDF — Page 1 is a full visual poster (zodiac wheel, Big Three cards, planet table, elemental bars, key aspects, synthesis) and Pages 2-5 contain full interpretive text (planetary interpretations, all 12 houses, all aspects, nodal axis, Chiron, synthesis). Output is commercial-grade, print-ready quality."
---

# Birth Chart Designer

Generates a multi-page PDF birth chart — visual poster + full interpretive text pages.

## Workflow

### 1. Get Chart Data
Input can be:
- **Structured text file** (like the Swiss Ephemeris format we use) — parse it
- **Raw birth details** (name, DOB, time, place) — generate chart data using astrological calculations
- **JSON chart_data** — pass directly to script

### 2. Build chart_data.json
Extract/construct the JSON schema below and save to `/tmp/chart_data.json`.

### 3. Run the script
```bash
python3 ~/.openclaw/workspace/skills/birth-chart-designer/scripts/generate_chart_pdf.py \
  /tmp/chart_data.json /tmp/output_chart.pdf
```

### 4. Send the PDF
```python
message(action="send", channel="telegram", media="/tmp/output_chart.pdf", caption="...")
```

---

## chart_data.json Schema

```json
{
  "name": "Full Name",
  "birth_date": "Month DD, YYYY",
  "birth_time": "HH:MM AM/PM",
  "birth_place": "City, State/Country",
  "ascendant": "Sign Degree",
  "midheaven": "Sign Degree",

  "big_three": {
    "sun":    { "sign": "Capricorn", "degree": "6°16'", "house": "4th",
                "interpretation": ["Para 1...", "Para 2..."], "note": "House note..." },
    "moon":   { "sign": "Scorpio",   "degree": "26°31'", "house": "2nd",
                "interpretation": ["Para 1...", "Para 2..."], "note": "..." },
    "rising": { "sign": "Libra",     "degree": "5°15'", "house": "1st",
                "interpretation": ["Para 1...", "Para 2..."], "note": "..." }
  },

  "planets": [
    {
      "symbol": "☉", "name": "Sun", "sign": "Capricorn",
      "degree": "6°16'", "house": "4th",
      "ecliptic": 276.27,
      "r_pos": 0.44,
      "color": "GOLD",
      "interpretation": "Full interpretive paragraph..."
    }
  ],

  "house_cusps_ecliptic": [185.25, 212.4, 243.02, 275.82, 308.53, 338.8,
                            5.25,  32.4,  63.02,  95.82, 128.53, 158.8],

  "houses": [
    {
      "number": 1, "sign": "Libra", "degree": "5°15'",
      "description": "Full house interpretation including any planets here..."
    }
  ],

  "elements": { "fire": 0.30, "earth": 0.20, "air": 0.00, "water": 0.50 },
  "modalities": { "cardinal": 0.20, "fixed": 0.30, "mutable": 0.50 },

  "aspects": [
    {
      "type": "CONJUNCTION", "orb": "0.7°",
      "p1": "Sun", "p2": "Neptune",
      "description": "Identity and imagination fused...",
      "color": "GOLD",
      "featured": true
    }
  ],

  "aspect_lines": [
    [276.27, 275.53],
    [236.52, 230.90]
  ],

  "nodal_axis": {
    "north_node": {
      "sign": "Aries", "house": "7th", "degree": "17°27'",
      "summary": "One-line summary for poster...",
      "interpretation": ["Para 1...", "Para 2..."],
      "note": "House context..."
    },
    "south_node": {
      "sign": "Libra", "house": "1st", "degree": "17°27'",
      "summary": "One-line summary...",
      "interpretation": ["Para 1...", "Para 2..."]
    }
  },

  "chiron": {
    "sign": "Gemini", "house": "9th", "degree": "17°34'",
    "retrograde": true,
    "summary": "One-line for poster...",
    "interpretation": ["Para 1...", "Para 2..."],
    "note": "House context..."
  },

  "synthesis": {
    "portrait_lines": [
      "Line 1 of portrait paragraph (each string = one rendered line on poster)",
      "Line 2..."
    ],
    "threads": [
      {
        "title": "SUN ☉ conjunct NEPTUNE ♆  (0.7°)",
        "body1": "First line of interpretation",
        "body2": "Second line",
        "color": "GOLD"
      }
    ],
    "pull_quote": "The one-liner that defines the chart.",
    "full_text": ["Full synthesis paragraph 1...", "Para 2..."]
  }
}
```

---

## Planet Ecliptic Degrees Reference

Convert sign + degree to ecliptic:
- Aries 0° = 0°, Taurus 0° = 30°, Gemini 0° = 60°, Cancer 0° = 90°
- Leo 0° = 120°, Virgo 0° = 150°, Libra 0° = 180°, Scorpio 0° = 210°
- Sagittarius 0° = 240°, Capricorn 0° = 270°, Aquarius 0° = 300°, Pisces 0° = 330°

Example: Scorpio 26°31' = 210 + 26.52 = **236.52**

## Planet Symbols

☉ Sun · ☽ Moon · ☿ Mercury · ♀ Venus · ♂ Mars · ♃ Jupiter
♄ Saturn · ⛢ Uranus · ♆ Neptune · ♇ Pluto · ☊ North Node · ⚷ Chiron

## Color Names
GOLD · WINE · LAV (lavender) · FIRE · EARTH · AIR · WATER · MID · DARK · GRAY

## r_pos (radial position on wheel — avoid overlap)
Default ~0.42. Stagger nearby planets: 0.30–0.57 range.

## Notes
- `featured: true` on up to 8 aspects → shown on poster
- `portrait_lines` should be ~6 lines of ~90 chars each for poster layout
- `threads` should have 3 entries for poster layout
- All `interpretation` fields used in text pages only (not poster)
- Script auto-installs matplotlib, pillow, img2pdf if missing
