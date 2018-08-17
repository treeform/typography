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

  HAlignMode* = enum
    ## Horizontal alignment mode
    Left
    Center
    Right

  VAlignMode* = enum
    ## Vertical alignment mode
    Top
    Middle
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
    pos: Vec2 = vec2(0, 0),
    size: Vec2 = vec2(0, 0),
    hAlign: HAlignMode = Left,
    vAlign: VAlignMode = Top
  ): seq[GlyphPosition] =
  ## Draw text string

  result = @[]
  var
    at = pos
    lineStart = pos.x
    prev = ""
    fontHeight = font.ascent - font.descent
    scale = font.size / fontHeight
    boundsMin = vec2(0, 0)
    boundsMax = vec2(0, 0)
    glyphCount = 0

  let smallAdj = floor(font.capHeight - font.xHeight) * scale
  #let smallAdj = 1.0 # WHY?

  at.y += font.size - smallAdj

  var
    index = 0
    lastSpaceAt = 0

  for rune in runes(text):
    var c = $rune
    if rune == Rune(10):
      at.x = lineStart
      at.y += font.lineHeight
      continue

    if rune == Rune(32):
      lastSpaceAt = index

    if c notin font.glyphs:
      c = "\uFFFD" # if glyph is missing use missing glyph

    var glyph = font.glyphs[c]
    at.x += font.kerningAdjustment(prev, c)

    var glyphOffset: Vec2
    var subPixelShift = at.x - floor(at.x)
    var glyphPos = vec2(floor(at.x), floor(at.y + glyphOffset.y))
    let glyphSize = font.getGlyphSize(glyph)
    if glyphSize.x != 0 and glyphSize.y != 0:
      # does it need to wrap?
      if size.x != 0 and at.x - pos.x + glyphSize.x > size.x:
        # wrap to next line
        at.y += font.lineHeight

        let goBack = lastSpaceAt - index + 1
        if goBack < 0:
          let shift = result[result.len + goBack].at.x - pos.x
          for i in result.len + goBack ..< result.len:
            print i
            result[i].at.x -= shift
            result[i].at.y += font.lineHeight
          at.x -= shift
        else:
          at.x = lineStart

        glyphPos = vec2(floor(at.x), floor(at.y + glyphOffset.y))

      if size.y != 0 and at.y - pos.y > size.y:
        # reached the bottom of the area
        return

      result.add GlyphPosition(
        font: font,
        fontSize: font.size,
        subPixelShift: subPixelShift,
        at: glyphPos,
        size: glyphSize,
        character: c
      )
      if glyphCount == 0:
        # first glyph
        boundsMax.x = at.x + glyphSize.x
        boundsMin.x = at.x
        boundsMax.y = at.y + font.size
        boundsMin.y = at.y
      else:
        boundsMax.x = max(boundsMax.x, at.x + glyphSize.x)
        boundsMin.x = min(boundsMin.x, at.x)
        boundsMax.y = max(boundsMax.y, at.y + font.size + smallAdj)
        boundsMin.y = min(boundsMin.y, at.y)

      inc index

    at.x += glyph.advance * scale
    prev = c
    inc glyphCount

  ## Shifts layout by alignMode
  if result.len == 0: return

  let boundsSize = boundsMax - boundsMin

  if hAlign == Right:
    let offset = floor(size.x - boundsSize.x)
    for pos in result.mitems:
      pos.at.x += offset

  if hAlign == Center:
    let offset = floor((size.x - boundsSize.x) / 2.0)
    for pos in result.mitems:
      pos.at.x += offset

  if vAlign == Bottom:
    let offset = floor(size.y - boundsSize.y)
    for pos in result.mitems:
      pos.at.y += offset

  if vAlign == Middle:
    let offset = floor((size.y - boundsSize.y) / 2.0)
    for pos in result.mitems:
      pos.at.y += offset


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


proc drawText*(font: var Font, image: var Image, pos: Vec2, text: string) =
  ## Draw text string
  var layout = font.typeset(text, pos)
  image.drawText(layout)
