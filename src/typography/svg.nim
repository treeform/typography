import xmlparser, xmltree, tables, streams, os, strutils
import vmath
import font


proc readFontSvg*(filename: string): Font =
  ## Reads an SVG font
  if not fileExists(filename):
    raise newException(OSError, "File " & filename & " not found")

  var font: Font
  font.size = 16
  font.lineHeight = 20
  font.filename = filename
  font.glyphs = initTable[string, Glyph]()


  var xml = parseXml(newFileStream(filename))

  for tag in xml.findAll "font":
    var name = tag.attr "id"
    if name.len > 0:
      font.name = name
    var advance = tag.attr "horiz-adv-x"
    if advance.len > 0:
      font.advance = parseFloat(advance)

  for tag in xml.findAll "font-face":
    var bbox = tag.attr "bbox"
    if bbox.len > 0:
      var v = bbox.split()
      font.bboxMin = vec2(parseFloat(v[0]), parseFloat(v[1]))
      font.bboxMax = vec2(parseFloat(v[2]), parseFloat(v[3]))
    var capHeight = tag.attr "cap-height"
    if capHeight.len > 0:
      font.capHeight = parseFloat(capHeight)
    var xHeight = tag.attr "x-height"
    if xHeight.len > 0:
      font.xHeight = parseFloat(xHeight)
    var ascent = tag.attr "ascent"
    if ascent.len > 0:
      font.ascent = parseFloat(ascent)
    var descent = tag.attr "descent"
    if descent.len > 0:
      font.descent = parseFloat(descent)

  for tag in xml.findAll "glyph":
    var glyph: Glyph
    glyph.code = tag.attr "unicode"
    glyph.name = tag.attr "glyph-name"
    var advance = tag.attr "horiz-adv-x"
    if advance.len > 0:
      glyph.advance = parseFloat(advance)
    else:
      glyph.advance = font.advance
    glyph.path = tag.attr "d"
    if glyph.name == "space" and glyph.code == "":
      glyph.code = " "
    font.glyphs[glyph.code] = glyph

  font.kerning = initTable[string, float]()
  for tag in xml.findAll "hkern":
    var k = parseFloat tag.attr "k"
    var u1 = tag.attr "u1"
    var u2 = tag.attr "u2"
    if u1.len > 0 and u2.len > 0:
      font.kerning[u1 & ":" & u2] = k

  return font