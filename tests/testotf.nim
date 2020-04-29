import chroma, flippy, print, tables, typography, typography, vmath

block:
  #var font = readFontOtf("fonts/Changa-Bold.ttf")
  #var font = readFontOtf("fonts/Ubuntu.ttf")
  var font = readFontOtf("fonts/hanazono/HanaMinA.ttf")
  font.size = 20
  font.lineHeight = 40
  print font.unitsPerEm
  print font.ascent
  print font.descent
  print font.lineGap

  var image = newImage(500, 40, 4)

  font.drawText(
    image,
    vec2(10, 0),
    """!!! The "quick" brown fox jumps over the lazy dog. !!!"""
  )

  image.alphaToBlankAndWhite()
  image.save("testotf.png")

  echo "saved"
