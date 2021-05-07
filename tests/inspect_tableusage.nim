import common, cligen, typography, tables

var usage: CountTable[string]

proc main(fonts = "/p/googlefonts") =
  let fontPaths = findAllFonts(fonts)
  for fontPath in fontPaths:
    let font = readFontOtf(fontPath)
    for tag in font.typeface.otf.chunks.keys:
      usage.inc(tag)

  usage.sort()

  for tag, count in usage:
    let countStr = $count
    var dots = ""
    for i in tag.len + countStr.len .. 40:
      dots.add(".")
    echo tag, " ", dots, " ", countStr

dispatch(main)
