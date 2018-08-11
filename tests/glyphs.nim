import tables

import ../src/typography
import ../src/typography/images
import ../src/typography/vmath

block:
  #var font = readFontTtf("fonts/SourceSansPro.otf")
  var font = readFontTtf("fonts/Moon Bold.otf")
  font.size = 300
  font.lineHeight = 300

  var image = font.getGlyphOutlineImage("Q")

  echo font.glyphs["Q"].path
  # M754,236 Q555,236 414,377  Q273,518 273,717  Q273,916 414,1057  Q555,1198 754,1198  Q953,1198 1094,1057  Q1235,916 1235,717  Q1235,593 1175,485  L1096,565  Q1062,599 1013,599  Q964,599 929,565  Q895,530 895,481  Q895,432 929,398  L1014,313  Q895,236 754,236  Z M1347,314  Q1471,496 1471,717  Q1471,1014 1261,1224  Q1051,1434 754,1434  Q458,1434 247,1224 Q37,1014 37,717  Q37,421 247,210  Q458,0 754,0  Q993,0 1184,143  L1292,35  Q1327,0 1376,0  Q1425,0 1459,35  Q1494,69 1494,118  Q1494,167 1459,201  Z

  image.filename = "examples/q.png"
  image.save()


block:
  var image = newImage("examples/subpixelglyphs.png", 140, 20, 4)
  image.fill(rgba(255, 255, 255, 255))

  var font = readFontSvg("fonts/DejaVuSans.svg")
  font.size = 11 # 11px or 8pt
  var glyph = font.glyphs["g"]
  var under = font.glyphs["_"]

  for i in 0..<10:
    var glyphOffset: Vec2
    var at = vec2(12.0 + float(i)*12, 11)
    var img = font.getGlyphImage(glyph, glyphOffset, subPixelShift=float(i)/10.0)
    img.blit(
      image,
      newRect(0, 0, img.width, img.height),
      newRect(int(at.x + glyphOffset.x), int(at.y + glyphOffset.y), img.width, img.height)
    )

  image = image.magnify(6)
  for i in 0..<10:
    var red = Rgba(r:255,g:0,b:0,a:255)
    var at = vec2(12.0 + float(i)*12, 15) * 6
    font.drawText(image, at + vec2(0, 6), "+0." & $i)

    image.drawLine(at, at + vec2(7*6, 0), red)
    image.drawLine(at + vec2(7*6, 0), at + vec2(7*6, -13*6), red)
    image.drawLine(at + vec2(0, -13*6), at + vec2(7*6, -13*6), red)
    image.drawLine(at + vec2(0, -13*6), at, red)
  image.save()