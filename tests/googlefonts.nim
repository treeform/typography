## Loads google fonts and draws a text sample.

import algorithm, chroma, flippy, math, os, ospaths, print, sequtils, strutils,
    tables, typography, typography/sysfonts, vmath


var fontPaths: seq[string]

for fontPath in walkDirRec("/p/googlefonts/"):
  if fontPath.endsWith(".ttf"):
    fontPaths.add(fontPath)

fontPaths.sort()
fontPaths = fontPaths[0 .. 1000]

var image = newImage(1000, fontPaths.len*40, 4)

var mainFont = readFontTtf("fonts/Ubuntu.ttf")

for fontNum, fontPath in fontPaths:
  var font = readFontTtf(fontPath)
  echo font.name
  font.size = 20
  font.lineHeight = 40
  echo font.glyphs.len

  let y = fontNum.float32 * 40 + 10

  mainFont.size = 10
  mainFont.lineHeight = 40
  mainFont.drawText(image, vec2(10, y), fontPath.lastPathPart)

  try:
    font.drawText(
      image,
      vec2(300, y),
      "The quick brown fox jumps over the lazy dog! :)"
    )
  except:
    echo "error!"
    discard
image.alphaToBlankAndWhite()
image.save("googlefonts.png")


    # let
    #   width = 1000
    #   height = 100 * int(ceil(float(font.glyphs.len) / 10.0))

    # var ctx = newImage(width, height, 4)
    # ctx.fill(rgba(255, 255, 255, 255))
    # var x, y: int
    # var names = toSeq(font.glyphs.keys)
    # names.sort(cmp)
    # for i, name in names:

    #   if font.glyphs[name].isEmpty:
    #     ctx.fillRect(
    #       rect(
    #         float(x) + 20.0, float(y) + 20.0,
    #         float 20, float 20
    #       ),
    #       rgba(128, 128, 128, 255)
    #     )
    #   else:
    #     try:
    #       var img = font.getGlyphImage(name)
    #       #img.save("samples/letter" & $i & ".png")
    #       ctx.blitWithMask(
    #         img,
    #         rect(
    #           0, 0,
    #           float img.width, float img.height
    #         ),
    #         rect(
    #           float(x) + 20.0, float(y) + 20.0,
    #           float img.width, float img.height
    #         ),
    #         rgba(0, 0, 0, 255)
    #       )
    #     except:
    #       echo "error on: ", i
    #       ctx.fillRect(
    #         rect(
    #           float(x) + 20.0, float(y) + 20.0,
    #           float 20, float 20
    #         ),
    #         rgba(255, 0, 0, 255)
    #       )

    #   x += 100
    #   if x >= 1000:
    #     x = 0
    #     y += 100
    # ctx.save("samples/" & name & ".png")
