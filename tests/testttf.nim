import pixie, print, typography, vmath, os, osproc

setCurrentDir(getCurrentDir() / "tests")

block:
  #var font = readFontTtf("fonts/Changa-Bold.ttf")
  #var font = readFontTtf("fonts/Ubuntu.ttf")
  var font = readFontTtf("fonts/hanazono/HanaMinA.ttf")
  font.size = 20
  font.lineHeight = 40
  print font.typeface.unitsPerEm
  print font.typeface.ascent
  print font.typeface.descent
  print font.typeface.lineGap

  var image = newImage(500, 40)

  font.drawText(
    image,
    vec2(10, 0),
    """!!! The "quick" brown fox jumps over the lazy dog. !!!"""
  )

  image.alphaToBlankAndWhite()
  image.writeFile("testttf.png")

  echo "saved"

let (outp, _) = execCmdEx("git diff tests/*.png")
if len(outp) != 0:
  echo outp
  quit("Output does not match")
