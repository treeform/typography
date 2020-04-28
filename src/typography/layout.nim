import flippy, font, rasterizer, tables, unicode, vmath

const
  normalLineHeight* = 0 # default line height of font.size * 1.2

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
    rect*: Rect       # Where to draw the image character
    selectRect*: Rect # Were to draw or hit selection
    character*: string
    rune*: Rune
    count*: int
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

proc kerningAdjustment*(font: Font, prev, c: string): float =
  ## Get Kerning Adjustment between two letters
  if prev != "":
    var key = (prev, c)
    if font.kerning.hasKey(key):
      var kerning = font.kerning[key]
      return kerning

proc canWrap(rune: Rune): bool =
  if rune == Rune(32): return true # early return for ascii space
  if rune.isWhiteSpace(): return true
  if not rune.isAlpha(): return true

proc typeset*(
    font: Font,
    runes: seq[Rune],
    pos: Vec2 = vec2(0, 0),
    size: Vec2 = vec2(0, 0),
    hAlign: HAlignMode = Left,
    vAlign: VAlignMode = Top,
    clip = true,
    tabWidth: float32 = 0.0
  ): seq[GlyphPosition] =
  ## Typeset runes and return glyph positions that is ready to draw

  assert font.size != 0
  assert font.unitsPerEm != 0

  result = @[]
  var
    at = pos
    lineStart = pos.x
    prev = ""
    scale = font.size / font.unitsPerEm
    #scale = font.size / (font.ascent - font.descent)
    boundsMin = vec2(0, 0)
    boundsMax = vec2(0, 0)
    glyphCount = 0
    tabWidth = tabWidth

  if tabWidth == 0.0:
    tabWidth = font.size * 4

  var
    strIndex = 0
    glyphIndex = 0
    lastCanWrap = 0
    lineHeight = font.lineHeight

  if lineHeight == normalLineHeight:
    lineHeight = font.size

  at.y += ceil(font.size / 2 + lineHeight / 2 + font.descent * scale)

  for rune in runes:
    var c = $rune
    if rune == Rune(10): # new line \n
      # add special small width glyph on this line
      var selectRect = rect(
        floor(at.x),
        floor(at.y) - font.size,
        font.glyphs[" "].advance * scale,
        lineHeight
      )
      result.add GlyphPosition(
        font: font,
        fontSize: font.size,
        subPixelShift: 0,
        rect: rect(0, 0, 0, 0),
        selectRect: selectRect,
        rune: rune,
        character: c,
        count: glyphCount,
        index: strIndex
      )
      prev = c
      inc glyphCount
      strIndex += c.len

      at.x = lineStart
      at.y += lineHeight
      continue
    elif rune == Rune(9): # tab \t
      at.x = ceil(at.x / tabWidth) * tabWidth
      continue

    if canWrap(rune):
      lastCanWrap = glyphIndex + 1

    if c notin font.glyphs:
      # TODO: make missing glyphs work better
      c = " " # if glyph is missing use space for now
      if c notin font.glyphs:
        ## Space is missing!?
        continue

    var glyph = font.glyphs[c]
    at.x += font.kerningAdjustment(prev, c) * scale

    var subPixelShift = at.x - floor(at.x)
    var glyphPos = vec2(floor(at.x), floor(at.y))
    var glyphSize = font.getGlyphSize(glyph)
    # if glyphSize.x == 0 or glyphSize.y == 0:
    #   echo "too small", c
    if rune == Rune(32):
      glyphSize.x = glyph.advance * scale

    if glyphSize.x != 0 and glyphSize.y != 0:
      # does it need to wrap?
      if size.x != 0 and at.x - pos.x + glyphSize.x > size.x:
        # wrap to next line
        let goBack = lastCanWrap - glyphIndex
        if lastCanWrap != -1 and goBack < 0:
          lastCanWrap = -1
          at.y += lineHeight
          if clip and size.y != 0 and at.y - pos.y > size.y:
            # delete glyphs that would wrap into next line that is clipped
            result.setLen(result.len + goBack)
            return

          # wrap glyphs on prev line down to next line
          let shift = result[result.len + goBack].rect.x - pos.x
          for i in result.len + goBack ..< result.len:
            result[i].rect.x -= shift
            result[i].rect.y += lineHeight
            result[i].selectRect.x -= shift
            result[i].selectRect.y += lineHeight

          at.x -= shift
        else:
          at.y += lineHeight
          at.x = lineStart

        glyphPos = vec2(floor(at.x), floor(at.y))

      if clip and size.y != 0 and at.y - pos.y > size.y:
        # reached the bottom of the area, clip
        return

    var selectRect = rect(
      floor(at.x),
      floor(at.y) - font.size,
      glyphSize.x + 1,
      lineHeight
    )

    result.add GlyphPosition(
      font: font,
      fontSize: font.size,
      subPixelShift: subPixelShift,
      rect: rect(glyphPos, glyphSize),
      selectRect: selectRect,
      character: c,
      rune: rune,
      count: glyphCount,
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
      boundsMax.y = max(boundsMax.y, at.y + font.size)
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
    let offset = floor(size.y - boundsSize.y + font.descent * scale)
    for pos in result.mitems:
      pos.rect.y += offset

  if vAlign == Middle:
    let offset = floor((size.y - boundsSize.y) / 2.0)
    for pos in result.mitems:
      pos.rect.y += offset

proc typeset*(
    font: Font,
    text: string,
    pos: Vec2 = vec2(0, 0),
    size: Vec2 = vec2(0, 0),
    hAlign: HAlignMode = Left,
    vAlign: VAlignMode = Top,
    clip = true,
    tabWidth: float32 = 0.0
  ): seq[GlyphPosition] =
  ## Typeset string and return glyph positions that is ready to draw
  typeset(font, toRunes(text), pos, size, hAlign, vAlign, clip, tabWidth)

proc drawText*(image: Image, layout: seq[GlyphPosition]) =
  ## Draws layout
  for pos in layout:
    var font = pos.font
    if pos.character in font.glyphs:
      var glyph = font.glyphs[pos.character]
      var glyphOffset: Vec2
      let img = font.getGlyphImage(
        glyph,
        glyphOffset,
        subPixelShift = pos.subPixelShift
      )
      image.blitWithAlpha(
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

proc drawText*(font: Font, image: Image, pos: Vec2, text: string) =
  ## Draw text string
  var layout = font.typeset(text, pos)
  image.drawText(layout)

proc getSelection*(layout: seq[GlyphPosition], start, stop: int): seq[Rect] =
  ## Given a layout gives selection from start to stop in glyph positions
  ## If start == stop returns []
  if start == stop:
    return
  for g in layout:
    if g.count >= start and g.count < stop:
      if result.len > 0:
        let onSameLine = result[^1].y == g.selectRect.y and result[^1].h == g.selectRect.h
        let notTooFar = g.selectRect.x - result[^1].x < result[^1].w * 2
        if onSameLine and notTooFar:
          result[^1].w = g.selectRect.x - result[^1].x + g.selectRect.w
          continue
      result.add g.selectRect

proc pickGlyphAt*(layout: seq[GlyphPosition], pos: Vec2): GlyphPosition =
  ## Given X,Y coordinate, return the GlyphPosition picked
  # direct click not happened find closest to the right
  var minG: GlyphPosition
  var minDist = -1.0
  for i, g in layout:
    if g.selectRect.y <= pos.y and pos.y < g.selectRect.y + g.selectRect.h:
      # on same line
      let dist = abs(pos.x - (g.selectRect.x))
      # closet character
      if minDist < 0 or dist < minDist:
        # min distance here
        minDist = dist
        minG = g
  return minG

proc textBounds*(layout: seq[GlyphPosition]): Vec2 =
  ## Given a layout, return the bounding rectangle.
  ## You can use this to get text width or height.
  for i, g in layout:
    result.x = max(result.x, g.selectRect.x + g.selectRect.w)
    result.y = max(result.y, g.selectRect.y + g.selectRect.h)

proc textBounds*(font: Font, text: string): Vec2 =
  ## Given a font and text, return the bounding rectangle.
  ## You can use this to get text width or height.
  var layout = font.typeset(text)
  return layout.textBounds()
