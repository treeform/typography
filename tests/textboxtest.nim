import bumpy, chroma, pixie, print, strformat, typography, typography/textboxes,
    unicode, vmath, os, osproc

setCurrentDir(getCurrentDir() / "tests")

proc alphaWhite(image: var Image) =
  ## Typography deals mostly with transparent images with white text
  ## This is hard to see in tests so we convert it to white background
  ## with black text.
  for x in 0..<image.width:
    for y in 0..<image.height:
      var c = image[x, y]
      c.r = uint8(255) - c.a
      c.g = uint8(255) - c.a
      c.b = uint8(255) - c.a
      c.a = 255
      image[x, y] = c

proc drawRect(image: var Image, at, wh: Vec2, color: ColorRGBA) =
  var wh = wh - vec2(1, 1) # line width
  image.line(at, at + vec2(wh.x, 0), color)
  image.line(at + vec2(wh.x, 0), at + vec2(wh.x, wh.y), color)
  image.line(at + vec2(0, wh.y), at + vec2(wh.x, wh.y), color)
  image.line(at + vec2(0, wh.y), at, color)

proc drawRect(image: var Image, rect: Rect, color: ColorRGBA) =
  image.drawRect(rect.xy, rect.wh, color)

proc draw(textBox: TextBox, imageName: string) =
  var image = newImage(textBox.width, textBox.innerHeight)

  # draw text at a layout
  image.drawText(textBox.layout)

  image.alphaWhite()

  # draw scroll region
  image.drawRect(
    rect(0, float textBox.scroll.y, float textBox.width, float textBox.height),
    rgba(0, 255, 255, 155))

  # draw selection regions
  for rect in textBox.selectionRegions():
    image.drawRect(rect, rgba(0, 255, 0, 155))

  # draw cursor
  image.drawRect(textBox.selectorRect, rgba(0, 0, 255, 255))
  image.drawRect(textBox.cursorRect, rgba(255, 0, 0, 255))

  # draw mouse pos
  image.drawRect(rect(textBox.mousePos, vec2(4, 4)), rgba(255, 128, 128, 255))

  image.writeFile(imageName)

var font = readFontSvg("fonts/Ubuntu.svg")
font.size = 16
font.lineHeight = 20

block:
  print "plain"
  var textBox = newTextBox(font, 300, 120)
  textBox.draw("textbox/plain.png")

block:
  print "typing"
  var textBox = newTextBox(font, 300, 120)
  textBox.typeCharacter(Rune(65))
  textBox.typeCharacter('B')
  textBox.typeCharacters("CDEFG")
  textBox.draw("textbox/typing.png")

block:
  print "backspace & delete"
  var textBox = newTextBox(font, 300, 120, "ABCDEFG")
  textBox.backspace()
  textBox.setCursor(0)
  textBox.delete()
  textBox.draw("textbox/backspace_delete.png")

block:
  print "ctr backspace & ctr delete"
  var textBox = newTextBox(font, 300, 120, "Lorem  dolor sit amet, consectetur elit.")
  textBox.setCursor(11)
  textBox.backspaceWord()
  textBox.setCursor(7)
  textBox.deleteWord()
  textBox.draw("textbox/word_backspace_delete.png")

block:
  print "left & right"
  var textBox = newTextBox(font, 300, 120, "ABCDEFG")
  for i in 0..10:
    textBox.left()
  for i in 0..10:
    textBox.right()

  for i in 0..4:
    textBox.left()
  for i in 0..2:
    textBox.right()

  textBox.draw("textbox/left_right.png")

block:
  print "left & right shift"
  var textBox = newTextBox(font, 300, 120, "ABCDEFG")
  var f = 0
  for i in 0..7:
    textBox.left(shift = true)
    textBox.draw(&"textbox/left_right_shift_{f}.png")
    inc f
  for i in 0..7:
    textBox.right(shift = true)
    textBox.draw(&"textbox/left_right_shift_{f}.png")
    inc f

  for i in 0..4:
    textBox.left(shift = true)
    textBox.draw(&"textbox/left_right_shift_{f}.png")
    inc f
  for i in 0..2:
    textBox.right(shift = true)
    textBox.draw(&"textbox/left_right_shift_{f}.png")
    inc f

block:
  print "up & down"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit.

Maecenas facilisis massa ac ipsum efficitur, in consequat justo imperdiet.

Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.setCursor(0)
  for i in 0..10:
    textBox.right()

  textBox.draw("textbox/up_down_0.png")
  textBox.down()
  textBox.draw("textbox/up_down_1.png")
  textBox.down()
  textBox.draw("textbox/up_down_2.png")
  textBox.down()
  textBox.draw("textbox/up_down_3.png")
  textBox.down()
  textBox.draw("textbox/up_down_4.png")

  textBox.draw("textbox/up_down_5.png")
  textBox.up()
  textBox.draw("textbox/up_down_6.png")
  textBox.up()
  textBox.draw("textbox/up_down_7.png")
  textBox.up()
  textBox.draw("textbox/up_down_8.png")
  textBox.up()
  textBox.draw("textbox/up_down_9.png")

block:
  print "empty text box"
  var textBox = newTextBox(font, 300, 120, "")
  textBox.up()
  textBox.down()
  textBox.left()
  textBox.right()
  textBox.backspace()
  textBox.delete()
  textBox.backspaceWord()
  textBox.deleteWord()
  textBox.leftWord()
  textBox.rightWord()
  textBox.startOfLine()
  textBox.endOfLine()
  textBox.pageUp()
  textBox.pageDown()

block:
  print "1char text box"
  var textBox = newTextBox(font, 300, 120, "?")
  textBox.up()
  textBox.down()
  textBox.left()
  textBox.right()
  textBox.backspace()
  textBox.delete()
  textBox.backspaceWord()
  textBox.deleteWord()
  textBox.leftWord()
  textBox.rightWord()
  textBox.startOfLine()
  textBox.endOfLine()
  textBox.pageUp()
  textBox.pageDown()

block:
  print "picking"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.mouseAction(vec2(30, 30), click = true)
  # mouse dragging to select
  for i in 0..10:
    textBox.mouseAction(vec2(float 30+i*10, float 30+i*5), click = false)
    textBox.draw(&"textbox/picking_{i}.png")

block:
  print "copy"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.mouseAction(vec2(30, 30), click = true)
  textBox.mouseAction(vec2(230, 30), click = false)
  print textBox.copy()
  textBox.draw("textbox/copy.png")

block:
  print "paste"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.mouseAction(vec2(30, 30), click = true)
  textBox.mouseAction(vec2(230, 30), click = false)
  textBox.draw("textbox/paste_0.png")
  textBox.paste("<PASTED>")
  textBox.draw("textbox/paste_1.png")

block:
  print "cut"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.mouseAction(vec2(30, 30), click = true)
  textBox.mouseAction(vec2(230, 30), click = false)
  print textBox.cut()
  textBox.draw("textbox/cut.png")

block:
  print "select word"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.selectWord(vec2(30, 30))
  textBox.draw("textbox/select_word.png")

block:
  print "select peragraph"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.selectParagraph(vec2(30, 30))
  textBox.draw("textbox/select_peragraph.png")

block:
  print "select all"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.selectAll()
  textBox.draw("textbox/select_all.png")

block:
  print "jump to 0 on up"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis massa ac ipsum eff!
Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.mouseAction(vec2(30, 30), click = true)
  textBox.draw("textbox/jump_up_0.png")
  textBox.up()
  textBox.draw("textbox/jump_up_1.png")
  textBox.up()
  textBox.draw("textbox/jump_up_2.png")
  textBox.down()
  textBox.draw("textbox/jump_up_3.png")

block:
  print "jump to last on down"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit. Maecenas facilisis quam odio, tempor a facilisis massa ac ipsum eff!""")
  textBox.mouseAction(vec2(30, 30), click = true)
  textBox.draw("textbox/jump_down_0.png")
  textBox.down()
  textBox.draw("textbox/jump_down_1.png")
  textBox.down()
  textBox.draw("textbox/jump_down_2.png")
  textBox.up()
  textBox.draw("textbox/jump_down_3.png")

block:
  print "scrolling up & down"
  var textBox = newTextBox(font, 300, 120, """
Lorem ipsum dolor sit amet, consectetur elit.

Maecenas facilisis massa ac ipsum efficitur, in consequat justo imperdiet.

Mauris vel turpis a elit scelerisque luctus. Aliquam quam odio, tempor a facilisis et, cursus nec nibh. Nunc ut facilisis arcu. Cras odio lorem, facilisis eget tincidunt nec, maximus sit amet nulla. Nam mi dolor, dignissim ac eleifend ut, malesuada et libero. Vestibulum mattis bibendum mattis. Donec diam odio, pellentesque sed bibendum quis, facilisis ut mauris.""")
  textBox.setCursor(0)
  for i in 0..10:
    textBox.right()
  var f = 0
  textBox.draw(&"textbox/scroll_{f}.png")
  inc f
  for i in 0..10:
    textBox.down()
    textBox.draw(&"textbox/scroll_{f}.png")
    inc f
  for i in 0..10:
    textBox.up()
    textBox.draw(&"textbox/scroll_{f}.png")
    inc f

let (outp, _) = execCmdEx("git diff tests/*.png")
if len(outp) != 0:
  echo outp
  quit("Output does not match")
