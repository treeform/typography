import algorithm, chroma, flippy, font, tables, vmath, opentype/parser

proc makeReady*(glyph: Glyph, font: Font) =
  ## Make sure the glyph is ready to render

  if glyph.ready:
    return

  if font.otf != nil and glyph.commands.len == 0:
    glyph.parseGlyph(font)
  if glyph.path.len > 0:
    glyph.glyphPathToCommands()
  if glyph.commands.len > 0:
    glyph.commandsToShapes()

    if glyph.shapes[0].len > 0:
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

proc scale*(font: Font): float =
  font.size / font.unitsPerEm

proc getGlyphSize*(
    font: Font,
    glyph: Glyph
  ): Vec2 =

  glyph.makeReady(font)
  var
    tx = floor(glyph.bboxMin.x * font.scale)
    ty = floor(glyph.bboxMin.y * font.scale)
    w = ceil(glyph.bboxMax.x * font.scale) - tx + 1
    h = ceil(glyph.bboxMax.y * font.scale) - ty + 1

  return vec2(float w, float h)

proc getGlyphImage*(
    font: Font,
    glyph: Glyph,
    glyphOffset: var Vec2,
    quality = 4,
    subPixelShift: float = 0.0,
  ): Image =
  ## Get image for this glyph
  let
    white = ColorRgba(r: 255, g: 255, b: 255, a: 255)
    whiteTrans = ColorRgba(r: 255, g: 255, b: 255, a: 0)

  var
    size = getGlyphSize(font, glyph)
    w = int(size.x)
    h = int(size.y)
    tx = floor(glyph.bboxMin.x * font.scale)
    ty = floor(glyph.bboxMin.y * font.scale)

  var image = newImage(w, h, 4)
  image.fill(whiteTrans)
  let origin = vec2(tx, ty)

  glyphOffset.x = origin.x
  glyphOffset.y = -float(h) - origin.y

  proc trans(v: Vec2): Vec2 = (v + origin) / font.scale

  const ep = 0.0001 * PI

  proc scanLineHits(shapes: seq[seq[Segment]], y: int, shiftY: float): seq[(float, bool)] =
    var yLine = (float(y) + ep) + shiftY
    var scan = Segment(at: vec2(-10000, yLine), to: vec2(100000, yLine))

    scan.at = trans(scan.at)
    scan.to = trans(scan.to)

    for shape in shapes:
      for line in shape:
        var at: Vec2

        if line.intersects(scan, at):
          let winding = line.at.y > line.to.y
          result.add((at.x * font.scale - origin.x + subPixelShift, winding))

    result.sort(proc(a, b: (float, bool)): int = cmp(a[0], b[0]))

    if result.len mod 2 != 0:
      # echo "issue!", result.len
      return

  if quality == 0:
    for y in 0 ..< image.height:
      let hits = glyph.shapes.scanLineHits(y, 0)
      if hits.len == 0:
        continue
      var
        pen: int16 = 0
        curHit = 0
      for x in 0 ..< image.width:
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
          image.putRgba(x, h-y-1, white)
  else:
    for y in 0 ..< image.height:
      var alphas = newSeq[float](image.width)
      for m in 0 ..< quality:
        let hits = glyph.shapes.scanLineHits(y, float(m)/float(quality))
        if hits.len == 0:
          continue
        var
          penFill = 0.0
          curHit = 0
        for x in 0 ..< image.width:
          var penEdge = penFill
          while true:
            if curHit >= hits.len:
              break
            if x != hits[curHit][0].int:
              break
            let cover = hits[curHit][0] - x.float
            let winding = hits[curHit][1]
            if winding == false:
              penFill += 1.0
              penEdge += 1.0 - cover
            else:
              penFill -= 1.0
              penEdge -= 1.0 - cover
            inc curHit
          alphas[x] += penEdge
      for x in 0 ..< image.width:
        var a = clamp(abs(alphas[x]) / float(quality), 0.0, 1.0)
        var color = ColorRgba(r: 255, g: 255, b: 255, a: uint8(a * 255.0))
        image.putRgba(x, h-y-1, color)

  return image

proc getGlyphOutlineImage*(
  font: Font,
  unicode: string,
  lines=true,
  points=true,
  winding=true
): Image =
  ## Get an outline of the glyph with controls points. Useful for debugging.
  var glyph = font.glyphs[unicode]

  const
    green = ColorRgba(r: 0, g: 255, b: 0, a: 255)
    red = ColorRgba(r: 255, g: 0, b: 0, a: 255)
    blue = ColorRgba(r: 0, g: 0, b: 255, a: 255)

  glyph.makeReady(font)

  var fontHeight = font.ascent - font.descent
  var scale = font.size / (fontHeight)
  var tx = int floor(glyph.bboxMin.x * scale)
  var ty = int floor(glyph.bboxMin.y * scale)
  var w = int(ceil(glyph.bboxMax.x * scale)) - tx + 1
  var h = int(ceil(glyph.bboxMax.y * scale)) - ty + 1

  var image = newImage(w, h, 4)
  let origin = vec2(float tx, float ty)

  proc adjust(v: Vec2): Vec2 = (v) * scale - origin
  # Draw the outline.
  proc flip(v: Vec2): Vec2 =
    result.x = v.x
    result.y = float(h) - v.y
  for shape in glyph.shapes:

    if lines:
      # Draw lines.
      for s in shape:
        image.line(flip(adjust(s.at)), flip(adjust(s.to)), red)
    if points:
      # Draw points.
      for ruleNum, c in glyph.commands:

        for i in 0..<c.numbers.len div 2:
          var at: Vec2
          at.x = c.numbers[i*2+0]
          at.y = c.numbers[i*2+1]
          image.line(
            flip(adjust(at)) + vec2(1, 1),
            flip(adjust(at)) + vec2(-1, -1),
            blue
          )
          image.line(
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
          image.line(head, left, color)
          image.line(left, right, color)
          image.line(right, head, color)

  return image

proc getGlyphImage*(
  font: Font,
  unicode: string,
  glyphOffset: var Vec2,
  subPixelShift = 0.0
): Image =
  ## Get an image of the glyph and the glyph offset the image should be drawn
  var glyph = font.glyphs[unicode]
  return font.getGlyphImage(glyph, glyphOffset)

proc getGlyphImage*(font: Font, unicode: string): Image =
  ## Get an image of the glyph
  var glyphOffset: Vec2
  return font.getGlyphImage(unicode, glyphOffset)

proc drawGlyph*(font: Font, image: var Image, at: Vec2, c: string) =
  ## Draw glyph at a location on the image
  var at = at
  at.y += font.lineHeight
  if c in font.glyphs:
    var glyph = font.glyphs[c]
    if glyph.shapes.len > 0:
      var origin = vec2(0, 0)
      var img = font.getGlyphImage(glyph, origin)
      img.blit(
        image,
        rect(0, 0, float img.width, float img.height),
        rect(
          at.x + origin.x,
          at.y + origin.y,
          float img.width,
          float img.height
        )
      )

proc getGlyphImageOffset*(
  font: Font,
  glyph: Glyph,
  quality = 4,
  subPixelShift: float = 0.0,
): Vec2 =
  ## Get image for this glyph
  glyph.makeReady(font)
  var fontHeight = font.ascent - font.descent
  var scale = font.size / fontHeight
  var tx = int floor(glyph.bboxMin.x * scale)
  var ty = int floor(glyph.bboxMin.y * scale)
  #var w = int(ceil(glyph.bboxMax.x * scale)) - tx + 1
  var h = int(ceil(glyph.bboxMax.y * scale)) - ty + 1

  let origin = vec2(float tx, float ty)

  result.x = origin.x
  result.y = -float(h) - origin.y

proc alphaToBlankAndWhite*(image: var Image) =
  ## Typography deals mostly with transparent images with white text
  ## This is hard to see in tests so we convert it to white background
  ## with black text.
  for x in 0..<image.width:
    for y in 0..<image.height:
      var c = image.getrgba(x, y)
      c.r = uint8(255) - c.a
      c.g = uint8(255) - c.a
      c.b = uint8(255) - c.a
      c.a = 255
      image.putRgba(x, y, c)
