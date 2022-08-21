import pixie, print, tables, typography, vmath, os, osproc

setCurrentDir(getCurrentDir() / "tests")

block:
  var font = readFontTtf("fonts/Changa-Bold.ttf")
  #var font = readFontTtf("fonts/Ubuntu.ttf")
  #var font = readFontTtf("fonts/Moon Bold.otf")
  #var font = readFontOtf("/p/googlefonts/apache/jsmathcmbx10/jsMath-cmbx10.ttf")
  font.size = 1000
  font.lineHeight = 1000

  # for name in font.glyphs.keys:
  #   font.glyphs[name].name = name

  for i, glyph in font.typeface.glyphArr:
    #print glyph.code
    if glyph.code != "+": continue
    print i, glyph.code
    #if name != "a": continue

    print glyph.code in font.typeface.glyphs
    if glyph.code in font.typeface.glyphs:

      print glyph
      var g = glyph
      g.parseGlyph(font)
      print g

      # g.commands = g.commands[0 .. 20]
      # g.commands.add PathCommand(kind: End)

      #print font.glyphs[name].ttfOffset
      #print font.glyphs[name].commands.len
      # for j, command in font.typeface.glyphs[glyph.code].path.commands:
      #   echo j, ": ", command
      #   for i in 0 ..< command.numbers.len div 2:
      #     var x = int command.numbers[i*2+0]
      #     var y = int command.numbers[i*2+1]
          #print x, y

      glyph.commandsToShapes()

      print glyph.shapes.len
      for i, shape in glyph.shapes:
        for j, segment in shape:
          print i, j, segment

      #print glyph

      # var image = font.getGlyphOutlineImage(
      #   glyph.code,
      #   lines=true,
      #   points=true,
      #   winding=true
      # )

      # image.writeFile("rendered/test_char.png")

      # var glyphOffset: Vec2
      # image = font.getGlyphImage(glyph, glyphOffset, quality=4)
      # image.alphaToBlackAndWhite()
      # image.writeFile("rendered/test_charFill.png")

      # if image.width == 1396:
      #   quit()

let (outp, _) = execCmdEx("git diff tests/rendered/*.png")
if len(outp) != 0:
  echo outp
  quit("Output does not match")
