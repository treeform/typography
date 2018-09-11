import algorithm, tables
import flippy, vmath, chroma, print
import font, ttf


proc makeReady*(glyph: var Glyph) =
  ## Make sure the glyph is ready to render

  if glyph.ready:
    return

  if glyph.ttfStream != nil:
    #perfBegin "ttfGlyphToCommands"
    glyph.ttfGlyphToCommands()
    #perfEnd()

  if glyph.path.len > 0:
    #perfBegin "glyphPathToCommands"
    glyph.glyphPathToCommands()
    #perfEnd()

  if glyph.commands.len > 0:
    #perfBegin "commandsToShapes"
    glyph.commandsToShapes()
    #perfEnd()

    glyph.bboxMin = glyph.lines[0].at
    glyph.bboxMax = glyph.lines[0].at

    for s in glyph.lines:
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
    font: var Font,
    glyph: var Glyph
  ): Vec2 =

  glyph.makeReady()
  var
    fontHeight = font.ascent - font.descent
    scale = font.size / fontHeight
    tx = floor(glyph.bboxMin.x * scale)
    ty = floor(glyph.bboxMin.y * scale)
    w = ceil(glyph.bboxMax.x * scale) - tx + 1
    h = ceil(glyph.bboxMax.y * scale) - ty + 1

  return vec2(float w, float h)

proc getGlyphImage*(
    font: var Font,
    glyph: var Glyph,
    glyphOffset: var Vec2,
    quality = 4,
    subPixelShift: float = 0.0,
  ): Image =
  ## Get image for this glyph
  let white = ColorRgba(r:255, g:255, b:255, a:255)

  var
    size = getGlyphSize(font, glyph)
    w = int(size.x)
    h = int(size.y)
    fontHeight = font.ascent - font.descent
    scale = font.size / fontHeight
    tx = floor(glyph.bboxMin.x * scale)
    ty = floor(glyph.bboxMin.y * scale)

  var image = newImage(w, h, 4)
  image.fill(ColorRgba(r:255, g:255, b:255, a:0))
  let origin = vec2(float tx, float ty)

  glyphOffset.x = origin.x
  glyphOffset.y = -float(h) - origin.y

  proc trans(v: Vec2): Vec2 = (v + origin) / scale

  const ep = 0.0001 * PI

  if quality == 0:
    # fill
    for y in 0..<image.height:
      var scan = Segment(at: vec2(-10000, float(y) + ep), to: vec2(100000, float(y) + ep))

      scan.at = trans(scan.at)
      scan.to = trans(scan.to)

      var hits = newSeq[float]()
      for line in glyph.lines:
        var at: Vec2
        if line.intersects(scan, at):
          hits.add(at.x * scale - origin.x)

      hits.sort(system.cmp)

      if hits.len mod 2 != 0:
        #echo "issue!", hits
        continue

      var i = 0
      while i < hits.len:
        var at = hits[i]
        var to = hits[i+1]

        for j in int(at)+1..int(to)-1:
          image.putRgba(j, h-y, white)
        i += 2

  else:
    # fill AA
    for y in 1..image.height:
      var alphas = newSeq[float](image.width)
      for m in 0..<quality:
        var yline = (float(y) + ep) + float(m)/float(quality) - 1
        var scan = Segment(at: vec2(-10000, yline), to: vec2(100000, yline))

        scan.at = trans(scan.at)
        scan.to = trans(scan.to)

        var hits = newSeq[float]()
        for line in glyph.lines:
          var at: Vec2

          if line.intersects(scan, at):
            hits.add(at.x * scale - origin.x + subPixelShift)

        hits.sort(system.cmp)

        if hits.len mod 2 != 0:
          #echo "issue!", hits
          continue

        var i = 0
        while i < hits.len:
          var at = hits[i]
          var to = hits[i+1]

          for j in int(at)+1..int(to)-1:
            alphas[j] += 1.0
          i += 2

          if int(at) == int(to):
            var a = (to - floor(to)) - (at - floor(at))
            assert a >= 0 and a <= 1.0
            alphas[int at] += a

          else:
            block:
              var a = 1.0 - (at - floor(at))
              assert a <= 1.0
              alphas[int at] += a

            block:
              var a = (to - floor(to))
              assert a <= 1.0
              alphas[int to] += a

      for j in 0..<image.width:
        if alphas[j] != 0:
          var a = alphas[j]/float(quality)
          if a > 1.0:
            a = 1.0
          var alpha = uint8(a*255.0)
          var color = ColorRgba(r:255, g:255, b:255, a:alpha)
          image.putRgba(j, h-y, color)

  return image

proc getGlyphOutlineImage*(font: var Font, unicode: string): Image =
  ## Get an outine of the glyph with contorls points. Useful for debugging.
  var glyph = font.glyphs[unicode]

  glyph.makeReady()

  var fontHeight = font.ascent - font.descent
  var scale = font.size / (fontHeight)
  var tx = int floor(glyph.bboxMin.x * scale)
  var ty = int floor(glyph.bboxMin.y * scale)
  var w = int(ceil(glyph.bboxMax.x * scale)) - tx + 1
  var h = int(ceil(glyph.bboxMax.y * scale)) - ty + 1

  var image = newImage(w, h, 4)
  let origin = vec2(float tx, float ty)

  proc atrans(v: Vec2): Vec2 = (v) * scale - origin
  # draw outline
  proc flip(v: Vec2): Vec2 =
    result.x = v.x
    result.y = float(h) - v.y
  for s in glyph.lines:
    var red = ColorRgba(r:255,g:0,b:0,a:255)
    image.line(flip(atrans(s.at)), flip(atrans(s.to)), red)
  # draw points
  for ruleNum, c in glyph.commands:
    var blue = ColorRgba(r:0,g:0,b:255,a:255)
    for i in 0..<c.numbers.len div 2:
      var at: Vec2
      at.x = c.numbers[i*2+0]
      at.y = c.numbers[i*2+1]
      image.line(flip(atrans(at)) + vec2(1,1), flip(atrans(at)) + vec2(-1,-1), blue)
      image.line(flip(atrans(at)) + vec2(-1,1), flip(atrans(at)) + vec2(1,-1), blue)

  return image


proc getGlyphImage*(font: var Font, unicode: string, glyphOffset: var Vec2, subPixelShift=0.0): Image =
  ## Get an image of the glyph and the glyph offset the image should be drawn
  var glyph = font.glyphs[unicode]
  return font.getGlyphImage(glyph, glyphOffset)


proc getGlyphImage*(font: var Font, unicode: string): Image =
  ## Get an image of the glyph
  var glyphOffset: Vec2
  return font.getGlyphImage(unicode, glyphOffset)


proc drawGlyph*(font: var Font, image: var Image, at: Vec2, c: string) =
  ## Draw glyph at a location on the image
  var at = at
  at.y += font.lineHeight
  if c in font.glyphs:
    var glyph = font.glyphs[c]
    if glyph.lines.len > 0:
      var origin = vec2(0, 0)
      var img = font.getGlyphImage(glyph, origin)
      img.blit(
        image,
        rect(0, 0, float img.width, float img.height),
        rect(at.x + origin.x, at.y + origin.y, float img.width, float img.height)
      )

proc getGlyphImageOffset*(
    font: var Font,
    glyph: var Glyph,
    quality = 4,
    subPixelShift: float = 0.0,
  ): Vec2 =
  ## Get image for this glyph
  glyph.makeReady()
  var fontHeight = font.ascent - font.descent
  var scale = font.size / fontHeight
  var tx = int floor(glyph.bboxMin.x * scale)
  var ty = int floor(glyph.bboxMin.y * scale)
  #var w = int(ceil(glyph.bboxMax.x * scale)) - tx + 1
  var h = int(ceil(glyph.bboxMax.y * scale)) - ty + 1

  let origin = vec2(float tx, float ty)

  result.x = origin.x
  result.y = -float(h) - origin.y