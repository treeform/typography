import sequtils, typography, unicode, vmath

#[
It's hard to implement a text. A textbox has many complex features one does not think about
because it is so natural. Here is a small list of the most important ones:

* Typing at location of cursor
* Cursor going left and right
* Backspace and delete
* Cursor going up and down must take into account font and line wrap
* Clicking should select a character edge. Closet edge wins.
* Click and drag should select text, selected text will be between text cursor and select cursor
* Any insert when typing or copy pasting and have selected text, it should get removed and then do normal action
* Copy text should set it to system clipboard
* Cut text should copy and remove selected text
* Paste text should paste at current text cursor, if there is selection it needs to be removed
* Clicking before text should select first character
* Clicking at the end of text should select last character
* Click at the end of the end of the line should select character before the new line
* Click at the end of the start of the line should select character first character and not the newline
* Double click should select current word
* Double click again should select current peragraph
* Double click again should select everything
* Text area needs to be able to have margins that can be clicked
* There should be a scroll bar and a scroll window
* Scroll window should stay with the text cursor
* Backspace and delete with selected text remove selected text and don't perform their normal action
]#

type TextBox* = ref object
  cursor*: int      # the typing cursor
  selector*: int    # the selection cursor
  runes*: seq[Rune] # the runes we are typing
  width*: int       # width of text box in px
  height*: int      # height of text box in px
  scroll*: Vec2     # scroll position
  font*: Font
  fontSize*: float
  lineHeight*: float
  mousePos*: Vec2

  multiline*: bool  # single line only (good for input fields)
  wordWrap*: bool   # should the lines wrap or not

  glyphs: seq[GlyphPosition]
  savedX: float

proc clamp(v, a, b: int): int =
  max(a, min(b, v))

proc newTextBox*(font: Font, width, height: int): TextBox =
  ## Creates new empty textbox
  result = TextBox()
  result.font = font
  result.fontSize = font.size
  result.lineHeight = font.lineHeight
  result.width = width
  result.height = height
  result.multiline = true
  result.wordWrap = true

proc newTextBox*(
  font: Font, width,
  height: int,
  text: string,
  multiline = true
): TextBox =
  ## Creates new text box with existing text
  result = TextBox()
  result.font = font
  result.fontSize = font.size
  result.lineHeight = font.lineHeight
  result.width = width
  result.height = height
  result.multiline = multiline
  result.wordWrap = multiline
  result.runes = toRunes(text)
  result.cursor = result.runes.len
  result.selector = result.cursor

proc cursorWidth*(font: Font): float =
  min(font.size / 12, 1)

proc text*(textBox: TextBox): string =
  ## Converts internal runes to string
  $textBox.runes

proc multilineCheck(textBox: TextBox) =
  ## Makes sure there are not new lines in a single line text box
  if not textBox.multiline:
    textBox.runes.keepIf(proc (r: Rune): bool = r != Rune(10))

proc size*(textBox: TextBox): Vec2 =
  ## Returns with and height as a Vec2
  vec2(float textBox.width, float textBox.height)

proc selection*(textBox: TextBox): HSlice[int, int] =
  ## Returns current selection from
  result.a = min(textBox.cursor, textBox.selector)
  result.b = max(textBox.cursor, textBox.selector)

proc layout*(textBox: TextBox): seq[GlyphPosition] =
  if textBox.glyphs.len == 0:
    textBox.font.size = textBox.fontSize
    textBox.font.lineHeight = textBox.lineHeight
    textBox.multilineCheck()
    var size = vec2(1E10, 1E10)
    if textBox.wordWrap:
      size = textBox.size
    textBox.glyphs = textBox.font.typeset(
     textBox.runes,
     vec2(0, 0),
     size = size,
     clip = false
    )
  return textBox.glyphs

proc innerHeight*(textBox: TextBox): int =
  ## Rectangle where selection cursor should be drawn
  let layout = textBox.layout()
  if layout.len > 0:
    let lastPos = layout[^1].selectRect
    return int(lastPos.y + lastPos.h)
  else:
    return int(textBox.font.lineHeight)

proc locationRect*(textBox: TextBox, loc: int): Rect =
  ## Rectangle where cursor should be drawn
  let layout = textBox.layout()
  if layout.len > 0:
    if loc >= layout.len:
      let g = layout[^1]
      # if last char is a new line go to next line
      if g.character == "\n":
        result.x = 0
        result.y = g.selectRect.y + textBox.font.lineHeight
      else:
        result = g.selectRect
        result.x += g.selectRect.w
    else:
      let g = layout[loc]
      result = g.selectRect
  result.w = textBox.font.cursorWidth
  result.h = textBox.font.lineHeight + 1.0

proc cursorRect*(textBox: TextBox): Rect =
  ## Rectangle where cursor should be drawn
  textBox.locationRect(textBox.cursor)

proc cursorPos*(textBox: TextBox): Vec2 =
  ## Position where cursor should be drawn
  textBox.cursorRect.xy

proc selectorRect*(textBox: TextBox): Rect =
  ## Rectangle where selection cursor should be drawn
  textBox.locationRect(textBox.selector)

proc selectorPos*(textBox: TextBox): Vec2 =
  ## Position where selection cursor should be drawn
  textBox.cursorRect.xy

proc selectionRegions*(textBox: TextBox): seq[Rect] =
  ## Selection regions to draw selection of text
  let sel = textBox.selection
  textBox.layout.getSelection(sel.a, sel.b)

proc removedSelection*(textBox: TextBox): bool =
  ## Removes selected runes if they are selected.
  ## Returns true if anything was removed.
  let sel = textBox.selection
  if sel.a != sel.b:
    textBox.runes.delete(sel.a, sel.b - 1)
    textBox.glyphs.setLen(0)
    textBox.cursor = sel.a
    textBox.selector = textBox.cursor
    return true
  return false

proc removeSelection(textBox: TextBox) =
  ## Removes selected runes if they are selected.
  discard textBox.removedSelection()

proc adjustScroll*(textBox: TextBox) =
  ## Adjust scroll to make sure cursor is in the window
  let
    r = textBox.cursorRect
  # is pos.y inside the window?
  if r.y < textBox.scroll.y:
    textBox.scroll.y = r.y
  if r.y + r.h > textBox.scroll.y + float textBox.height:
    textBox.scroll.y = r.y + r.h - float textBox.height
  # is pos.x inside the window?
  if r.x < textBox.scroll.x:
    textBox.scroll.x = r.x
  if r.x + r.w > textBox.scroll.x + float textBox.width:
    textBox.scroll.x = r.x + r.w - float textBox.width

proc typeCharacter*(textBox: TextBox, rune: Rune) =
  ## Add a character to the text box.
  textBox.removeSelection()
  # dont add new lines in a single line box
  if not textBox.multiline and rune == Rune(10):
    return
  if textBox.cursor == textBox.runes.len:
    textBox.runes.add(rune)
  else:
    textBox.runes.insert(rune, textBox.cursor)
  inc textBox.cursor
  textBox.selector = textBox.cursor
  textBox.glyphs.setLen(0)
  textBox.adjustScroll()

proc typeCharacter*(textBox: TextBox, letter: char) =
  ## Add a character to the text box.
  textBox.typeCharacter(Rune(letter))

proc typeCharacters*(textBox: TextBox, s: string) =
  ## Add a character to the text box.
  textBox.removeSelection()
  for rune in runes(s):
    textBox.runes.insert(rune, textBox.cursor)
    inc textBox.cursor
  textBox.selector = textBox.cursor
  textBox.glyphs.setLen(0)
  textBox.adjustScroll()

proc copy*(textBox: TextBox): string =
  ## Returns the text that was copied
  let sel = textBox.selection
  if sel.a != sel.b:
    return $textBox.runes[sel.a ..< sel.b]

proc paste*(textBox: TextBox, s: string) =
  ## Pastes a string
  textBox.typeCharacters(s)
  textBox.savedX = textBox.cursorPos.x

proc cut*(textBox: TextBox): string =
  ## Returns the text that was cut
  result = textBox.copy()
  textBox.removeSelection()
  textBox.savedX = textBox.cursorPos.x

proc setCursor*(textBox: TextBox, loc: int) =
  textBox.cursor = clamp(loc, 0, textBox.runes.len + 1)
  textBox.selector = textBox.cursor

proc backspace*(textBox: TextBox, shift = false) =
  ## Backspace command.
  if textBox.removedSelection(): return
  if textBox.cursor > 0:
    textBox.runes.delete(textBox.cursor - 1)
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()
    dec textBox.cursor
    textBox.selector = textBox.cursor

proc delete*(textBox: TextBox, shift = false) =
  ## Delete command.
  if textBox.removedSelection(): return
  if textBox.cursor < textBox.runes.len:
    textBox.runes.delete(textBox.cursor)
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()

proc backspaceWord*(textBox: TextBox, shift = false) =
  ## Backspace wrod command. (Usually ctr + backspace)
  if textBox.removedSelection(): return
  if textBox.cursor > 0:
    while textBox.cursor > 0 and
      not textBox.runes[textBox.cursor - 1].isWhiteSpace():
      textBox.runes.delete(textBox.cursor - 1)
      dec textBox.cursor
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()
    textBox.selector = textBox.cursor

proc deleteWord*(textBox: TextBox, shift = false) =
  ## Delete word command. (Usually ctr + delete)
  if textBox.removedSelection(): return
  if textBox.cursor < textBox.runes.len:
    while textBox.cursor < textBox.runes.len and
      not textBox.runes[textBox.cursor].isWhiteSpace():
      textBox.runes.delete(textBox.cursor)
    textBox.glyphs.setLen(0)
    textBox.adjustScroll()

proc left*(textBox: TextBox, shift = false) =
  ## Move cursor left
  if textBox.cursor > 0:
    dec textBox.cursor
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
    textBox.savedX = textBox.cursorPos.x

proc right*(textBox: TextBox, shift = false) =
  ## Move cursor right
  if textBox.cursor < textBox.runes.len:
    inc textBox.cursor
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
    textBox.savedX = textBox.cursorPos.x

proc down*(textBox: TextBox, shift = false) =
  ## Move cursor down
  if textBox.layout.len == 0:
    return
  let pos = textBox.layout.pickGlyphAt(
    vec2(textBox.savedX, textBox.cursorPos.y + textBox.font.lineHeight * 1.5))
  if pos.character != "":
    textBox.cursor = pos.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif textBox.cursorPos.y == textBox.layout[^1].selectRect.y:
    # are we on the last line? then jump to start location last
    textBox.cursor = textBox.runes.len
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc up*(textBox: TextBox, shift = false) =
  ## Move cursor up
  if textBox.layout.len == 0:
    return
  let pos = textBox.layout.pickGlyphAt(
    vec2(textBox.savedX, textBox.cursorPos.y - textBox.font.lineHeight * 0.5))
  if pos.character != "":
    textBox.cursor = pos.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif textBox.cursorPos.y == textBox.layout[0].selectRect.y:
    # are we on the first line? then jump to start location 0
    textBox.cursor = 0
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc leftWord*(textBox: TextBox, shift = false) =
  ## Move cursor left by a word (Usually ctr + left)
  if textBox.cursor > 0:
    dec textBox.cursor
  while textBox.cursor > 0 and
    not textBox.runes[textBox.cursor - 1].isWhiteSpace():
    dec textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc rightWord*(textBox: TextBox, shift = false) =
  ## Move cursor right by a word (Usually ctr + right)
  if textBox.cursor < textBox.runes.len:
    inc textBox.cursor
  while textBox.cursor < textBox.runes.len and
    not textBox.runes[textBox.cursor].isWhiteSpace():
    inc textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc startOfLine*(textBox: TextBox, shift = false) =
  ## Move cursor left by a word
  while textBox.cursor > 0 and
    textBox.runes[textBox.cursor - 1] != Rune(10):
    dec textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc endOfLine*(textBox: TextBox, shift = false) =
  ## Move cursor right by a word
  while textBox.cursor < textBox.runes.len and
    textBox.runes[textBox.cursor] != Rune(10):
    inc textBox.cursor
  textBox.adjustScroll()
  if not shift:
    textBox.selector = textBox.cursor
  textBox.savedX = textBox.cursorPos.x

proc pageUp*(textBox: TextBox, shift = false) =
  ## Move cursor up by half a text box height
  if textBox.layout.len == 0:
    return
  let
    pos = vec2(textBox.savedX, textBox.cursorPos.y - float(textBox.height) * 0.5)
    g = textBox.layout.pickGlyphAt(pos)
  if g.character != "":
    textBox.cursor = g.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif pos.y <= textBox.layout[0].selectRect.y:
    # above the first line? then jump to start location 0
    textBox.cursor = 0
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc pageDown*(textBox: TextBox, shift = false) =
  ## Move cursor down up by half a text box height
  if textBox.layout.len == 0:
    return
  let
    pos = vec2(textBox.savedX, textBox.cursorPos.y + float(textBox.height) * 0.5)
    g = textBox.layout.pickGlyphAt(pos)
  if g.character != "":
    textBox.cursor = g.count
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor
  elif pos.y > textBox.layout[^1].selectRect.y:
    # bellow the last line? then jump to start location last
    textBox.cursor = textBox.runes.len
    textBox.adjustScroll()
    if not shift:
      textBox.selector = textBox.cursor

proc mouseAction*(
  textBox: TextBox,
  mousePos: Vec2,
  click = true,
  shift = false
) =
  ## Click on this with a mouse
  textBox.mousePos = mousePos + textBox.scroll
  # pick where to place the cursor
  let pos = textBox.layout.pickGlyphAt(textBox.mousePos)
  if pos.character != "":
    textBox.cursor = pos.count
    textBox.savedX = textBox.mousePos.x
    if pos.character != "\n":
      # select to the right or left of the character based on what is closer
      let pickOffset = textBox.mousePos - pos.selectRect.xy
      if pickOffset.x > pos.selectRect.w / 2 and
         textBox.cursor == textBox.runes.len - 1:
        inc textBox.cursor
  else:
    # if above the text select first character
    if textBox.mousePos.y < 0:
      textBox.cursor = 0
    # if below text select last character + 1
    if textBox.mousePos.y > float textBox.innerHeight:
      textBox.cursor = textBox.glyphs.len
  textBox.savedX = textBox.mousePos.x
  textBox.adjustScroll()

  if not shift and click:
    textBox.selector = textBox.cursor

proc selectWord*(textBox: TextBox, mousePos: Vec2, extraSpace = true) =
  ## Select word under the cursor (double click)
  textBox.mouseAction(mousePos, click = true)
  while textBox.cursor > 0 and
    not textBox.runes[textBox.cursor - 1].isWhiteSpace():
    dec textBox.cursor
  while textBox.selector < textBox.runes.len and
    not textBox.runes[textBox.selector].isWhiteSpace():
    inc textBox.selector
  if extraSpace:
    # Select extra space to the right if its there
    if textBox.selector < textBox.runes.len and
      textBox.runes[textBox.selector] == Rune(32):
      inc textBox.selector

proc selectPeragraph*(textBox: TextBox, mousePos: Vec2) =
  ## Select peragraph under the cursor (triple click)
  textBox.mouseAction(mousePos, click = true)
  while textBox.cursor > 0 and
     textBox.runes[textBox.cursor - 1] != Rune(10):
    dec textBox.cursor
  while textBox.selector < textBox.runes.len and
     textBox.runes[textBox.selector] != Rune(10):
    inc textBox.selector

proc selectAll*(textBox: TextBox) =
  ## Select all text (quad click)
  textBox.cursor = 0
  textBox.selector = textBox.runes.len

proc resize*(textBox: TextBox, size: Vec2) =
  ## Resize text box
  textBox.width = int size.x
  textBox.height = int size.y
  textBox.glyphs.setLen(0)
  textBox.adjustScroll()

proc scrollBy*(textBox: TextBox, amount: float) =
  ## Scroll text box with a scroll wheel
  textBox.scroll.y += amount
  # make sure it does not scroll off the top
  textBox.scroll.y = max(0, textBox.scroll.y)
  # or the bottom
  textBox.scroll.y = min(
    float(textBox.innerHeight - textBox.height),
    textBox.scroll.y
  )
  # Check if there is not enough text to scroll
  if textBox.innerHeight < textBox.height:
    textBox.scroll.y = 0
