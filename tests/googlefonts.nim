## Loads google fonts and draws a text sample.

import algorithm, flippy, math, os, ospaths, strutils,
    tables, typography, vmath, strformat

proc textStr(font: Font): string =
  var text = """The quick brown fox jumps over the lazy dog."""
  if "q" notin font.glyphs:
    # can't display english, use random glpyhs:
    text = ""
    var i = 0
    for g in font.glyphs.values:
      text.add(g.code)
      inc i
      if i > 80:
        break
  return text

var fontPaths: seq[string]

for fontPath in walkDirRec("/p/googlefonts/"):
  if fontPath.endsWith(".ttf"):
    fontPaths.add(fontPath)

fontPaths.sort()
fontPaths = fontPaths

var mainFont = readFontTtf("fonts/Ubuntu.ttf")

for pageNum in 0 ..< fontPaths.len div 100 + 1:
  echo "page ", pageNum
  var image = newImage(800, 100*40, 4)
  for fontNum in 0 .. 100:
    if fontNum + pageNum * 100 >= fontPaths.len:
      break
    let fontPath = fontPaths[fontNum + pageNum * 100]
    var font = readFontTtf(fontPath)
    echo font.name
    echo fontPath
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
        font.textStr()
      )
    except:
      echo "error!"
      discard

  image.alphaToBlankAndWhite()
  let imagePath = &"samples/googlefonts_{pageNum}.png"
  echo "saving ", imagePath
  image.save(imagePath)
