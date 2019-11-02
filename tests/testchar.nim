import tables
import flippy, vmath, chroma, print, strformat
import typography

proc alphaWhite(image: var Image) =
  ## Typography deals mostly with transperant images with white text
  ## This is hard to see in tests so we convert it to white background
  ## with black text.
  for x in 0..<image.width:
    for y in 0..<image.height:
      var c = image.getrgba(x, y)
      c.r = uint8(255) - c.a
      c.g = uint8(255) - c.a
      c.b = uint8(255) - c.a
      c.a = 255
      image.putrgba(x, y, c)


block:
  var font = readFontTtf(r"C:\Windows\Fonts\Alef-Bold.ttf")
  font.size = 300
  font.lineHeight = 300


  for name in font.glyphs.keys:
    echo name
    echo repr(name)
    var image = font.getGlyphOutlineImage(name)
    echo font.glyphs[name].path
    for command in font.glyphs[name].commands:
      echo command
      for i in 0 ..< command.numbers.len div 2:
        var x = int command.numbers[i*2+0]
        var y = int command.numbers[i*2+1]
        print x, y

    image.save("testchar.png")

    image = font.getGlyphImage("&")
    image.alphaWhite()
    image.save("testcharFill.png")