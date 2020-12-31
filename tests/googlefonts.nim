## Loads google fonts and draws a text sample.

import pixie, math, os, strutils, cligen, common, tables, typography, vmath,
  strformat, chroma

proc textStr(font: Font): string =
  var text = """The quick brown fox jumps over the lazy dog."""
  if "q" notin font.typeface.glyphs:
    # can't display english, use random glpyhs:
    text = ""
    var i = 0
    for g in font.typeface.glyphs.values:
      text.add(g.code)
      inc i
      if i > 80:
        break
  return text

proc main(fonts = "/p/googlefonts/") =
  let fontPaths = findAllFonts(fonts)

  var
    mainFont = readFontTtf("tests/fonts/Ubuntu.ttf")
    html = ""

  for pageNum in 0 ..< fontPaths.len div 100 + 1:
    echo "page ", pageNum
    var image = newImage(800, 100*40)
    for fontNum in 0 .. 100:
      if fontNum + pageNum * 100 >= fontPaths.len:
        break
      let fontPath = fontPaths[fontNum + pageNum * 100]
      var font = readFontTtf(fontPath)
      #echo font.name
      #echo fontPath
      font.size = 20
      font.lineHeight = 20
      if " " in font.typeface.glyphs:
        echo font.typeface.glyphs[" "].advance, " ", fontPath

      let y = fontNum.float32 * 40 + 10

      mainFont.size = 10
      mainFont.lineHeight = 20
      mainFont.drawText(image, vec2(10, y), fontPath.lastPathPart)

      let topLine = y + 20 + (-font.typeface.ascent + font.typeface.descent) * font.scale
      let capLine = y + font.capline
      let baseLine = y + font.baseline
      let bottomLine = y + 20

      for line in [topLine, capLine, baseLine, bottomLine]:
        let path = newPath()
        path.rect(300, line, 500, 1)
        image.fillPath(path, rgba(0, 0, 0, 255))

      font.drawText(
        image,
        vec2(300, y),
        font.textStr()
      )

    image.alphaToBlankAndWhite()
    echo "saving ", pageNum
    image.writeFile(&"tests/googlefonts/out/googlefonts_{pageNum}.png")

    let
      master = readImage(&"tests/googlefonts/masters/googlefonts_{pageNum}.png")
      (score, diff) = imageDiff(master, image)

    diff.writeFile(&"tests/googlefonts/diffs/googlefonts_{pageNum}.png")

    html.add(&"<h4>{pageNum}</h4>")
    html.add(&"<p>{score:0.3f}% diffpx</p>")
    html.add(&"<img width='300' src='out/googlefonts_{pageNum}.png'>")
    html.add(&"<img width='300' src='masters/googlefonts_{pageNum}.png'>")
    html.add(&"<img width='300' src='diffs/googlefonts_{pageNum}.png'>")
    html.add("<br>")

  writeFile("tests/googlefonts/index.html", html)

dispatch(main)
