import bumpy, tables, vmath, opentype/types, pixie/paths, sequtils

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
    commands*: seq[PathCommand]

  PathCommandKind* = enum
    ## Type of path commands
    Close,
    Move, Line, HLine, VLine, Cubic, SCubic, Quad, TQuad, Arc,
    RMove, RLine, RHLine, RVLine, RCubic, RSCubic, RQuad, RTQuad, RArc

  PathCommand* = object
    ## Binary version of an SVG command.
    kind*: PathCommandKind
    numbers*: seq[float32]

proc parameterCount(kind: PathCommandKind): int =
  ## Returns number of parameters a path command has.
  case kind:
  of Close: 0
  of Move, Line, RMove, RLine, TQuad, RTQuad: 2
  of HLine, VLine, RHLine, RVLine: 1
  of Cubic, RCubic: 6
  of SCubic, RSCubic, Quad, RQuad: 4
  of Arc, RArc: 7

proc commandsToShapes*(glyph: Glyph) =
  ## Converts SVG-like commands to shape made out of lines
  glyph.shapes = glyph.path.commandsToShapes(false, 1.0)
  for shape in glyph.shapes:
    glyph.segments.add(toSeq(shape.segments))
