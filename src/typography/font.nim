import bumpy, tables, vmath, opentype/types, pixie/paths, sequtils

type
  Glyph* = ref object
    ## Contains information about Glyphs or "letters"
    ## SVG Path, command buffer, and shapes of lines.
    code*: string
    advance*: float32
    path*: Path
    shapes*: seq[seq[Segment]] ## Shapes are made of lines.
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

proc commandsToShapes*(glyph: Glyph) =
  ## Converts SVG-like commands to shape made out of lines
  let shapes = glyph.path.commandsToShapes()
  for shape in shapes:
    glyph.shapes.add(toSeq(shape.segments))
