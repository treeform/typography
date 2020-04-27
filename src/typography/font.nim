import streams, strutils, tables, vmath

type
  Segment* = object
    ## A math segment from point "at" to point "to"
    at*: Vec2
    to*: Vec2

  PathCommandKind* = enum
    ## Type of binary commands
    Start, Move, Line, HLine, VLine, Cubic, SCurve, Quad, TQuad, End
    RMove, RLine, RHLine, RVLine, RCubic, RSCurve, RQuad, RTQuad

  PathCommand* = object
    ## Binary version of an SVG command
    kind*: PathCommandKind
    numbers*: seq[float]

  Glyph* = ref object
    ## Contains information about Glyphs or "letters"
    ## SVG Path, command buffer, and shapes of lines.
    code*: string
    advance*: float
    commands*: seq[PathCommand]
    shapes*: seq[seq[Segment]] ## Shapes are made of lines.
    bboxMin*: Vec2
    bboxMax*: Vec2
    ready*: bool
    isEmpty*: bool
    numberOfContours*: int
    isComposite*: bool

    # SVG
    path*: string

    # TTF
    ttfStream*: Stream
    ttfOffset*: int

  Font* = ref object
    ## Main font object contains font information and Glyphs
    filename*: string
    name*: string
    bboxMin*: Vec2
    bboxMax*: Vec2
    advance*: float
    ascent*: float
    descent*: float
    xHeight*: float
    capHeight*: float
    unitsPerEm*: float
    lineGap*: float

    size*: float
    lineHeight*: float
    glyphs*: Table[string, Glyph]
    kerning*: Table[(string, string), float]
    glyphArr*: seq[Glyph]

proc `sizePt`*(font: Font): float =
  ## Gets font size in Pt or Point units.
  font.size * 0.75

proc `sizePt=`*(font: Font, sizePoints: float) =
  ## Sets font size in Pt or Point units.
  font.size = sizePoints / 0.75

proc `sizeEm`*(font: Font): float =
  ## Gets font size in em units.
  font.size / 12

proc `sizeEm=`*(font: Font, sizeEm: float) =
  ## Gets font size in em units.
  font.size = sizeEm * 12

proc `sizePr`*(font: Font): float =
  ## Gets font size in % or Percent units.
  font.size / 1200

proc `sizePr=`*(font: Font, sizePercent: float) =
  ## Gets font size in % or Percent units.
  font.size = sizePercent * 1200

proc intersects*(a, b: Segment, at: var Vec2): bool =
  ## Checks if the a segment intersects b segment.
  ## If it returns true, at will have point of intersection
  var s1_x, s1_y, s2_x, s2_y: float
  s1_x = a.to.x - a.at.x
  s1_y = a.to.y - a.at.y
  s2_x = b.to.x - b.at.x
  s2_y = b.to.y - b.at.y

  var s, t: float
  s = (-s1_y * (a.at.x - b.at.x) + s1_x * (a.at.y - b.at.y)) /
      (-s2_x * s1_y + s1_x * s2_y)
  t = (s2_x * (a.at.y - b.at.y) - s2_y * (a.at.x - b.at.x)) /
      (-s2_x * s1_y + s1_x * s2_y)

  if s >= 0 and s < 1 and t >= 0 and t < 1:
    at.x = a.at.x + (t * s1_x)
    at.y = a.at.y + (t * s1_y)
    return true
  return false

proc glyphPathToCommands*(glyph: Glyph) =
  ## Converts a glyph into lines-shape
  glyph.commands = newSeq[PathCommand]()

  var command = Start
  var number = ""
  var numbers = newSeq[float]()
  var commands = newSeq[PathCommand]()

  proc finishDigit() =
    if number.len > 0:
      numbers.add(parseFloat(number))
      number = ""

  proc finishCommand() =
    finishDigit()
    if command != Start:
      commands.add PathCommand(kind: command, numbers: numbers)
      numbers = newSeq[float]()

  for c in glyph.path:
    case c:
      of 'm':
        finishCommand()
        command = RMove
      of 'l':
        finishCommand()
        command = RLine
      of 'h':
        finishCommand()
        command = RHLine
      of 'v':
        finishCommand()
        command = RVLine
      of 'c':
        finishCommand()
        command = RCubic
      of 's':
        finishCommand()
        command = RSCurve
      of 'q':
        finishCommand()
        command = RQuad
      of 't':
        finishCommand()
        command = RTQuad
      of 'z':
        finishCommand()
        command = End

      of 'M':
        finishCommand()
        command = Move
      of 'L':
        finishCommand()
        command = Line
      of 'H':
        finishCommand()
        command = HLine
      of 'V':
        finishCommand()
        command = VLine
      of 'C':
        finishCommand()
        command = Cubic
      of 'S':
        finishCommand()
        command = SCurve
      of 'Q':
        finishCommand()
        command = Quad
      of 'T':
        finishCommand()
        command = TQuad
      of 'Z':
        finishCommand()
        command = End

      of ' ', ',':
        finishDigit()
      else:
        if command == Move and numbers.len == 2:
          finishCommand()
          command = Line
        elif command == Line and numbers.len == 2:
          finishCommand()
          command = Line
        number &= c

  finishCommand()

  glyph.commands = commands

proc commandsToShapes*(glyph: Glyph) =
  ## Converts SVG-like commands to shape made out of lines
  var lines = newSeq[Segment]()
  glyph.shapes = newSeq[seq[Segment]]()
  var start, at, to, ctr, ctr2: Vec2
  var prevCommand: PathCommandKind

  proc drawLine(at, to: Vec2) =
    if at - to != vec2(0, 0):
      # Don't add any 0 length lines.
      lines.add(Segment(at: at, to: to))

  proc getCurvePoint(points: seq[Vec2], t: float): Vec2 =
    if points.len == 1:
      return points[0]
    else:
      var newPoints = newSeq[Vec2](points.len - 1)
      for i in 0 ..< newPoints.len:
        newPoints[i] = points[i] * (1-t) + points[i + 1] * t
      return getCurvePoint(newPoints, t)

  proc drawCurve(points: seq[Vec2]) =
    let n = 10
    var a = at
    for t in 1..n:
      var b = getCurvePoint(points, float(t) / float(n))
      drawLine(a, b)
      a = b

  proc drawQuad(p0, p1, p2: Vec2) =
    let devx = p0.x - 2.0 * p1.x + p2.x
    let devy = p0.y - 2.0 * p1.y + p2.y
    let devsq = devx * devx + devy * devy
    if devsq < 0.333:
      drawLine(p0, p2)
      return
    let tol = 3.0
    let n = 1 + (tol * (devsq)).sqrt().sqrt().floor()
    var p = p0
    let nrecip = 1 / n
    var t = 0.0
    for i in 0 ..< int(n):
      t += nrecip
      let pn = lerp(lerp(p0, p1, t), lerp(p1, p2, t), t)
      drawLine(p, pn)
      p = pn

    drawLine(p, p2)

  for command in glyph.commands:
    case command.kind
      of Move:
        assert command.numbers.len == 2
        at.x = command.numbers[0]
        at.y = command.numbers[1]
        start = at

      of Line:
        assert command.numbers.len == 2
        to.x = command.numbers[0]
        to.y = command.numbers[1]
        drawLine(at, to)
        at = to

      of VLine:
        assert command.numbers.len == 1
        to.x = at.x
        to.y = command.numbers[0]
        drawLine(at, to)
        at = to

      of HLine:
        assert command.numbers.len == 1
        to.x = command.numbers[0]
        to.y = at.y
        drawLine(at, to)
        at = to

      of Quad:
        assert command.numbers.len mod 4 == 0
        var i = 0
        while i < command.numbers.len:
          ctr.x = command.numbers[i+0]
          ctr.y = command.numbers[i+1]
          to.x = command.numbers[i+2]
          to.y = command.numbers[i+3]

          drawQuad(at, ctr, to)
          at = to
          i += 4

      of TQuad:
        if prevCommand != Quad and prevCommand != TQuad:
          ctr = at
        assert command.numbers.len == 2
        to.x = command.numbers[0]
        to.y = command.numbers[1]
        ctr = at - (ctr - at)
        drawQuad(at, ctr, to)
        at = to

      of Cubic:
        assert command.numbers.len == 6
        ctr.x = command.numbers[0]
        ctr.y = command.numbers[1]
        ctr2.x = command.numbers[2]
        ctr2.y = command.numbers[3]
        to.x = command.numbers[4]
        to.y = command.numbers[5]
        drawCurve(@[at, ctr, ctr2, to])
        at = to

      of End:
        assert command.numbers.len == 0
        if prevCommand == Quad or prevCommand == TQuad:
          if at != start:
            drawQuad(at, ctr, start)
        else:
          drawLine(at, start)
        at = start
        glyph.shapes.add(lines)
        lines = newSeq[Segment]()

      of RMove:
        assert command.numbers.len == 2
        at.x += command.numbers[0]
        at.y += command.numbers[1]
        start = at

      of RLine:
        assert command.numbers.len == 2
        to.x = at.x + command.numbers[0]
        to.y = at.y + command.numbers[1]
        drawLine(at, to)
        at = to

      of RVLine:
        assert command.numbers.len == 1
        to.x = at.x
        to.y = at.y + command.numbers[0]
        drawLine(at, to)
        at = to

      of RHLine:
        assert command.numbers.len == 1
        to.x = at.x + command.numbers[0]
        to.y = at.y
        drawLine(at, to)
        at = to

      of RQuad:
        assert command.numbers.len == 4
        ctr.x = at.x + command.numbers[0]
        ctr.y = at.y + command.numbers[1]
        to.x = at.x + command.numbers[2]
        to.y = at.y + command.numbers[3]
        drawQuad(at, ctr, to)
        at = to

      of RTQuad:
        if prevCommand != RQuad and prevCommand != RTQuad:
          ctr = at
        assert command.numbers.len == 2
        to.x = at.x + command.numbers[0]
        to.y = at.y + command.numbers[1]
        ctr = at - (ctr - at)
        drawQuad(at, ctr, to)
        at = to

      of RCubic:
        assert command.numbers.len == 6
        ctr.x = at.x + command.numbers[0]
        ctr.y = at.y + command.numbers[1]
        ctr2.x = at.x + command.numbers[2]
        ctr2.y = at.y + command.numbers[3]
        to.x = at.x + command.numbers[4]
        to.y = at.y + command.numbers[5]
        drawCurve(@[at, ctr, ctr2, to])
        at = to

      of RSCurve:
        assert command.numbers.len == 4
        ctr = at - (ctr2 - at)
        ctr2.x = at.x + command.numbers[0]
        ctr2.y = at.y + command.numbers[1]
        to.x = at.x + command.numbers[2]
        to.y = at.y + command.numbers[3]
        drawCurve(@[at, ctr, ctr2, to])
        at = to

      else:
        raise newException(ValueError, "not supported path command " & $command)

    prevCommand = command.kind
