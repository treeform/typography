import bumpy, tables, vmath, opentype/types, pixie/paths, sequtils, std/fenv

type
  Glyph* = ref object
    ## Contains information about Glyphs or "letters"
    ## SVG Path, command buffer, and shapes of lines.
    code*: string
    advance*: float32
    path*: Path
    shapes*: seq[seq[Vec2]]
    segments*: seq[seq[Segment]]
    bboxMin*: Vec2
    bboxMax*: Vec2
    ready*: bool
    isEmpty*: bool
    numberOfContours*: int
    isComposite*: bool
    index*: int
    pathStr*: string  # SVG

  Typeface* = ref object
    ## Main font object contains font information and Glyphs
    filename*: string
    name*: string
    bboxMin*: Vec2
    bboxMax*: Vec2
    advance*: float32
    ascent*: float32
    descent*: float32
    xHeight*: float32
    capHeight*: float32
    unitsPerEm*: float32
    lineGap*: float32
    glyphs*: Table[string, Glyph]
    kerning*: Table[(string, string), float32]
    glyphArr*: seq[Glyph]
    otf*: OTFFont

  Font* = ref object
    ## Contains size, weight and typeface.
    typeface*: Typeface
    size*: float32
    lineHeight*: float32
    weight*: float32

  TypographyError* = object of ValueError

proc `sizePt`*(font: Font): float32 =
  ## Gets font size in Pt or Point units.
  font.size * 0.75

proc `sizePt=`*(font: Font, sizePoints: float32) =
  ## Sets font size in Pt or Point units.
  font.size = sizePoints / 0.75

proc `sizeEm`*(font: Font): float32 =
  ## Gets font size in em units.
  font.size / 12

proc `sizeEm=`*(font: Font, sizeEm: float32) =
  ## Gets font size in em units.
  font.size = sizeEm * 12

proc `sizePr`*(font: Font): float32 =
  ## Gets font size in % or Percent units.
  font.size / 1200

proc `sizePr=`*(font: Font, sizePercent: float32) =
  ## Gets font size in % or Percent units.
  font.size = sizePercent * 1200

proc scale*(font: Font): float32 =
  ## Gets the internal scaling of font units to pixles.
  font.size / font.typeface.unitsPerEm

proc letterHeight*(font: Font): float32 =
  ## Gets the current letter height based on ascent and descent and the current
  ## size and lineheight.
  (font.typeface.ascent - font.typeface.descent) * font.scale

proc baseline*(font: Font): float32 =
  ## Gets the baseline of the font based on current size and lineheight.
  font.lineHeight / 2 - font.size / 2 + (font.size - font.letterHeight) / 2 +
    font.typeface.ascent * font.scale

proc capline*(font: Font): float32 =
  ## Gets the current capline of the font based on current size and lineheight.
  font.baseline - font.typeface.capHeight * font.scale

proc glyphPathToCommands*(glyph: Glyph) =
  ## Converts a glyph into lines-shape
  glyph.path = parsePath(glyph.pathStr)

type
  PathShim* = ref object
    ## Used to hold paths and create paths.
    commands: seq[float32]
    start, at: Vec2 # Maintained by moveTo, lineTo, etc. Used by arcTo.

  PathCommandKind = enum
    ## Type of path commands
    Close,
    Move, Line, HLine, VLine, Cubic, SCubic, Quad, TQuad, Arc,
    RMove, RLine, RHLine, RVLine, RCubic, RSCubic, RQuad, RTQuad, RArc

proc parameterCount(kind: PathCommandKind): int =
  ## Returns number of parameters a path command has.
  case kind:
  of Close: 0
  of Move, Line, RMove, RLine, TQuad, RTQuad: 2
  of HLine, VLine, RHLine, RVLine: 1
  of Cubic, RCubic: 6
  of SCubic, RSCubic, Quad, RQuad: 4
  of Arc, RArc: 7

proc commandsToShapes(
  path: Path, closeSubpaths: bool, pixelScale: float32
): seq[Polygon] =
  ## Converts SVG-like commands to sequences of vectors.
  var
    start, at: Vec2
    shape: Polygon

  # Some commands use data from the previous command
  var
    prevCommandKind = Move
    prevCtrl, prevCtrl2: Vec2

  let errorMarginSq = pow(0.2 / pixelScale, 2)

  proc addSegment(shape: var Polygon, at, to: Vec2) =
    # Don't add any 0 length lines
    if at - to != vec2(0, 0):
      # Don't double up points
      if shape.len == 0 or shape[^1] != at:
        shape.add(at)
      shape.add(to)

  proc addCubic(shape: var Polygon, at, ctrl1, ctrl2, to: Vec2) =
    ## Adds cubic segments to shape.
    proc compute(at, ctrl1, ctrl2, to: Vec2, t: float32): Vec2 {.inline.} =
      let
        t2 = t*t
        t3 = t2*t
      at * (-t3 + 3*t2 - 3*t + 1) +
      ctrl1 * (3*t3 - 6*t2 + 3*t) +
      ctrl2 * (-3*t3 + 3*t2) +
      to * (t3)

    proc computeDeriv(at, ctrl1, ctrl2, to: Vec2, t: float32): Vec2 {.inline.} =
      let t2 = t*t
      at * (-3*t2 + 6*t - 3) +
      ctrl1 * (9*t2 - 12*t + 3) +
      ctrl2 * (-9*t2 + 6*t) +
      to * (3 * t2)

    var
      t: float32       # Where we are at on the curve from [0, 1]
      step = 1.float32 # How far we want to try to move along the curve
      prev = at
      next = compute(at, ctrl1, ctrl2, to, t + step)
      halfway = compute(at, ctrl1, ctrl2, to, t + step / 2)
    while true:
      if step <= epsilon(float32):
        raise newException(TypographyError, "Unable to discretize cubic")
      let
        midpoint = (prev + next) / 2
        lineTangent = midpoint - prev
        curveTangent = computeDeriv(at, ctrl1, ctrl2, to, t + step / 2)
        curveTangentScaled = curveTangent.normalize() * lineTangent.length()
        error = (midpoint - halfway).lengthSq
        errorTangent = (lineTangent - curveTangentScaled).lengthSq
      if error + errorTangent > errorMarginSq:
        next = halfway
        halfway = compute(at, ctrl1, ctrl2, to, t + step / 4)
        step /= 2
      else:
        shape.addSegment(prev, next)
        t += step
        if t == 1:
          break
        prev = next
        step = min(step * 2, 1 - t) # Optimistically attempt larger steps
        next = compute(at, ctrl1, ctrl2, to, t + step)
        halfway = compute(at, ctrl1, ctrl2, to, t + step / 2)

  proc addQuadratic(shape: var Polygon, at, ctrl, to: Vec2) =
    ## Adds quadratic segments to shape.
    proc compute(at, ctrl, to: Vec2, t: float32): Vec2 {.inline.} =
      let t2 = t*t
      at * (t2 - 2*t + 1) +
      ctrl * (-2*t2 + 2*t) +
      to * t2

    var
      t: float32       # Where we are at on the curve from [0, 1]
      step = 1.float32 # How far we want to try to move along the curve
      prev = at
      next = compute(at, ctrl, to, t + step)
      halfway = compute(at, ctrl, to, t + step / 2)
      halfStepping = false
    while true:
      if step <= epsilon(float32):
        raise newException(TypographyError, "Unable to discretize quadratic")
      let
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).lengthSq
      if error > errorMarginSq:
        next = halfway
        halfway = compute(at, ctrl, to, t + step / 4)
        halfStepping = true
        step /= 2
      else:
        shape.addSegment(prev, next)
        t += step
        if t == 1:
          break
        prev = next
        if halfStepping:
          step = min(step, 1 - t)
        else:
          step = min(step * 2, 1 - t) # Optimistically attempt larger steps
        next = compute(at, ctrl, to, t + step)
        halfway = compute(at, ctrl, to, t + step / 2)

  proc addArc(
    shape: var Polygon,
    at, radii: Vec2,
    rotation: float32,
    large, sweep: bool,
    to: Vec2
  ) =
    ## Adds arc segments to shape.
    type ArcParams = object
      radii: Vec2
      rotMat: Mat3
      center: Vec2
      theta, delta: float32

    proc endpointToCenterArcParams(
      at, radii: Vec2, rotation: float32, large, sweep: bool, to: Vec2
    ): ArcParams =
      var
        radii = vec2(abs(radii.x), abs(radii.y))
        radiiSq = vec2(radii.x * radii.x, radii.y * radii.y)

      let
        radians: float32 = rotation / 180 * PI
        d = vec2((at.x - to.x) / 2.0, (at.y - to.y) / 2.0)
        p = vec2(
          cos(radians) * d.x + sin(radians) * d.y,
          -sin(radians) * d.x + cos(radians) * d.y
        )
        pSq = vec2(p.x * p.x, p.y * p.y)

      let cr = pSq.x / radiiSq.x + pSq.y / radiiSq.y
      if cr > 1:
        radii *= sqrt(cr)
        radiiSq = vec2(radii.x * radii.x, radii.y * radii.y)

      let
        dq = radiiSq.x * pSq.y + radiiSq.y * pSq.x
        pq = (radiiSq.x * radiiSq.y - dq) / dq

      var q = sqrt(max(0, pq))
      if large == sweep:
        q = -q

      proc svgAngle(u, v: Vec2): float32 =
        let
          dot = dot(u, v)
          len = length(u) * length(v)
        result = arccos(clamp(dot / len, -1, 1))
        if (u.x * v.y - u.y * v.x) < 0:
          result = -result

      let
        cp = vec2(q * radii.x * p.y / radii.y, -q * radii.y * p.x / radii.x)
        center = vec2(
          cos(radians) * cp.x - sin(radians) * cp.y + (at.x + to.x) / 2,
          sin(radians) * cp.x + cos(radians) * cp.y + (at.y + to.y) / 2
        )
        theta = svgAngle(vec2(1, 0), vec2((p.x-cp.x) / radii.x, (p.y - cp.y) / radii.y))

      var delta = svgAngle(
          vec2((p.x - cp.x) / radii.x, (p.y - cp.y) / radii.y),
          vec2((-p.x - cp.x) / radii.x, (-p.y - cp.y) / radii.y)
        )
      delta = delta mod (PI * 2)

      if sweep and delta < 0:
        delta += 2 * PI
      elif not sweep and delta > 0:
        delta -= 2 * PI

      # Normalize the delta
      while delta > PI * 2:
        delta -= PI * 2
      while delta < -PI * 2:
        delta += PI * 2

      ArcParams(
        radii: radii,
        rotMat: rotate(-radians),
        center: center,
        theta: theta,
        delta: delta
      )

    proc compute(arc: ArcParams, a: float32): Vec2 =
      result = vec2(cos(a) * arc.radii.x, sin(a) * arc.radii.y)
      result = arc.rotMat * result + arc.center

    let arc = endpointToCenterArcParams(at, radii, rotation, large, sweep, to)

    var
      t: float32       # Where we are at on the curve from [0, 1]
      step = 1.float32 # How far we want to try to move along the curve
      prev = at
    while t != 1:
      if step <= epsilon(float32):
        raise newException(TypographyError, "Unable to discretize arc")
      let
        aPrev = arc.theta + arc.delta * t
        a = arc.theta + arc.delta * (t + step)
        next = arc.compute(a)
        halfway = arc.compute(aPrev + (a - aPrev) / 2)
        midpoint = (prev + next) / 2
        error = (midpoint - halfway).lengthSq
      if error > errorMarginSq:
        let
          quarterway = arc.compute(aPrev + (a - aPrev) / 4)
          midpoint = (prev + halfway) / 2
          halfwayError = (midpoint - quarterway).lengthSq
        if halfwayError < errorMarginSq:
          shape.addSegment(prev, halfway)
          prev = halfway
          t += step / 2
          step = min(step / 2, 1 - t) # Assume next steps hould be the same size
        else:
          step = step / 4 # We know a half-step is too big
      else:
        shape.addSegment(prev, next)
        prev = next
        t += step
        step = min(step * 2, 1 - t) # Optimistically attempt larger steps

  let path = cast[PathShim](path)

  var i: int
  while i < path.commands.len:
    let kind = path.commands[i].PathCommandKind
    inc i

    case kind:
    of Move:
      if shape.len > 0:
        if closeSubpaths:
          shape.addSegment(at, start)
        result.add(shape)
        shape = newSeq[Vec2]()
      at.x = path.commands[i + 0]
      at.y = path.commands[i + 1]
      start = at

    of Line:
      let to = vec2(path.commands[i + 0], path.commands[i + 1])
      shape.addSegment(at, to)
      at = to

    of HLine:
      let to = vec2(path.commands[i + 0], at.y)
      shape.addSegment(at, to)
      at = to

    of VLine:
      let to = vec2(at.x, path.commands[i + 0])
      shape.addSegment(at, to)
      at = to

    of Cubic:
      let
        ctrl1 = vec2(path.commands[i + 0], path.commands[i + 1])
        ctrl2 = vec2(path.commands[i + 2], path.commands[i + 3])
        to = vec2(path.commands[i + 4], path.commands[i + 5])
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of SCubic:
      let
        ctrl2 = vec2(path.commands[i + 0], path.commands[i + 1])
        to = vec2(path.commands[i + 2], path.commands[i + 3])
      if prevCommandKind in {Cubic, SCubic, RCubic, RSCubic}:
        let ctrl1 = at * 2 - prevCtrl2
        shape.addCubic(at, ctrl1, ctrl2, to)
      else:
        shape.addCubic(at, at, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of Quad:
      let
        ctrl = vec2(path.commands[i + 0], path.commands[i + 1])
        to = vec2(path.commands[i + 2], path.commands[i + 3])
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of TQuad:
      let
        to = vec2(path.commands[i + 0], path.commands[i + 1])
        ctrl =
          if prevCommandKind in {Quad, TQuad, RQuad, RTQuad}:
            at * 2 - prevCtrl
          else:
            at
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of Arc:
      let
        radii = vec2(path.commands[i + 0], path.commands[i + 1])
        rotation = path.commands[i + 2]
        large = path.commands[i + 3] == 1
        sweep = path.commands[i + 4] == 1
        to = vec2(path.commands[i + 5], path.commands[i + 6])
      shape.addArc(at, radii, rotation, large, sweep, to)
      at = to

    of RMove:
      if shape.len > 0:
        result.add(shape)
        shape = newSeq[Vec2]()
      at.x += path.commands[i + 0]
      at.y += path.commands[i + 1]
      start = at

    of RLine:
      let to = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
      shape.addSegment(at, to)
      at = to

    of RHLine:
      let to = vec2(at.x + path.commands[i + 0], at.y)
      shape.addSegment(at, to)
      at = to

    of RVLine:
      let to = vec2(at.x, at.y + path.commands[i + 0])
      shape.addSegment(at, to)
      at = to

    of RCubic:
      let
        ctrl1 = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        ctrl2 = vec2(at.x + path.commands[i + 2], at.y + path.commands[i + 3])
        to = vec2(at.x + path.commands[i + 4], at.y + path.commands[i + 5])
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of RSCubic:
      let
        ctrl2 = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        to = vec2(at.x + path.commands[i + 2], at.y + path.commands[i + 3])
        ctrl1 =
          if prevCommandKind in {Cubic, SCubic, RCubic, RSCubic}:
            at * 2 - prevCtrl2
          else:
            at
      shape.addCubic(at, ctrl1, ctrl2, to)
      at = to
      prevCtrl2 = ctrl2

    of RQuad:
      let
        ctrl = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        to = vec2(at.x + path.commands[i + 2], at.y + path.commands[i + 3])
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of RTQuad:
      let
        to = vec2(at.x + path.commands[i + 0], at.y + path.commands[i + 1])
        ctrl =
          if prevCommandKind in {Quad, TQuad, RQuad, RTQuad}:
            at * 2 - prevCtrl
          else:
            at
      shape.addQuadratic(at, ctrl, to)
      at = to
      prevCtrl = ctrl

    of RArc:
      let
        radii = vec2(path.commands[i + 0], path.commands[i + 1])
        rotation = path.commands[i + 2]
        large = path.commands[i + 3] == 1
        sweep = path.commands[i + 4] == 1
        to = vec2(at.x + path.commands[i + 5], at.y + path.commands[i + 6])
      shape.addArc(at, radii, rotation, large, sweep, to)
      at = to

    of Close:
      if at != start:
        shape.addSegment(at, start)
        at = start
      if shape.len > 0:
        result.add(shape)
        shape = newSeq[Vec2]()

    i += kind.parameterCount()
    prevCommandKind = kind

  if shape.len > 0:
    if closeSubpaths:
      shape.addSegment(at, start)
    result.add(shape)

proc commandsToShapes*(glyph: Glyph) =
  ## Converts SVG-like commands to shape made out of lines
  glyph.shapes = glyph.path.commandsToShapes(false, 1.0)
  for shape in glyph.shapes:
    glyph.segments.add(toSeq(shape.segments))
