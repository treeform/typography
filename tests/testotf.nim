import chroma, flippy, print, tables, typography, typography, vmath, json

block:
  var font = readFontOtf("fonts/Changa-Bold.ttf")
  #var font = readFontOtf("fonts/Ubuntu.ttf")
  #var font = readFontOtf("fonts/hanazono/HanaMinA.ttf")
  #var font = readFontOtf("/p/googlefonts/apache/jsmathcmbx10/jsMath-cmbx10.ttf")
  #var font = readFontOtf("/p/googlefonts/apache/nokora/Nokora-Bold.ttf")
  #var font = readFontOtf("/p/googlefonts/ofl/arvo/Arvo-Regular.ttf") # zero sides path
  #var font = readFontOtf("/p/googlefonts/ofl/chelseamarket/ChelseaMarket-Regular.ttf") # negative sided image
  font.size = 20
  font.lineHeight = 40
  print font.unitsPerEm
  #font.unitsPerEm = 2000
  print font.ascent
  print font.descent
  print font.lineGap

  echo pretty %font.otf.os2
  #for glyph in font.glyphArr:
  #  print glyph.code, glyph.advance

  var image = newImage(500, 40, 4)

  var text = """!!! The "quick" brown fox jumps over the lazy dog. !!!"""
  if "q" notin font.glyphs:
    # can't display english, use random glpyhs:
    text = ""
    var i = 0
    for g in font.glyphs.values:
      text.add(g.code)
      inc i
      if i > 80:
        break

  font.drawText(
    image,
    vec2(10, 0),
    text
  )

  image.alphaToBlankAndWhite()
  image.save("testotf.png")

  echo "saved"
