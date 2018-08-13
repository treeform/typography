import tables, unicode
import flippy, vmath, print
import font, rasterizer

type
  Span* = object
    ## Represents a run of litter of same size and font
    font: Font
    fontSize: float
    # lineHeight: float
    # tracking: float
    text: string

  GlyphPosition* = object
    ## Represents a glyph position after typesetting
    font*: Font
    fontSize*: float
    #lineHeight: float
    subPixelShift*: float
    at*: Vec2
    size*: Vec2
    character*: string

  AlignMode* = enum
    ## Text align mode
    Left
    Center
    Right
    Top
    Bottom


proc kerningAdjustment*(font: var Font, prev, c: string): float =
  ## Get Kerning Adjustment between two letters
  var fontHeight = font.ascent - font.descent
  var scale = font.size / fontHeight
  if prev != "":
    var key = prev & ":" & c
    if font.kerning.hasKey(key):
      var kerning = font.kerning[key]
      return - kerning * scale


proc typeset*(
    font: var Font,
    text: string,
    start: Vec2 = vec2(0, 0)
  ): seq[GlyphPosition] =
  ## Draw text string
  result = @[]
  var at = start
  var prev = ""
  var fontHeight = font.ascent - font.descent
  var scale = font.size / fontHeight

  at.y += floor(font.ascent * scale)

  for rune in runes(text):
    let c = $rune
    if rune == Rune(10):
      at.x = start.x
      at.y += font.lineHeight
      continue

    if c in font.glyphs:
      var glyph = font.glyphs[c]
      at.x += font.kerningAdjustment(prev, c)
      var glyphOffset: Vec2
      var subPixelShift = at.x - floor(at.x)
      let pos = vec2(floor(at.x), floor(at.y + glyphOffset.y))
      let img = font.getGlyphImage(glyph, glyphOffset, subPixelShift=subPixelShift)
      if img.width != 0 and img.height != 0:
        result.add GlyphPosition(
          font: font,
          fontSize: font.size,
          subPixelShift: subPixelShift,
          at: pos,
          size: vec2(float img.width, float img.height),
          character: c
        )
      at.x += glyph.advance * scale
      prev = c

    else:
      discard

proc align*(layout: var seq[GlyphPosition], alignMode: AlignMode = Left) =
  ## Shifts layout by alignMode
  if layout.len == 0: return
  var maxX = layout[0].at.x
  var minX = layout[0].at.x
  if alignMode == Right or alignMode == Center:
    for pos in layout:
      maxX = max(maxX, pos.at.x + pos.size.x)
      minX = min(minX, pos.at.x)
    let textWidth = maxX - minX
    if alignMode == Right:
      for pos in layout.mitems:
        pos.at.x -= textWidth
    if alignMode == Center:
      let center = textWidth / 2.0
      for pos in layout.mitems:
        pos.at.x -= center


proc drawText*(image: var Image, layout: seq[GlyphPosition]) =
  ## Draws layout
  for pos in layout:
    var font = pos.font
    var glyph = font.glyphs[pos.character]
    var glyphOffset: Vec2
    let img = font.getGlyphImage(glyph, glyphOffset, subPixelShift=pos.subPixelShift)
    image.blit(
      img,
      rect(0, 0, img.width, img.height),
      rect(int(pos.at.x + glyphOffset.x), int(pos.at.y + glyphOffset.y), img.width, img.height)
    )


proc drawText*(font: var Font, image: var Image, start: Vec2, text: string) =
  ## Draw text string
  var layout = font.typeset(text, start=start)
  image.drawText(layout)
