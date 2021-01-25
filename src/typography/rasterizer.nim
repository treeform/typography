import algorithm, bumpy, chroma, pixie, font, tables, vmath, opentype/parser

proc line*(image: Image, at, to: Vec2, rgba: ColorRGBA) =
  ## Draws a line from one at vec to to vec.
  let
    dx = to.x - at.x
    dy = to.y - at.y
  var x = at.x
  while true:
    if dx == 0:
      break
    let y = at.y + dy * (x - at.x) / dx
    image[int x, int y] =  rgba
    if at.x < to.x:
      x += 1
      if x > to.x:
        break
    else:
      x -= 1
      if x < to.x:
        break

  var y = at.y
  while true:
    if dy == 0:
      break
    let x = at.x + dx * (y - at.y) / dy
    image[int x, int y] = rgba
    if at.y < to.y:
      y += 1
      if y > to.y:
        break
    else:
      y -= 1
      if y < to.y:
        break

proc makeReady*(glyph: Glyph, font: Font) =
  ## Make sure the glyph is ready to render
  var typeface = font.typeface
  if glyph.ready:
    return

  if typeface.otf != nil and glyph.path == nil:
    glyph.parseGlyph(font)
  if glyph.pathStr.len > 0:
    glyph.glyphPathToCommands()
  if glyph.path != nil and glyph.path.commands.len > 0:
    glyph.commandsToShapes()

    if glyph.shapes.len > 0 and glyph.shapes[0].len > 0:
      glyph.bboxMin = glyph.shapes[0][0].at
      glyph.bboxMax = glyph.shapes[0][0].at
      for shape in glyph.shapes:
        for s in shape:
          var at = s.at
          var to = s.to

          if at.x < glyph.bboxMin.x: glyph.bboxMin.x = at.x
          if at.y < glyph.bboxMin.y: glyph.bboxMin.y = at.y
          if at.x > glyph.bboxMax.x: glyph.bboxMax.x = at.x
          if at.y > glyph.bboxMax.y: glyph.bboxMax.y = at.y

          if to.x < glyph.bboxMin.x: glyph.bboxMin.x = to.x
          if to.y < glyph.bboxMin.y: glyph.bboxMin.y = to.y
          if to.x > glyph.bboxMax.x: glyph.bboxMax.x = to.x
          if to.y > glyph.bboxMax.y: glyph.bboxMax.y = to.y
    else:
      glyph.isEmpty = true
  else:
    glyph.isEmpty = true

  glyph.ready = true

proc getGlyphSize*(font: Font,glyph: Glyph): Vec2 =
  glyph.makeReady(font)
  var
    tx = floor(glyph.bboxMin.x * font.scale)
    ty = floor(glyph.bboxMin.y * font.scale)
    w = ceil(glyph.bboxMax.x * font.scale) - tx + 1
    h = ceil(glyph.bboxMax.y * font.scale) - ty + 1
  vec2(float32 w, float32 h)
import print
proc getGlyphImage*(
    font: Font,
    glyph: Glyph,
    glyphOffset: var Vec2,
    quality = 4,
    subPixelShift: float32 = 0.0,
  ): Image =
  ## Get image for this glyph
  const
    white = ColorRgba(r: 255, g: 255, b: 255, a: 255)
    whiteTrans = ColorRgba(r: 255, g: 255, b: 255, a: 0)

  let
    size = getGlyphSize(font, glyph)
    w = max(int(size.x), 0)
    h = max(int(size.y), 0)

  result = newImage(w, h)
  # TODO: Check, I don't think whiteTrans is needed with premultiplied alpha.
  result.fill(whiteTrans)

  if glyph.isEmpty or glyph.path == nil:
    return

  let lh = font.letterHeight.floor

  var mat = translate(vec2(0, lh)) *
    scale(vec2(font.scale, -font.scale))

  let
    bboxMin = mat * glyph.bboxMin
    bboxMax = mat * glyph.bboxMax
    offset = vec2(bboxMin.x - subPixelShift, bboxMax.y - 0.13)

  glyphOffset = vec2(bboxMin.x, bboxMax.y - lh).floor

  mat = translate(-offset) * mat

  result.fillPath(glyph.path, white, mat)

proc getGlyphOutlineImage*(
  font: Font,
  unicode: string,
  lines=true,
  points=true,
  winding=true
): Image =
  ## Get an outline of the glyph with controls points. Useful for debugging.
  var glyph = font.typeface.glyphs[unicode]

  const
    green = ColorRgba(r: 0, g: 255, b: 0, a: 255)
    red = ColorRgba(r: 255, g: 0, b: 0, a: 255)
    blue = ColorRgba(r: 0, g: 0, b: 255, a: 255)

  glyph.makeReady(font)

  var fontHeight = font.typeface.ascent - font.typeface.descent
  var scale = font.size / (fontHeight)
  var tx = int floor(glyph.bboxMin.x * scale)
  var ty = int floor(glyph.bboxMin.y * scale)
  var w = int(ceil(glyph.bboxMax.x * scale)) - tx + 1
  var h = int(ceil(glyph.bboxMax.y * scale)) - ty + 1

  result = newImage(w, h)
  let origin = vec2(float32 tx, float32 ty)

  proc adjust(v: Vec2): Vec2 = (v) * scale - origin

  proc flip(v: Vec2): Vec2 =
    result.x = v.x
    result.y = float32(h) - v.y

  # Draw the outline.
  for shape in glyph.shapes:
    if lines:
      # Draw lines.
      for s in shape:
        result.line(flip(adjust(s.at)), flip(adjust(s.to)), red)
    if points:
      # Draw points.
      for ruleNum, c in glyph.path.commands:

        for i in 0..<c.numbers.len div 2:
          var at: Vec2
          at.x = c.numbers[i*2+0]
          at.y = c.numbers[i*2+1]
          result.line(
            flip(adjust(at)) + vec2(1, 1),
            flip(adjust(at)) + vec2(-1, -1),
            blue
          )
          result.line(
            flip(adjust(at)) + vec2(-1, 1),
            flip(adjust(at)) + vec2(1, -1),
            blue
          )
    if winding:
      # Draw winding order
      for s in shape:
        let
          at = flip(adjust(s.at))
          to = flip(adjust(s.to))
          length = (at - to).length
          mid = (at + to) / 2
          angle = angle(at - to)
          dir = dir(angle) * 3
          dir2 = dir(angle + PI/2) * 3
          winding = s.at.y > s.to.y
        var color = if winding: blue else: green

        if length > 0:
          # Triangle.
          let
            head = mid + dir
            left = mid - dir + dir2
            right = mid - dir - dir2
          result.line(head, left, color)
          result.line(left, right, color)
          result.line(right, head, color)

proc getGlyphImage*(
  font: Font,
  unicode: string,
  glyphOffset: var Vec2,
  subPixelShift = 0.0
): Image =
  ## Get an image of the glyph and the glyph offset the image should be drawn
  var glyph = font.typeface.glyphs[unicode]
  font.getGlyphImage(glyph, glyphOffset)

proc getGlyphImage*(font: Font, unicode: string): Image =
  ## Get an image of the glyph
  var glyphOffset: Vec2
  font.getGlyphImage(unicode, glyphOffset)

proc drawGlyph*(font: Font, image: Image, at: Vec2, c: string) =
  ## Draw glyph at a location on the image
  var at = at
  at.y += font.lineHeight
  if c in font.typeface.glyphs:
    var glyph = font.typeface.glyphs[c]
    if glyph.shapes.len > 0:
      var origin = vec2(0, 0)
      var img = font.getGlyphImage(glyph, origin)
      image.draw(img, origin + at)

proc getGlyphImageOffset*(
  font: Font,
  glyph: Glyph,
  quality = 4,
  subPixelShift: float32 = 0.0,
): Vec2 =
  ## Get image for this glyph
  glyph.makeReady(font)
  var fontHeight = font.typeface.ascent - font.typeface.descent
  var scale = font.size / fontHeight
  var tx = int floor(glyph.bboxMin.x * scale)
  var ty = int floor(glyph.bboxMin.y * scale)
  #var w = int(ceil(glyph.bboxMax.x * scale)) - tx + 1
  var h = int(ceil(glyph.bboxMax.y * scale)) - ty + 1

  let origin = vec2(float32 tx, float32 ty)

  result.x = origin.x
  result.y = -float32(h) - origin.y

proc alphaToBlackAndWhite*(image: Image) =
  ## Typography deals mostly with transparent images with white text
  ## This is hard to see in tests so we convert it to white background
  ## with black text.
  for c in image.data.mitems:
    c.r = 255 - c.a
    c.g = 255 - c.a
    c.b = 255 - c.a
    c.a = 255
