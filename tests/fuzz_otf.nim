import os, strutils, algorithm, random, strformat

include typography/opentype/parser

randomize()

var fontPaths: seq[string]
for fontPath in walkDirRec("tests/fonts"):
  if fontPath.endsWith(".ttf") or fontPath.endsWith(".otf"):
    fontPaths.add(fontPath)
fontPaths.sort()

for i in 0 ..< 10000:
  var
    file = fontPaths[rand(fontPaths.len - 1)]
    data = readFile(file)
    pos = rand(data.len)
    value = rand(255).char
  data[pos] = value
  echo &"{i} {file} {pos} {value.uint8}"
  try:
    let font = parseOtf(data)
    doAssert font != nil
    for glyph in font.typeface.glyphArr:
      parseGlyph(glyph, font)
  except TypographyError:
    discard

  data = data[0 ..< pos]
  try:
    let font = parseOtf(data)
    doAssert font != nil
    for glyph in font.typeface.glyphArr:
      parseGlyph(glyph, font)
  except TypographyError:
    discard
