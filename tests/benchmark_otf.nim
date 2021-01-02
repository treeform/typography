import typography, benchy, common, strutils

let fontPaths = findAllFonts("tests/fonts")

for path in fontPaths:
  if path.endsWith("SourceSansPro.otf"):
    continue # Doesn't work for some reason
  timeIt path:
    let font = readFontOtf(path)
    for glyph in font.typeface.glyphArr:
      parseGlyph(glyph, font)
