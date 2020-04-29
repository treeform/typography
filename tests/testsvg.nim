import chroma, flippy, print, tables, typography, typography, vmath, json

block:
  var font = readFontSvg("fonts/Changa-Bold.svg")

  font.size = 40
  font.lineHeight = 40
  print font.unitsPerEm
  #font.unitsPerEm = 2000
  print font.ascent
  print font.descent
  print font.lineGap

  #echo pretty %font.otf.os2
  #for glyph in font.glyphArr:
  #  print glyph.code, glyph.advance

  var image = newImage(500, 40, 4)

  var text = """+Welcome, Earthling."""
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
  image.save("testsvg.png")

  echo "saved"
