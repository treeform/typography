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

proc drawRect(image: var Image, at, wh: Vec2, color: ColorRGBA) =
  var wh = wh - vec2(1, 1) # line width
  image.line(at, at + vec2(wh.x, 0), color)
  image.line(at + vec2(wh.x, 0), at + vec2(wh.x, wh.y), color)
  image.line(at + vec2(0, wh.y), at + vec2(wh.x, wh.y), color)
  image.line(at + vec2(0, wh.y), at, color)

proc drawRect(image: var Image, rect: Rect, color: ColorRGBA) =
  image.drawRect(rect.xy, rect.wh, color)

block:
  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 100
  var image = font.getGlyphImage("h")
  image.alphaWhite()
  image.save("hFill.png")

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

  font.drawText(image, vec2(10, 10), "The \"quick\" brown fox jumps over the lazy dog.")

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
  var image = newImage(800, 200, 4)
  var font = readFontTtf("fonts/Ubuntu.ttf")

  font.size = 16
  font.lineHeight = 20
  font.drawText(image, vec2(10, 10), readFile("sample.txt"))

  image.alphaWhite()
  image.save("ttf.png")

# block:
#   var image = newImage(800, 200, 4)
#   var font = readFontOtf("fonts/Ubuntu.ttf")

#   font.size = 16
#   font.lineHeight = 20
#   font.drawText(image, vec2(10, 10), readFile("sample.txt"))

#   image.alphaWhite()
#   image.save("otf.png")

block:
  var image = newImage(600, 620, 4)
  var font = readFontTtf("fonts/hanazono/HanaMinA.ttf")
  font.size = 16
  font.lineHeight = 20

  font.drawText(image, vec2(10, 10), readFile("sample.ch.txt"))

  image.alphaWhite()
  image.save("ch.png")

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
    var glyphImage = font.getGlyphImage(
      glyph, glyphOffset,
      quality = 4,
      subPixelShift = float(i)/10.0
    )
    image.blit(
      glyphImage,
      rect(0, 0, float glyphImage.width, float glyphImage.height),
      rect(
        at.x + glyphOffset.x,
        at.y + glyphOffset.y,
        float glyphImage.width,
        float glyphImage.height
      )
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

block:
  var font = readFontTtf("fonts/Moon Bold.otf")
  font.size = 300
  font.lineHeight = 300

  var image = font.getGlyphOutlineImage("Q")

  echo font.glyphs["Q"].path

  image.save("qOutLine.png")

  image = font.getGlyphImage("Q")
  image.alphaWhite()
  image.save("qFill.png")

block:
  var image = newImage(200, 100, 4)

  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 11 # 11px or 8pt
  font.lineHeight = 20

  # compute layout
  var layout = font.typeset("""
Two roads diverged in a yellow wood,
And sorry I could not travel both
And be one traveler, long I stood
And looked down one as far as I could
To where it bent in the undergrowth;""")

  echo "textBounds: ", layout.textBounds()

  # draw text at a layout
  image.drawText(layout)

  let mag = 3.0
  image = image.magnify(int mag)
  image.alphaWhite()

  # draw layout boxes
  for pos in layout:
    var font = pos.font
    if pos.character in font.glyphs:
      var glyph = font.glyphs[pos.character]
      var glyphOffset: Vec2
      let img = font.getGlyphImage(
        glyph,
        glyphOffset,
        subPixelShift = pos.subPixelShift
      )
      image.drawRect(
        (pos.rect.xy + glyphOffset) * mag,
        vec2(float img.width, float img.height) * mag,
        rgba(255, 0, 0, 255)
      )
  image.save("layout.png")

  image.fill(rgba(255, 255, 255, 255))
  # draw layout boxes only
  for pos in layout:
    var font = pos.font
    if pos.character in font.glyphs:
      var glyph = font.glyphs[pos.character]
      var glyphOffset: Vec2
      let img = font.getGlyphImage(glyph, glyphOffset,
          subPixelShift = pos.subPixelShift)
      image.drawRect(
        (pos.rect.xy + glyphOffset) * mag,
        vec2(float img.width, float img.height) * mag,
        rgba(255, 0, 0, 255)
      )
  image.save("layoutNoText.png")

block:
  var image = newImage(500, 200, 4)

  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 11 # 11px or 8pt
  font.lineHeight = 20

  image.drawText(
    font.typeset(
      "Left, Top",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Left,
      vAlign = Top
    )
  )
  image.drawText(
    font.typeset(
      "Left, Middle",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Left,
      vAlign = Middle
    )
  )
  image.drawText(
    font.typeset(
      "Left, Bottom",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Left,
      vAlign = Bottom
    )
  )

  image.drawText(
    font.typeset(
      "Center, Top",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Center,
      vAlign = Top
    )
  )
  image.drawText(
    font.typeset(
      "Center, Middle",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Center,
      vAlign = Middle
    )
  )
  image.drawText(
    font.typeset(
      "Center, Bottom",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Center,
      vAlign = Bottom
    )
  )

  image.drawText(
    font.typeset(
      "Right, Top",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Right,
      vAlign = Top
    )
  )
  image.drawText(
    font.typeset(
      "Right, Middle",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Right,
      vAlign = Middle
    )
  )
  image.drawText(
    font.typeset(
      "Right, Bottom",
      pos = vec2(20, 20),
      size = vec2(460, 160),
      hAlign = Right,
      vAlign = Bottom
    )
  )

  image.alphaWhite()

  image.drawRect(
    vec2(20, 20),
    vec2(460, 160),
    rgba(255, 0, 0, 255)
  )

  image.save("alignment.png")

block:
  var image = newImage(500, 200, 4)

  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 16
  font.lineHeight = 20

  image.drawText(font.typeset(
    readFile("sample.wrap.txt"),
    pos = vec2(100, 20),
    size = vec2(300, 160)
  ))

  image.alphaWhite()

  image.drawRect(
    vec2(100, 20),
    vec2(300, 160),
    rgba(255, 0, 0, 255)
  )

  image.save("wordwrap.png")

block:
  var image = newImage(500, 200, 4)

  var font = readFontTtf("fonts/hanazono/HanaMinA.ttf")
  font.size = 16
  font.lineHeight = 20

  image.drawText(font.typeset(
    readFile("sample.ch.txt"),
    pos = vec2(100, 20),
    size = vec2(300, 160)
  ))

  image.alphaWhite()

  image.drawRect(
    vec2(100, 20),
    vec2(300, 160),
    rgba(255, 0, 0, 255)
  )

  image.save("wordwrapch.png")

block:
  var image = newImage(300, 120, 4)

  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 16 # 11px or 8pt
  font.lineHeight = 20

  # compute layout
  var layout = font.typeset("""
Two roads diverged in a yellow wood,
And sorry I could not travel both
And be one traveler, long I stood
And looked down one as far as I could
To where it bent in the undergrowth;""",
  vec2(10, 10))

  # draw text at a layout
  image.drawText(layout)

  image.alphaWhite()

  let selectionRects = layout.getSelection(23, 120)
  # draw selection boxes
  for rect in selectionRects:
    image.drawRect(rect, rgba(255, 0, 0, 255))

  image.save("selection.png")

block:

  var image = newImage(300, 120, 4)

  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 16
  font.lineHeight = 20

  # compute layout
  var layout = font.typeset("""
Two roads diverged in a yellow wood,
And sorry I could not travel both
And be one traveler, long I stood
And looked down one as far as I could
To where it bent in the undergrowth;""",
  vec2(10, 10))

  # draw text at a layout
  image.drawText(layout)

  image.alphaWhite()

  let at = vec2(120, 52)
  let g = layout.pickGlyphAt(at)
  # draw g
  image.drawRect(rect(at, vec2(4, 4)), rgba(0, 0, 255, 255))
  image.drawRect(g.selectRect, rgba(255, 0, 0, 255))

  image.save("picking.png")

block:
  var image = newImage(500, 120, 4)

  var font = readFontSvg("fonts/Ubuntu.svg")
  font.size = 16
  font.lineHeight = 20

  # compute layout
  var layout = font.typeset(
    "name\tstate\tnumber\tcount\n" &
    "cat\tT\t3.14\t0\n" &
    "dog\tF\t2.11\t1\n" &
    "really loong cat\tG\t123.678\t2",
    vec2(10, 10),
    tabWidth = 100)

  # draw text at a layout
  image.drawText(layout)
  image.alphaWhite()
  image.save("tabs.png")
