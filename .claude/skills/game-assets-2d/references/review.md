# Self-review checklist

Render a contact sheet with the new asset at real display size and at 4×, next to the
anchor assets, on both a light and a dark background (`contact_sheet.py` does this).
Read the image and answer every question honestly. Any "no" → fix before registering.

## Readability
- [ ] At the smallest real display size, can you tell what it is within a second?
- [ ] Is the silhouette distinct from the other assets in its set (no two icons that
      read the same at small size)?
- [ ] Does it work on both backgrounds it will appear on?

## Consistency
- [ ] Same stroke width, corner radius and outline color as the anchors?
- [ ] Same light direction and shading model?
- [ ] Same visual weight (not noticeably bolder/busier/emptier than its neighbors)?
- [ ] `check_palette.py` passes – only palette colors?
- [ ] Same perspective (front/top/isometric) as the set?

## Technical
- [ ] Nothing clipped at the edges; consistent padding inside the canvas?
- [ ] Correct size, format, naming and density set for the target?
- [ ] Pixel art: no anti-aliased pixels, no stray single pixels, integer scale?
- [ ] Textures: no visible seams in the 2×2 tile preview?
- [ ] Transparency where expected, no background box?

## Purpose
- [ ] Does it communicate its gameplay meaning (a "danger" icon looks dangerous, a
      "gold" resource looks valuable)?
- [ ] For tone (silly, serious, historical): does it fit the profile summary?

## When it keeps failing
After 3 iterations: simplify. Remove details, reduce colors, enlarge key shapes.
Unreadable small assets are almost always over-detailed, rarely under-detailed.
Log what failed in the manifest note so the next session knows.
