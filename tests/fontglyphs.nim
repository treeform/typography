## Loads ttf system fonts and prodces a grid of their glphys

import algorithm, chroma, pixie, math, os, ospaths, print, sequtils, strutils,
    tables, typography, typography/systemfonts, vmath

proc alphaWhite(image: var Image) =
  ## Typography deals mostly with transperant images with white text
  ## This is hard to see in tests so we convert it to white background
  ## with black text.
  for x in 0..<image.width:
    for y in 0..<image.height:
      var c = image[x, y]
      c.r = uint8(255) - c.a
      c.g = uint8(255) - c.a
      c.b = uint8(255) - c.a
      c.a = 255
      image[x, y] = c

for fontPath in getSystemFonts():
  if fontPath.endsWith(".ttf"):
    echo fontPath

    let (dir, name, ext) = fontPath.splitFile()
    # if fileExists("samples/" & name & ".png"):
    #   continue

    var font = readFontTtf(fontPath)
    echo font.typeface.name
    font.size = 30
    echo font.typeface.glyphs.len

    let
      width = 1000
      height = 100 * int(ceil(float(font.typeface.glyphs.len) / 10.0))

    var ctx = newImage(width, height)
    ctx.fill(rgba(255, 255, 255, 255))
    let context = newContext(ctx)
    var x, y: int
    var names = toSeq(font.typeface.glyphs.keys)
    names.sort(cmp)
    for i, name in names:

      if font.typeface.glyphs[name].isEmpty:
        context.fillStyle = rgba(128, 128, 128, 255)
        context.fillRect(float(x) + 20, float(y) + 20, 20, 20)
      else:
        try:
          var img = font.getGlyphImage(name)
          for color in img.data.mitems:
            color.r = 0
            color.g = 0
            color.b = 0
          ctx.draw(img, translate(vec2(float(x) + 20, float(y) + 20)))
        except:
          echo "error on: ", i
          context.fillStyle = rgba(255, 0, 0, 255)
          context.fillRect(float(x) + 20, float(y) + 20, 20, 20)

      x += 100
      if x >= 1000:
        x = 0
        y += 100
    ctx.writeFile("samples/" & name & ".png")
