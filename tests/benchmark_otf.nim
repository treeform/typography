import typography, benchy

timeIt "readFontOtf":
  let font = readFontOtf("tests/fonts/Ubuntu.ttf")
  for glyph in font.typeface.glyphArr:
    parseGlyph(glyph, font)
