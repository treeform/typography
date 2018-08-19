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
    subPixelShift*: float
    rect*: Rect # Where to draw the image character
    selectRect*: Rect # Were to draw or hit selection
    character*: string
    index*: int

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


proc canWrap(rune: Rune): bool =
  if rune == Rune(32): return true # early return for ascii space
  if rune.isWhiteSpace(): return true
  if not rune.isAlpha(): return true


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
    strIndex = 0
    glyphIndex = 0
    lastCanWrap = 0

  for rune in runes(text):
    var c = $rune
    if rune == Rune(10):
      at.x = lineStart
      at.y += font.lineHeight
      continue

    if canWrap(rune):
      lastCanWrap = glyphIndex

    if c notin font.glyphs:
      c = "\uFFFD" # if glyph is missing use missing glyph

    var glyph = font.glyphs[c]
    at.x += font.kerningAdjustment(prev, c)

    var glyphOffset: Vec2
    var subPixelShift = at.x - floor(at.x)
    var glyphPos = vec2(floor(at.x), floor(at.y + glyphOffset.y))
    let glyphSize = font.getGlyphSize(glyph)
    if glyphSize.x != 0 and glyphSize.y != 0 and rune != Rune(32):
      # does it need to wrap?
      if size.x != 0 and at.x - pos.x + glyphSize.x > size.x:
        # wrap to next line
        at.y += font.lineHeight

        let goBack = lastCanWrap - glyphIndex
        if goBack < 0:

          if size.y != 0 and at.y - pos.y > size.y:
            # delete glyphs that would wrap into next line that is clipped
            result.setLen(result.len + goBack)
            return

          # wrap glyphs on prev line down to next line
          let shift = result[result.len + goBack].rect.x - pos.x
          for i in result.len + goBack ..< result.len:
            result[i].rect.x -= shift
            result[i].rect.y += font.lineHeight
          at.x -= shift
        else:
          at.x = lineStart

        glyphPos = vec2(floor(at.x), floor(at.y + glyphOffset.y))

      if size.y != 0 and at.y - pos.y > size.y:
        # reached the bottom of the area, clip
        return

      var selectRect =
        rect(floor(at.x),
        floor(at.y) - font.size / 2 - font.lineHeight / 2,
        glyphSize.x,
        font.lineHeight)

      result.add GlyphPosition(
        font: font,
        fontSize: font.size,
        subPixelShift: subPixelShift,
        rect: rect(glyphPos, glyphSize),
        selectRect: selectRect,
        character: c,
        index: strIndex
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

      inc glyphIndex

    at.x += glyph.advance * scale
    prev = c
    inc glyphCount
    strIndex += c.len

  ## Shifts layout by alignMode
  if result.len == 0: return

  let boundsSize = boundsMax - boundsMin

  if hAlign == Right:
    let offset = floor(size.x - boundsSize.x)
    for pos in result.mitems:
      pos.rect.x += offset

  if hAlign == Center:
    let offset = floor((size.x - boundsSize.x) / 2.0)
    for pos in result.mitems:
      pos.rect.x += offset

  if vAlign == Bottom:
    let offset = floor(size.y - boundsSize.y)
    for pos in result.mitems:
      pos.rect.y += offset

  if vAlign == Middle:
    let offset = floor((size.y - boundsSize.y) / 2.0)
    for pos in result.mitems:
      pos.rect.y += offset


proc drawText*(image: var Image, layout: seq[GlyphPosition]) =
  ## Draws layout
  for pos in layout:
    var font = pos.font
    var glyph = font.glyphs[pos.character]
    var glyphOffset: Vec2
    let img = font.getGlyphImage(glyph, glyphOffset, subPixelShift=pos.subPixelShift)
    image.blit(
      img,
      rect(
        0, 0,
        float img.width, float img.height
      ),
      rect(
        pos.rect.x + glyphOffset.x, pos.rect.y + glyphOffset.y,
        float img.width, float img.height
      )
    )


proc drawText*(font: var Font, image: var Image, pos: Vec2, text: string) =
  ## Draw text string
  var layout = font.typeset(text, pos)
  image.drawText(layout)


proc getSelection*(layout: seq[GlyphPosition], start, stop: int): seq[Rect] =
  ## Given a layout gives selection from start to stop
  ## If start == stop, just a caret position is given
  for g in layout:
    if g.index >= start and g.index < stop:
      if result.len > 0:
        let onSameLine = result[^1].y == g.selectRect.y and result[^1].h == g.selectRect.h
        let notTooFar = g.selectRect.x - result[^1].x < result[^1].w * 2
        if onSameLine and notTooFar:
          result[^1].w = g.selectRect.x - result[^1].x + g.selectRect.w
          continue
      result.add g.selectRect


proc pickGlyphAt*(layout: seq[GlyphPosition], pos: Vec2): GlyphPosition =
  ## Given X,Y cordiante, return the GlyphPosition picked
  for g in layout:
    if g.selectRect.intersects(pos):
      return g