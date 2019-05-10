## Loads ttf system fonts and prodces a grid of their glphys

import strutils, tables, ospaths, math, sequtils, algorithm, os
import flippy, vmath, chroma, print
import typography, typography/sysfonts


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


for fontPath in getSystemFonts():
  if fontPath.endsWith(".ttf"):
    echo fontPath

    let (dir, name, ext) = fontPath.splitFile()
    if fileExists("samples/" & name & ".png"):
      continue

    var font = readFontTtf(fontPath)
    echo font.name
    font.size = 20
    echo font.glyphs.len

    let
      width = 1000
      height = 100 * int(ceil(float(font.glyphs.len) / 10.0))

    var ctx = newImage(width, height, 4)
    ctx.fill(rgba(255, 255, 255, 255))
    var x, y: int
    var names = toSeq(font.glyphs.keys)
    names.sort(cmp)
    for name in names:
      try:
        var img = font.getGlyphImage(name)
        ctx.blitWithMask(
          img,
          rect(
            0, 0,
            float img.width, float img.height
          ),
          rect(
            float(x) + 20.0, float(y) + 20.0,
            float img.width, float img.height
          ),
          rgba(0,0,0,255)
        )
        x += 100
        if x >= 1000:
          x = 0
          y += 100
      except:
        echo "error on: ", repr(name)
        break
    ctx.save("samples/" & name & ".png")