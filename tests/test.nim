import tables
import flippy, vmath, chroma, print
import typography


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
  var image = newImage(500, 40, 4)
  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 16

  font.drawText(image, vec2(10, 10), "The quick brown fox jumps over the lazy dog.")

  image.alphaWhite()
  image.save("basicSvg.png")

block:
  var font = readFontTtf("fonts/Ubuntu.ttf")
  font.size = 16
  var image = newImage(500, 40, 4)

  font.drawText(image, vec2(10, 10), "The quick brown fox jumps over the lazy dog.")

  image.alphaWhite()
  image.save("basicTtf.png")

block:
  var font = readFontSvg("fonts/Ubuntu.svg")
  var image = newImage(500, 240, 4)

  font.size = 8
  font.drawText(image, vec2(10, 10), "The quick brown fox jumps over the lazy dog.")
  font.size = 10
  font.drawText(image, vec2(10, 25), "The quick brown fox jumps over the lazy dog.")
  font.size = 14
  font.drawText(image, vec2(10, 45), "The quick brown fox jumps over the lazy dog.")
  font.size = 22
  font.drawText(image, vec2(10, 75), "The quick brown fox jumps over the lazy dog.")
  font.size = 36
  font.drawText(image, vec2(10, 110), "The quick brown fox jumps over the lazy dog.")
  font.size = 72
  font.drawText(image, vec2(10, 150), "The quick brown fox jumps over the lazy dog.")

  image.alphaWhite()
  image.save("sizes.png")


block:
  var image = newImage(800, 200, 4)
  var font = readFontSvg("fonts/DejaVuSans.svg")

  font.size = 16
  font.lineHeight = 20
  font.drawText(image, vec2(10, 10), readFile("sample.ru.txt"))

  image.alphaWhite()
  image.save("ru.png")


block:
  var image = newImage(250, 20, 4)


  var font = readFontSvg("fonts/DejaVuSans.svg")
  font.size = 11 # 11px or 8pt
  font.drawText(image, vec2(10, 4), "The quick brown fox jumps over the lazy dog.")

  image = image.magnify(4)
  image.alphaWhite()
  image.save("scaledup.png")


block:
  var image = newImage(140, 20, 4)

  var font = readFontSvg("fonts/DejaVuSans.svg")
  font.size = 11 # 11px or 8pt
  font.drawText(image, vec2(8, 4), "momomomomomomo")

  image = image.magnify(6)
  image.alphaWhite()
  image.save("subpixelpos.png")


block:
  var image = newImage(140, 20, 4)

  var font = readFontSvg("fonts/DejaVuSans.svg")
  font.size = 11 # 11px or 8pt
  var glyph = font.glyphs["g"]
  var under = font.glyphs["_"]

  for i in 0..<10:
    var glyphOffset: Vec2
    var at = vec2(12.0 + float(i)*12, 11)
    var glyphImage = font.getGlyphImage(glyph, glyphOffset, quality=4, subPixelShift=float(i)/10.0)
    image.blit(
      glyphImage,
      rect(0, 0, glyphImage.width, glyphImage.height),
      rect(int(at.x + glyphOffset.x), int(at.y + glyphOffset.y), glyphImage.width, glyphImage.height)
    )


  image = image.magnify(6)
  for i in 0..<10:
    let at = vec2(12.0 + float(i)*12, 15) * 6
    font.drawText(image, at + vec2(0, 6), "+0." & $i)

  image.alphaWhite()

  let red = rgba(255, 0, 0, 255)
  for i in 0..<10:
    let at = vec2(12.0 + float(i)*12, 15) * 6
    image.line(at, at + vec2(7*6, 0), red)
    image.line(at + vec2(7*6, 0), at + vec2(7*6, -13*6), red)
    image.line(at + vec2(0, -13*6), at + vec2(7*6, -13*6), red)
    image.line(at + vec2(0, -13*6), at, red)


  image.save("subpixelglyphs.png")

