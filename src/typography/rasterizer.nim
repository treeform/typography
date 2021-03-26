import algorithm, bumpy, chroma, pixie, font, tables, vmath, opentype/parser

proc makeReady*(glyph: Glyph, font: Font) =
  ## Make sure the glyph is ready to render
  var typeface = font.typeface
  if glyph.ready:
    return

  if typeface.otf != nil and not glyph.isEmpty:
    glyph.parseGlyph(font)
  if glyph.pathStr.len > 0:
    glyph.glyphPathToCommands()
  if glyph.path.commands.len > 0:
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

proc getGlyphSize*(font: Font, glyph: Glyph): Vec2 =
  glyph.makeReady(font)
  var
    tx = floor(glyph.bboxMin.x * font.scale)
    ty = floor(glyph.bboxMin.y * font.scale)
    w = ceil(glyph.bboxMax.x * font.scale) - tx + 1
    h = ceil(glyph.bboxMax.y * font.scale) - ty + 1
  vec2(float32 w, float32 h)

proc getGlyphImage*(
    font: Font,
    glyph: Glyph,
    glyphOffset: var Vec2,
    quality = 4,
    subPixelShift: float32 = 0.0,
  ): Image =
  ## Get image for this glyph
  let white = ColorRgba(r: 255, g: 255, b: 255, a: 255)

  let
    size = getGlyphSize(font, glyph)
    w = max(int(size.x), 0)
    h = max(int(size.y), 0)
    tx = floor(glyph.bboxMin.x * font.scale)
    ty = floor(glyph.bboxMin.y * font.scale)
    origin = vec2(tx, ty)

  if w == 0 or h == 0:
    return newImage(1, 1)

  result = newImage(w, h)

  glyphOffset.x = origin.x
  glyphOffset.y = -float32(h) - origin.y

  proc trans(v: Vec2): Vec2 = (v + origin) / font.scale

  const ep = 0.0001 * PI

  proc scanLineHits(
    shapes: seq[seq[Segment]],
    hits: var seq[(float32, bool)],
    y: int,
    shiftY: float32
  ) =
    hits.setLen(0)
    var yLine = (float32(y) + ep) + shiftY
    var scan = Line(a: vec2(-10000, yLine), b: vec2(10000, yLine))

    scan.a = trans(scan.a)
    scan.b = trans(scan.b)

    for shape in shapes:
      for line in shape:
        var line2 = line
        if line2.at.y > line2.to.y: # Sort order doesn't actually matter
          swap(line2.at, line2.to)
        # Lines often connect and we need them to not share starts and ends
        var at: Vec2
        if line2.intersects(scan, at) and line2.to != at:
          let winding = line.at.y > line.to.y
          hits.add((at.x * font.scale - origin.x + subPixelShift, winding))

    hits.sort(proc(a, b: (float32, bool)): int = cmp(a[0], b[0]))

  var hits: seq[(float32, bool)]

  if quality == 0:
    for y in 0 ..< result.height:
      glyph.shapes.scanLineHits(hits, y, 0)
      if hits.len == 0:
        continue
      var
        pen: int16 = 0
        curHit = 0
      for x in 0 ..< result.width:
        while true:
          if curHit >= hits.len:
            break
          if x != hits[curHit][0].int:
            break
          let winding = hits[curHit][1]
          if winding == false:
            pen += 1
          else:
            pen -= 1
          inc curHit
        if pen != 0:
          result[x, h-y-1] = white
  else:
    var alphas = newSeq[float32](result.width)
    for y in 0 ..< result.height:
      for x in 0 ..< result.width:
        alphas[x] = 0
      for m in 0 ..< quality:
        glyph.shapes.scanLineHits(hits, y, float32(m)/float32(quality))
        if hits.len == 0:
          continue
        var
          penFill = 0.0
          curHit = 0
        for x in 0 ..< result.width:
          var penEdge = penFill
          while true:
            if curHit >= hits.len:
              break
            if x != hits[curHit][0].int:
              break
            let cover = hits[curHit][0] - x.float32
            let winding = hits[curHit][1]
            if winding == false:
              penFill += 1.0
              penEdge += 1.0 - cover
            else:
              penFill -= 1.0
              penEdge -= 1.0 - cover
            inc curHit
          alphas[x] += penEdge
      for x in 0 ..< result.width:
        var a = clamp(abs(alphas[x]) / float32(quality), 0.0, 1.0)
        var color = ColorRgba(r: 255, g: 255, b: 255, a: uint8(a * 255.0))
        result[x, h-y-1] = color

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
        result.strokeSegment(segment(flip(adjust(s.at)), flip(adjust(s.to))), red)
    if points:
      # Draw points.
      for ruleNum, c in glyph.path.commands:

        for i in 0..<c.numbers.len div 2:
          var at: Vec2
          at.x = c.numbers[i*2+0]
          at.y = c.numbers[i*2+1]
          result.strokeSegment(segment(
            flip(adjust(at)) + vec2(1, 1),
            flip(adjust(at)) + vec2(-1, -1)),
            blue
          )
          result.strokeSegment(segment(
            flip(adjust(at)) + vec2(-1, 1),
            flip(adjust(at)) + vec2(1, -1)),
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
          dir2 = dir(angle + float32(PI/2)) * 3
          winding = s.at.y > s.to.y
        var color = if winding: blue else: green

        if length > 0:
          # Triangle.
          let
            head = mid + dir
            left = mid - dir + dir2
            right = mid - dir - dir2
          result.strokeSegment(segment(head, left), color)
          result.strokeSegment(segment(left, right), color)
          result.strokeSegment(segment(right, head), color)

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
