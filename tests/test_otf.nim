import chroma, pixie, print, tables, typography, typography, vmath, json, os, osproc

setCurrentDir(getCurrentDir() / "tests")

block:
  var font = readFontOtf("fonts/Changa-Bold.ttf")
  #var font = readFontOtf("/p/googlefonts/ofl/changa/static/Changa-Regular.ttf")
  #var font = readFontOtf("fonts/Ubuntu.ttf")
  #var font = readFontOtf("fonts/hanazono/HanaMinA.ttf")
  #var font = readFontOtf("/p/googlefonts/apache/jsmathcmbx10/jsMath-cmbx10.ttf")
  #var font = readFontOtf("/p/googlefonts/apache/nokora/Nokora-Bold.ttf")
  #var font = readFontOtf("/p/googlefonts/ofl/arvo/Arvo-Regular.ttf") # zero sides path
  #var font = readFontOtf("/p/googlefonts/ofl/chelseamarket/ChelseaMarket-Regular.ttf") # negative sided image
  #var font = readFontOtf("/p/googlefonts/ofl/frijole/Frijole-Regular.ttf") # negative sized glyph

  font.size = 40
  font.lineHeight = 40
  print font.typeface.unitsPerEm
  #font.unitsPerEm = 2000
  print font.typeface.ascent
  print font.typeface.descent
  print font.typeface.lineGap

  echo pretty %font.typeface.otf.os2
  #for glyph in font.glyphArr:
  #  print glyph.code, glyph.advance

  var image = newImage(500, 40)
  image.strokeSegment(segment(vec2(0, font.capline) + vec2(0, 0.25), vec2(500, font.capline) + vec2(0, 0.25)), rgba(0,0,0,255))
  image.strokeSegment(segment(vec2(0, font.baseline) + vec2(0, 0.25), vec2(500, font.baseline) + vec2(0, 0.25)), rgba(0,0,0,255))

  var text = """+Welcome, Earthling."""
  if "q" notin font.typeface.glyphs:
    # can't display english, use random glpyhs:
    text = ""
    var i = 0
    for g in font.typeface.glyphs.values:
      text.add(g.code)
      inc i
      if i > 80:
        break

  font.drawText(
    image,
    vec2(10, 0),
    text
  )

  image.alphaToBlackAndWhite()
  image.writeFile("rendered/test_otf.png")

  echo "saved"

let (outp, _) = execCmdEx("git diff tests/rendered/*.png")
if len(outp) != 0:
  echo outp
  quit("Output does not match")
