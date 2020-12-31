## Loads system fonts and draws a text sample.

import pixie, math, os, typography, typography/systemfonts, vmath

let fontPaths = getSystemFonts()

var image = newImage(1000, fontPaths.len*40)

var mainFont = readFontTtf("tests/fonts/Ubuntu.ttf")

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
      r"C:\Windows\Fonts\DINPro.otf"
  ]:
    echo "skip"
    continue

  var font = readFontTtf(fontPath)
  echo font.typeface.name

  font.size = 20
  font.lineHeight = 40
  echo font.typeface.glyphArr.len

  font.drawText(
    image,
    vec2(300, y),
    "The quick brown fox jumps over the lazy dog! :)"
  )

image.alphaToBlankAndWhite()

when defined(windows):
  image.writeFile("tests/rendered/systemfonts/windows.png")
elif defined(macos) or defined(macosx):
  image.writeFile("tests/rendered/systemfonts/macos.png")
elif defined(linux):
  image.writeFile("tests/rendered/systemfonts/linux.png")
else:
  quit("unknown os")
