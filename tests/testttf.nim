import chroma, flippy, print, tables, typography, vmath

proc alphaWhite(image: var Image) =
  ## Typography deals mostly with transperant images with white text
  ## This is hard to see in tests so we convert it to white background
  ## with black text.
  for x in 0..<image.width:
    for y in 0..<image.height:
      var c = image.getrgba(x, y)
      c.r = uint8(255) - c.a
      c.g = uint8(255) - c.a
      c.b = uint8(255) - c.a
      c.a = 255
      image.putrgba(x, y, c)

block:
  var font = readFontTtf("fonts/Ubuntu.ttf")
  font.size = 16

  var image = newImage(500, 40, 4)

  font.drawText(image, vec2(10, 10), "The quick brown fox jumps over the lazy dog.")

  image.alphaWhite()
  image.save("basicTtf.png")

  echo "saved"
