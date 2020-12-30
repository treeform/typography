## Loads google fonts and draws a text sample.

import algorithm, pixie, math, os, strutils, cligen,
    tables, typography, vmath, strformat, chroma

proc imageDiff*(master, image: Image): (float32, Image) =
  var
    diffImage = newImage(master.width, master.height)
    diffScore = 0
    diffTotal = 0
  for x in 0 ..< master.width:
    for y in 0 ..< master.height:
      let
        m = master.getRgbaUnsafe(x, y)
        u = image.getRgbaUnsafe(x, y)
      var
        c: ColorRGBA
      let diff = (m.r.int - u.r.int) +
        (m.g.int - u.g.int) +
        (m.b.int - u.b.int)
      c.r = abs(m.a.int - u.a.int).clamp(0, 255).uint8
      c.g = (diff).clamp(0, 255).uint8
      c.b = (-diff).clamp(0, 255).uint8
      c.a = 255
      diffScore += abs(m.r.int - u.r.int) +
        abs(m.g.int - u.g.int) +
        abs(m.b.int - u.b.int) +
        abs(m.a.int - u.a.int)
      diffTotal += 255 * 4
      diffImage.setRgbaUnsafe(x, y, c)
  return (100 * diffScore.float32 / diffTotal.float32, diffImage)

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
  var fontPaths: seq[string]
  for fontPath in walkDirRec(fonts):
    if fontPath.endsWith(".ttf"):
      fontPaths.add(fontPath)
  fontPaths.sort()

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
