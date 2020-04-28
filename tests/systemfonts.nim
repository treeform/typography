## Loads google fonts and draws a text sample.

import algorithm, chroma, flippy, math, os, ospaths, print, sequtils, strutils,
    tables, typography, typography/sysfonts, vmath

var fontPaths: seq[string]

for fontPath in getSystemFonts():
  if fontPath.endsWith(".ttf"):
    fontPaths.add(fontPath)

fontPaths.sort()

var image = newImage(1000, fontPaths.len*40, 4)

var mainFont = readFontTtf("fonts/Ubuntu.ttf")

for fontNum, fontPath in fontPaths:

  let y = fontNum.float32 * 40 + 10

  mainFont.size = 10
  mainFont.lineHeight = 40
  mainFont.drawText(image, vec2(10, y), fontPath.lastPathPart)

  echo fontPath
  if fontPath in [
      "/Library/Fonts/Kokonor.ttf", # invalid read?
      "/Library/Fonts/Microsoft Sans Serif.ttf", # 0-sized glyph
      "/Library/Fonts/NISC18030.ttf", # missing head chunk
  ]:
    echo "skip"
    continue

  var font = readFontTtf(fontPath)
  echo font.name

  font.size = 20
  font.lineHeight = 40
  echo font.glyphs.len

  font.drawText(
    image,
    vec2(300, y),
    "The quick brown fox jumps over the lazy dog! :)"
  )

image.alphaToBlankAndWhite()

when defined(windows):
  image.save("systemfonts.windows.png")
elif defined(macos) or defined(macosx):
  image.save("systemfonts.macos.png")
elif defined(linux):
  image.save("systemfonts.linux.png")
else:
  quit("unknown os")
