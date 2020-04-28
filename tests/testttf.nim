import chroma, flippy, print, tables, typography, vmath

block:
  var font = readFontTtf("fonts/Changa-Bold.ttf")
  font.size = 30
  font.lineHeight = 40

  var image = newImage(500, 40, 4)

  font.drawText(
    image,
    vec2(10, 10),
    "!!! The quick brown fox jumps over the lazy dog. !!!"
  )

  image.alphaToBlankAndWhite()
  image.save("testttf.png")

  echo "saved"
