## Loads google fonts and draws a text sample.

import pixie, math, os, strutils, cligen, common, tables, typography, vmath,
  strformat, chroma, typography/systemfonts

proc testString(font: Font): string =
  result = "The quick brown fox jumps over the lazy dog."
  if "q" notin font.typeface.glyphs:
    # can't display english, use random glpyhs:
    result = ""
    var i = 0
    for g in font.typeface.glyphs.values:
      result.add(g.code)
      inc i
      if i > 80:
        break

proc main(fonts = "") =
  let (testDir, fontPaths) =
    if fonts.len == 0:
      var systemFonts = getSystemFonts()
      systemFonts.delete(systemFonts.find(r"C:\Windows\Fonts\DINPro.otf")) # Doesn't work yet
      ("systemfonts", systemFonts)
    else:
      ("googlefonts", findAllFonts(fonts))

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
      echo fontPath

      var font = readFontTtf(fontPath)
      font.size = 20
      font.lineHeight = 20

      let y = fontNum.float32 * 40 + 10

      mainFont.size = 10
      mainFont.lineHeight = 20
      mainFont.drawText(image, vec2(10, y), fontPath.lastPathPart)

      let
        topLine = y + 20 + (-font.typeface.ascent + font.typeface.descent) * font.scale
        capLine = y + font.capline
        baseLine = y + font.baseline
        bottomLine = y + 20

      for line in [topLine, capLine, baseLine, bottomLine]:
        let path = newPath()
        path.rect(300, line, 500, 1)
        image.fillPath(path, rgba(0, 0, 0, 255))

      font.drawText(
        image,
        vec2(300, y),
        font.testString()
      )

    image.alphaToBlankAndWhite()
    echo &"saving {testDir} page {pageNum}"
    createDir(&"tests/{testDir}/out")
    image.writeFile(&"tests/{testDir}/out/{pageNum}.png")

    let
      master = readImage(&"tests/{testDir}/masters/{pageNum}.png")
      (score, diff) = imageDiff(master, image)

    createDir(&"tests/{testDir}/diffs")
    diff.writeFile(&"tests/{testDir}/diffs/{pageNum}.png")

    html.add(&"<h4>{pageNum}</h4>")
    html.add(&"<p>{score:0.3f}% diffpx</p>")
    html.add(&"<img width='300' src='out/{pageNum}.png'>")
    html.add(&"<img width='300' src='masters/{pageNum}.png'>")
    html.add(&"<img width='300' src='diffs/{pageNum}.png'>")
    html.add("<br>")

  writeFile(&"tests/{testDir}/index.html", html)

dispatch(main)
