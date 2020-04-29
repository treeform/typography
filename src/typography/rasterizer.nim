import algorithm, chroma, flippy, font, tables, ttf, vmath, opentype/parser

proc makeReady*(glyph: Glyph, font: Font) =
  ## Make sure the glyph is ready to render

  if glyph.ready:
    return

  if glyph.otf != nil:
    glyph.parseGlyph(font)
  if glyph.path.len > 0:
    glyph.glyphPathToCommands()
  if glyph.commands.len > 0:
    glyph.commandsToShapes()

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

  glyph.ready = true

proc getGlyphSize*(
    font: Font,
    glyph: Glyph
  ): Vec2 =

  glyph.makeReady(font)
  var
    fontHeight = font.ascent - font.descent
    scale = font.size / fontHeight
    tx = floor(glyph.bboxMin.x * scale)
    ty = floor(glyph.bboxMin.y * scale)
    w = ceil(glyph.bboxMax.x * scale) - tx + 1
    h = ceil(glyph.bboxMax.y * scale) - ty + 1

  return vec2(float w, float h)
import print
proc getGlyphImage*(
    font: Font,
    glyph: Glyph,
    glyphOffset: var Vec2,
    quality = 4,
    subPixelShift: float = 0.0,
  ): Image =
  ## Get image for this glyph
  let white = ColorRgba(r: 255, g: 255, b: 255, a: 255)
  let clear = ColorRgba(r: 0, g: 0, b: 0, a: 0)

  var
    size = getGlyphSize(font, glyph)
    w = int(size.x)
    h = int(size.y)
    fontHeight = font.ascent - font.descent
    scale = font.size / fontHeight
    tx = floor(glyph.bboxMin.x * scale)
    ty = floor(glyph.bboxMin.y * scale)

  var image = newImage(w, h, 4)
  image.fill(ColorRgba(r: 255, g: 255, b: 255, a: 0))
  let origin = vec2(float tx, float ty)

  glyphOffset.x = origin.x
  glyphOffset.y = -float(h) - origin.y

  proc trans(v: Vec2): Vec2 = (v + origin) / scale

  const ep = 0.0001 * PI

  proc scanLineHits(shape: seq[Segment], y: int, shiftY: float): seq[(float, bool)] =
    var yLine = (float(y) + ep) + shiftY
    var scan = Segment(at: vec2(-10000, yLine), to: vec2(100000, yLine))

    scan.at = trans(scan.at)
    scan.to = trans(scan.to)

    for line in shape:
      var at: Vec2

      if line.intersects(scan, at):
        let winding = line.at.y > line.to.y
        result.add((at.x * scale - origin.x + subPixelShift, winding))

    result.sort(proc(a, b: (float, bool)): int = cmp(a[0], b[0]))

    if result.len mod 2 != 0:
      # echo "issue!", result.len
      return

  #print "here"
  for y in 0 ..< image.height:

    if quality == 0:
      var scanLine = newSeq[int16](image.width)
      for shapeNum, shape in glyph.shapes:
        # fill
        var winding: bool

        #print shapeNum, winding, shape.len

        let hits = shape.scanLineHits(y, 0)

        if hits.len > 0:
          winding = hits[0][1]
        var i = 0
        while i < hits.len:
          var at = hits[i][0]
          var to = hits[i+1][0]
          for j in int(at)+1..int(to)-1:
            #print j, h-y-1, image.width, image.height
            if winding == false:
              scanLine[j] += 1 #image.putRgba(j, h-y-1, white)
            else:
              scanLine[j] -= 1 # image.putRgba(j, h-y-1, clear)
          i += 2
        #print shapeNum, y, winding, scanLine

      #print y, scanLine
      for x in 0 ..< image.width:
        if scanLine[x] > 0:
          image.putRgba(x, h-y-1, white)

    else:
      var alphas = newSeq[float](image.width)
      for shapeNum, shape in glyph.shapes:
        # fill AA
        var winding: float

        for m in 0 ..< quality:
          let hits = shape.scanLineHits(y, float(m)/float(quality) - 1)

          if hits.len > 0:
            if hits[0][1]:
              winding = -1
            else:
              winding = 1

          var i = 0
          while i < hits.len:
            var at = hits[i][0]
            var to = hits[i+1][0]

            for j in int(at) + 1 .. int(to) - 1:
              alphas[j] += 1.0 * winding
            i += 2

            if int(at) == int(to):
              var a = (to - floor(to)) - (at - floor(at))
              assert a >= 0 and a <= 1.0
              alphas[int at] += a * winding

            else:
              block:
                var a = 1.0 - (at - floor(at))
                assert a <= 1.0
                alphas[int at] += a * winding

              block:
                var a = (to - floor(to))
                assert a <= 1.0
                alphas[int to] += a * winding

            #print shapeNum, y, winding, m, alphas
          #print shapeNum, y, winding, alphas

      # we could have an inverted fill
      var invert = -1.0
      for a in alphas:
        if a > 0:
          invert = 1.0
      #print invert

      for j in 0..<image.width:
        if alphas[j] != 0:
          var a = clamp(alphas[j] * invert / float(quality), 0.0, 1.0)
          var color = ColorRgba(r: 255, g: 255, b: 255, a: uint8(a*255.0))
          image.putRgba(j, h-y, color)
          # if winding == false:
          #   var alpha = uint8(a*255.0)
          #   var currentColor = image.getRgba(j, h-y)
          #   alpha = min(255, currentColor.a.int + alpha.int).uint8
          #   var color = ColorRgba(r: 255, g: 255, b: 255, a: alpha)
          #   image.putRgba(j, h-y, color)
          # if winding == true:
          #   var alphaN = -int(a*255.0)
          #   var currentColor = image.getRgba(j, h-y)
          #   var alpha = min(255, currentColor.a.int + alphaN).uint8
          #   var color = ColorRgba(r: 255, g: 255, b: 255, a: alpha)
          #   image.putRgba(j, h-y, color)

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
