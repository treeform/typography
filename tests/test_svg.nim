import pixie, print, tables, typography, typography, vmath, os, osproc,
  typography/svgfont

setCurrentDir(getCurrentDir() / "tests")

block:
  var font = readFontSvg("fonts/Changa-Bold.svg")

  font.size = 40
  font.lineHeight = 40
  print font.typeface.unitsPerEm
  #font.unitsPerEm = 2000
  print font.typeface.ascent
  print font.typeface.descent
  print font.typeface.lineGap

  #echo pretty %font.otf.os2
  #for glyph in font.glyphArr:
  #  print glyph.code, glyph.advance

  var image = newImage(500, 40)

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
  image.writeFile("rendered/test_svg.png")

  echo "saved"

let (outp, _) = execCmdEx("git diff tests/rendered/*.png")
if len(outp) != 0:
  echo outp
  quit("Output does not match")
