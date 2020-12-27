import ../font, os, tables, unicode, vmath, types, pixie/paths, flatty/binny

proc readUint16Seq(input: string, p, len: int): seq[uint16] =
  result = newSeq[uint16](len)
  for i in 0 ..< len:
    result[i] = input.readUint16(p + i * 2).swap()

proc readFixed32(input: string, p: int): float32 =
  ## Packed 32-bit value with major and minor version numbers.
  ceil(input.readInt32(p).swap().float32 / 65536.0 * 100000.0) / 100000.0

proc readFixed16(input: string, p: int): float32 =
  ## Reads 16-bit signed fixed number with the low 14 bits of fraction (2.14).
  input.readInt16(p).swap().float32 / 16384.0

proc readLongDateTime*(input: string, p: int): float64 =
  ## Date and time represented in number of seconds since 12:00 midnight,
  ## January 1, 1904, UTC.
  input.readInt64(p).swap().float64 - 2082844800

proc fromUtf16BE*(input: string): string =
  ## Converts UTF-16 to UTF-8.
  var pos: int
  while pos < input.len:
    let u1 = input.readUint16(pos).swap()
    pos += 2

    if u1 - 0xd800 >= 0x800'u16:
      result.add(Rune(u1.int32))
    else:
      let u2 = input.readUint16(pos).swap()
      pos += 2

      if ((u1 and 0xfc00) == 0xd800) and ((u2 and 0xfc00) == 0xdc00):
        result.add(Rune((u1.int32 shl 10) + u2.int32 - 0x35fdc00))
      else:
        # Error, produce tofu character.
        result.add("□")

proc readHeadTable(input: string, p: int): HeadTable =
  result = HeadTable()
  result.majorVersion = input.readUint16(p + 0).swap()
  assert result.majorVersion == 1
  result.minorVersion = input.readUint16(p + 2).swap()
  assert result.minorVersion == 0
  result.fontRevision = input.readFixed32(p + 4)
  result.checkSumAdjustment = input.readUint32(p + 8).swap()
  result.magicNumber = input.readUint32(p + 12).swap()
  result.flags = input.readUint16(p + 16).swap()
  result.unitsPerEm = input.readUint16(p + 18).swap()
  result.created = input.readLongDateTime(p + 20)
  result.modified = input.readLongDateTime(p + 28)
  result.xMin = input.readInt16(p + 36).swap()
  result.yMin = input.readInt16(p + 38).swap()
  result.xMax = input.readInt16(p + 40).swap()
  result.yMax = input.readInt16(p + 42).swap()
  result.macStyle = input.readUint16(p + 44).swap()
  result.lowestRecPPEM = input.readUint16(p + 46).swap()
  result.fontDirectionHint = input.readInt16(p + 48).swap()
  result.indexToLocFormat = input.readInt16(p + 50).swap()
  result.glyphDataFormat = input.readInt16(p + 52).swap()
  assert result.glyphDataFormat == 0

proc readNameTable*(input: string, p: int): NameTable =
  result = NameTable()
  result.format = input.readUint16(p + 0).swap()
  assert result.format == 0
  result.count = input.readUint16(p + 2).swap()
  result.stringOffset = input.readUint16(p + 4).swap()

  var p = p + 6
  let start = p

  for i in 0 ..< result.count.int:
    var record = NameRecord()
    record.platformID = input.readUint16(p + 0).swap()
    record.encodingID = input.readUint16(p + 2).swap()
    record.languageID = input.readUint16(p + 4).swap()
    record.nameID = input.readUint16(p + 6).swap()
    record.name = cast[NameTableNames](record.nameID)
    record.length = input.readUint16(p + 8).swap()
    record.offset = input.readUint16(p + 10).swap()

    p += 12

    record.text = input.readStr(
      start + result.stringOffset.int + record.offset.int,
      record.length.int
    )

    if record.platformID == 3 and record.encodingID == 1:
      # Windows UTF-16BE.
      record.text = record.text.fromUtf16BE()
    if record.platformID == 3 and record.encodingID == 0:
      # Windows UTF-16BE.
      record.text = record.text.fromUtf16BE()
    if record.encodingID == 1 and record.encodingID == 0:
      # Mac unicode.
      discard
    result.nameRecords.add(record)

proc readMaxpTable*(input: string, p: int): MaxpTable =
  result = MaxpTable()
  result.version = input.readFixed32(p + 0)
  result.numGlyphs = input.readUint16(p + 4).swap()
  result.maxPoints = input.readUint16(p + 6).swap()
  result.maxContours = input.readUint16(p + 8).swap()
  result.maxCompositePoints = input.readUint16(p + 10).swap()
  result.maxCompositeContours = input.readUint16(p + 12).swap()
  result.maxZones = input.readUint16(p + 14).swap()
  result.maxTwilightPoints = input.readUint16(p + 16).swap()
  result.maxStorage = input.readUint16(p + 18).swap()
  result.maxFunctionDefs = input.readUint16(p + 20).swap()
  result.maxInstructionDefs = input.readUint16(p + 22).swap()
  result.maxStackElements = input.readUint16(p + 24).swap()
  result.maxSizeOfInstructions = input.readUint16(p + 26).swap()
  result.maxComponentElements = input.readUint16(p + 28).swap()
  result.maxComponentDepth = input.readUint16(p + 30).swap()

proc readOS2Table*(input: string, p: int): OS2Table =
  result = OS2Table()
  result.version = input.readUint16(p + 0).swap()
  result.xAvgCharWidth = input.readInt16(p + 2).swap()
  result.usWeightClass = input.readUint16(p + 4).swap()
  result.usWidthClass = input.readUint16(p + 6).swap()
  result.fsType = input.readUint16(p + 8).swap()
  result.ySubscriptXSize = input.readInt16(p + 10).swap()
  result.ySubscriptYSize = input.readInt16(p + 12).swap()
  result.ySubscriptXOffset = input.readInt16(p + 14).swap()
  result.ySubscriptYOffset = input.readInt16(p + 16).swap()
  result.ySuperscriptXSize = input.readInt16(p + 18).swap()
  result.ySuperscriptYSize = input.readInt16(p + 20).swap()
  result.ySuperscriptXOffset = input.readInt16(p + 22).swap()
  result.ySuperscriptYOffset = input.readInt16(p + 24).swap()
  result.yStrikeoutSize = input.readInt16(p + 26).swap()
  result.yStrikeoutPosition = input.readInt16(p + 28).swap()
  result.sFamilyClass = input.readInt16(p + 30).swap()
  for i in 0 ..< 10:
    result.panose[i] = input.readUint8(p + 32 + i)
  result.ulUnicodeRange1 = input.readUint32(p + 42).swap()
  result.ulUnicodeRange2 = input.readUint32(p + 46).swap()
  result.ulUnicodeRange3 = input.readUint32(p + 50).swap()
  result.ulUnicodeRange4 = input.readUint32(p + 54).swap()
  result.achVendID = input.readStr(p + 58, 4)
  result.fsSelection = input.readUint16(p + 62).swap()
  result.usFirstCharIndex = input.readUint16(p + 64).swap()
  result.usLastCharIndex = input.readUint16(p + 66).swap()
  result.sTypoAscender = input.readInt16(p + 68).swap()
  result.sTypoDescender = input.readInt16(p + 70).swap()
  result.sTypoLineGap = input.readInt16(p + 72).swap()
  result.usWinAscent = input.readUint16(p + 74).swap()
  result.usWinDescent = input.readUint16(p + 76).swap()
  if result.version >= 1.uint16:
    result.ulCodePageRange1 = input.readUint32(p + 78).swap()
    result.ulCodePageRange2 = input.readUint32(p + 82).swap()
  if result.version >= 2.uint16:
    result.sxHeight = input.readInt16(p + 86).swap()
    result.sCapHeight = input.readInt16(p + 88).swap()
    result.usDefaultChar = input.readUint16(p + 90).swap()
    result.usBreakChar = input.readUint16(p + 92).swap()
    result.usMaxContext = input.readUint16(p + 94).swap()
  if result.version >= 5.uint16:
    result.usLowerOpticalPointSize = input.readUint16(p + 96).swap()
    result.usUpperOpticalPointSize = input.readUint16(p + 98).swap()

proc readLocaTable*(
  input: string, p: int, head: HeadTable, maxp: MaxpTable
): LocaTable =
  result = LocaTable()
  var p = p
  if head.indexToLocFormat == 0:
    # Uses uint16.
    for i in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(input.readUint16(p).swap().uint32 * 2)
      p += 2
  else:
    # Uses uint32.
    for i in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(input.readUint32(p).swap())
      p += 4

proc readHheaTable*(input: string, p: int): HheaTable =
  result = HheaTable()
  result.majorVersion = input.readUint16(p + 0).swap()
  assert result.majorVersion == 1
  result.minorVersion = input.readUint16(p + 2).swap()
  assert result.minorVersion == 0
  result.ascender = input.readInt16(p + 4).swap()
  result.descender = input.readInt16(p + 6).swap()
  result.lineGap = input.readInt16(p + 8).swap()
  result.advanceWidthMax = input.readUint16(p + 10).swap()
  result.minLeftSideBearing = input.readInt16(p + 12).swap()
  result.minRightSideBearing = input.readInt16(p + 14).swap()
  result.xMaxExtent = input.readInt16(p + 16).swap()
  result.caretSlopeRise = input.readInt16(p + 18).swap()
  result.caretSlopeRun = input.readInt16(p + 20).swap()
  result.caretOffset = input.readInt16(p + 22).swap()
  discard input.readUint16(p + 24).swap()
  discard input.readUint16(p + 26).swap()
  discard input.readUint16(p + 28).swap()
  discard input.readUint16(p + 30).swap()
  result.metricDataFormat = input.readInt16(p + 32).swap()
  assert result.metricDataFormat == 0
  result.numberOfHMetrics = input.readUint16(p + 34).swap()

proc readHmtxTable*(
  input: string, p: int, maxp: MaxpTable, hhea: HheaTable
): HmtxTable =
  result = HmtxTable()
  var p = p
  for i in 0 ..< maxp.numGlyphs.int:
    if i < hhea.numberOfHMetrics.int:
      var record = LongHorMetricRecrod()
      record.advanceWidth = input.readUint16(p + 0).swap()
      record.lsb = input.readInt16(p + 2).swap()
      result.hMetrics.add(record)
      p += 4
    else:
      result.leftSideBearings.add(input.readInt16(p + 0).swap())
      p += 2

proc readKernTable*(input: string, p: int): KernTable =
  result = KernTable()
  result.version = input.readUint16(p + 0).swap()
  var p = p
  if result.version == 0:
    # Windows format.
    result.nTables = input.readUint16(p + 2).swap()
    p += 4
    for i in 0 ..< result.nTables.int:
      var subTable = KernSubTable()
      subTable.version = input.readUint16(p + 0).swap()
      assert subTable.version == 0
      subTable.length = input.readUint16(p + 2).swap()
      subTable.coverage = input.readUint16(p + 4).swap()
      # TODO: check coverage
      subTable.numPairs = input.readUint16(p + 6).swap()
      subTable.searchRange = input.readUint16(p + 8).swap()
      subTable.entrySelector = input.readUint16(p + 10).swap()
      subTable.rangeShift = input.readUint16(p + 12).swap()
      p += 14
      for i in 0 ..< subTable.numPairs.int:
        var pair = KerningPair()
        pair.left = input.readUint16(p + 0).swap()
        pair.right = input.readUint16(p + 2).swap()
        pair.value = input.readInt16(p + 4).swap()
        subTable.kerningPairs.add(pair)
        p += 6
      result.subTables.add(subTable)
  elif result.version == 1:
    # Mac format.
    # TODO: add mac kern format
    discard
  else:
    assert false

proc readCmapTable*(input: string, p: int): CmapTable =
  let cmapOffset = p
  result = CmapTable()
  result.version = input.readUint16(p + 0).swap()
  result.numTables = input.readUint16(p + 2).swap()
  var p = p + 4
  for i in 0 ..< result.numTables.int:
    var record = EncodingRecord()
    record.platformID = input.readUint16(p + 0).swap()
    record.encodingID = input.readUint16(p + 2).swap()
    record.offset = input.readUint32(p + 4).swap()
    p += 8

    if record.platformID == 3:
      # Windows format unicode format.
      var p = cmapOffset + record.offset.int
      let format = input.readUint16(p + 0).swap()
      if format == 4:
        var subRecord = SegmentMapping()
        subRecord.format = format
        subRecord.length = input.readUint16(p + 2).swap()
        subRecord.language = input.readUint16(p + 4).swap()
        subRecord.segCountX2 = input.readUint16(p + 6).swap()
        let segCount = (subRecord.segCountX2 div 2).int
        subRecord.searchRange = input.readUint16(p + 8).swap()
        subRecord.entrySelector = input.readUint16(p + 10).swap()
        subRecord.rangeShift = input.readUint16(p + 12).swap()
        p += 14
        subRecord.endCode = input.readUint16Seq(p, segCount)
        p += segCount * 2
        subRecord.reservedPad = input.readUint16(p + 0).swap()
        p += 2
        subRecord.startCode = input.readUint16Seq(p, segCount)
        p += segCount * 2
        subRecord.idDelta = input.readUint16Seq(p, segCount)
        p += segCount * 2
        let idRangeAddress = p
        subRecord.idRangeOffset = input.readUint16Seq(p, segCount)
        p += segCount * 2
        for j in 0 ..< segCount:
          let
            endCount = subRecord.endCode[j].int
            startCount = subRecord.startCode[j].int
            idDelta = subRecord.idDelta[j].int
            idRangeOffset = subRecord.idRangeOffset[j].int
          for c in startCount .. endCount:
            var glyphIndex = 0
            if idRangeOffset != 0:
              var glyphIndexOffset = idRangeAddress + j * 2
              glyphIndexOffset += idRangeOffset
              glyphIndexOffset += (c - startCount) * 2
              glyphIndex = input.readUint16(glyphIndexOffset).swap().int
              if glyphIndex != 0:
                glyphIndex = (glyphIndex + idDelta) and 0xFFFF
            else:
              glyphIndex = (c + idDelta) and 0xFFFF
            if c != 65535:
              result.glyphIndexMap[c] = glyphIndex
      else:
        # TODO implement other record formats
        discard
    else:
      # TODO implement other cmap formats
      discard

    result.encodingRecords.add(record)

proc readGlyfTable*(input: string, p: int, loca: LocaTable): GlyfTable =
  result = GlyfTable()

  let glyphOffset = p
  for glyphIndex in 0 ..< loca.offsets.len:
    let locaOffset = loca.offsets[glyphIndex]
    let offset = glyphOffset + locaOffset.int
    result.offsets.add(offset)

proc parseGlyphPath(input: string, p: int, glyph: Glyph): seq[PathCommand] =
  if glyph.numberOfContours <= 0:
    return

  var p = p

  var endPtsOfContours = newSeq[int](glyph.numberOfContours)
  for i in 0 ..< glyph.numberOfContours:
    endPtsOfContours[i] = input.readUint16(p).swap().int
    p += 2

  let instructionLength = input.readUint16(p).swap()
  p += 2 + instructionLength.int

  var flags = newSeq[uint8]()

  let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
  var coordinates = newSeq[TtfCoordinate](totalOfCoordinates)

  var i = 0
  while i < totalOfCoordinates:
    let flag = input.readUint8(p)
    flags.add(flag)
    inc i
    inc p

    if (flag and 0x8) != 0 and i < totalOfCoordinates:
      let repeat = input.readUint8(p)
      inc p
      for j in 0 ..< repeat.int:
        flags.add(flag)
        inc i

  # Figure out xCoordinates.
  var prevX = 0
  for i, flag in flags:
    var x = 0
    if (flag and 0x2) != 0:
      x = input.readUint8(p).int
      inc p
      if (flag and 16) == 0:
        x = -x
    elif (flag and 16) != 0:
      x = 0
    else:
      x = input.readInt16(p).swap().int
      p += 2
    prevX += x
    coordinates[i].x = prevX
    coordinates[i].isOnCurve = (flag and 1) != 0

  # Figure out yCoordinates.
  var prevY = 0
  for i, flag in flags:
    var y = 0
    if (flag and 0x4) != 0:
      y = input.readUint8(p).int
      inc p
      if (flag and 32) == 0:
        y = -y
    elif (flag and 32) != 0:
      y = 0
    else:
      y = input.readInt16(p).swap().int
      p += 2
    prevY += y
    coordinates[i].y = prevY

  # Make an svg path out of this crazy stuff.
  var path = newSeq[PathCommand]()

  proc cmd(kind: PathCommandKind, x, y: int) =
    path.add PathCommand(kind: kind, numbers: @[float32 x, float32 y])

  proc cmd(kind: PathCommandKind) =
    path.add PathCommand(kind: kind, numbers: @[])

  proc cmd(x, y: int) =
    path[^1].numbers.add float32(x)
    path[^1].numbers.add float32(y)

  var contours: seq[seq[TtfCoordinate]]
  var currIdx = 0
  for endIdx in endPtsOfContours:
    contours.add(coordinates[currIdx .. endIdx])
    currIdx = endIdx + 1

  for contour in contours:
    var prev: TtfCoordinate
    var curr: TtfCoordinate = contour[^1]
    var next: TtfCoordinate = contour[0]

    if curr.isOnCurve:
      cmd(Move, curr.x, curr.y)
    else:
      if next.isOnCurve:
        cmd(Move, next.x, next.y)
      else:
        # If both first and last points are off-curve, start at their middle.
        cmd(Move, (curr.x + next.x) div 2, (curr.y + next.y) div 2)

    for i in 0 ..< contour.len:
      prev = curr
      curr = next
      next = contour[(i + 1) mod contour.len]

      if curr.isOnCurve:
        # This is a straight line.
        cmd(Line, curr.x, curr.y)
      else:
        var prev2 = prev
        var next2 = next

        if not prev.isOnCurve:
          prev2 = TtfCoordinate(
            x: (curr.x + prev.x) div 2,
            y: (curr.y + prev.y) div 2
          )
        if not next.isOnCurve:
          next2 = TtfCoordinate(
            x: (curr.x + next.x) div 2,
            y: (curr.y + next.y) div 2
          )

        cmd(Quad, curr.x, curr.y)
        cmd(next2.x, next2.y)

    cmd(End)

  return path

proc parseGlyph*(glyph: Glyph, font: Font)

proc parseCompositeGlyph(input: string, p: int, glyph: Glyph, font: Font): seq[PathCommand] =
  var
    typeface = font.typeface
    moreComponents = true
    p = p
  while moreComponents:
    let flags = input.readUint16(p + 0).swap()

    type TtfComponent = object
      glyphIndex: uint16
      xScale: float32
      scale01: float32
      scale10: float32
      yScale: float32
      dx: float32
      dy: float32
      matchedPoints: array[2, int]

    var component = TtfComponent()
    component.glyphIndex = input.readUint16(p + 2).swap()
    component.xScale = 1
    component.yScale = 1

    p += 4

    proc checkBit(flags, bit: uint16): bool =
      (flags.int and bit.int) > 0.int

    if flags.checkBit(1):
      # The arguments are words.
      if flags.checkBit(2):
        # Values are offset.
        component.dx = input.readInt16(p + 0).swap().float32
        component.dy = input.readInt16(p + 2).swap().float32
      else:
        # Values are matched points.
        component.matchedPoints = [
          input.readUint16(p + 0).swap().int, input.readUint16(p + 2).swap().int
        ]
      p += 4
    else:
      # The arguments are bytes.
      if flags.checkBit(2):
        # Values are offset.
        component.dx = input.readInt8(p + 0).float32
        component.dy = input.readInt8(p + 1).float32
      else:
        # Values are matched points.
        component.matchedPoints = [
          input.readInt8(p + 0).int, input.readInt8(p + 1).int
        ]
      p += 2

    if flags.checkBit(8):
      # We have a scale.
      component.xScale = input.readFixed16(p + 0)
      component.yScale = component.xScale
      p += 2
    elif flags.checkBit(64):
      # We have an X / Y scale.
      component.xScale = input.readFixed16(p + 0)
      component.yScale = input.readFixed16(p + 2)
      p += 4
    elif flags.checkBit(128):
      # We have a 2x2 transformation.
      component.xScale = input.readFixed16(p + 0)
      component.scale10 = input.readFixed16(p + 2)
      component.scale01 = input.readFixed16(p + 4)
      component.yScale = input.readFixed16(p + 6)
      p += 8

    var subGlyph = typeface.glyphArr[component.glyphIndex]
    if subGlyph.commands.len == 0:
      parseGlyph(subGlyph, font)

    # Transform commands path.
    let mat = mat3(
      component.xScale, component.scale10, 0.0,
      component.scale01, component.yScale, 0.0,
      component.dx, component.dy, 1.0
    )
    # Copy commands.
    for command in subGlyph.commands:
      var newCommand = PathCommand(kind: command.kind)
      for n in 0 ..< command.numbers.len div 2:
        var pos = vec2(command.numbers[n*2+0], command.numbers[n*2+1])
        pos = mat * pos
        newCommand.numbers.add pos.x
        newCommand.numbers.add pos.y
      result.add(newCommand)
    moreComponents = flags.checkBit(32)

proc parseGlyph*(glyph: Glyph, font: Font) =
  var
    otf = font.typeface.otf
    index = glyph.index

  var p = otf.glyf.offsets[index].int

  if index + 1 < otf.glyf.offsets.len and
    otf.glyf.offsets[index] == otf.glyf.offsets[index + 1]:
    glyph.isEmpty = true
    return

  glyph.numberOfContours = otf.data.readInt16(p + 0).swap()
  let
    xMin = otf.data.readInt16(p + 2).swap()
    yMin = otf.data.readInt16(p + 4).swap()
    xMax = otf.data.readInt16(p + 6).swap()
    yMax = otf.data.readInt16(p + 8).swap()
  glyph.bboxMin = vec2(xMin.float32, yMin.float32)
  glyph.bboxMax = vec2(xMax.float32, yMax.float32)

  p += 10

  if glyph.numberOfContours == -1:
    glyph.isComposite = true
    glyph.commands = parseCompositeGlyph(otf.data, p, glyph, font)
  else:
    glyph.commands = parseGlyphPath(otf.data, p, glyph)

proc parseOtf(input: string): Font =
  var
    otf = OTFFont()
    p: int

  otf.data = input
  otf.version = input.readUint32(p + 0).swap()
  otf.numTables = input.readUint16(p + 4).swap()
  otf.searchRange = input.readUint16(p + 6).swap()
  otf.entrySelector = input.readUint16(p + 8).swap()
  otf.rangeShift = input.readUint16(p + 10).swap()

  p += 12

  for i in 0 ..< otf.numTables.int:
    var chunk: Chunk
    chunk.tag = input.readStr(p + 0, 4)
    chunk.checkSum = input.readUint32(p + 4).swap()
    chunk.offset = input.readUint32(p + 8).swap()
    chunk.length = input.readUint32(p + 12).swap()
    otf.chunks[chunk.tag] = chunk
    p += 16

  otf.head = readHeadTable(input, otf.chunks["head"].offset.int)

  otf.name = readNameTable(input, otf.chunks["name"].offset.int)

  otf.maxp = readMaxpTable(input, otf.chunks["maxp"].offset.int)

  if "OS/2" in otf.chunks:
    otf.os2 = readOS2Table(input, otf.chunks["OS/2"].offset.int)

  otf.loca = readLocaTable(
    input, otf.chunks["loca"].offset.int, otf.head, otf.maxp
  )

  otf.hhea = readHheaTable(input, otf.chunks["hhea"].offset.int)

  otf.hmtx = readHmtxTable(
    input, otf.chunks["hmtx"].offset.int, otf.maxp, otf.hhea
  )

  if "kern" in otf.chunks:
    otf.kern = readKernTable(input, otf.chunks["kern"].offset.int)

  otf.cmap = readCmapTable(input, otf.chunks["cmap"].offset.int)

  otf.glyf = readGlyfTable(input, otf.chunks["glyf"].offset.int, otf.loca)

  var font = Font()
  var typeface = Typeface()
  font.typeface = typeface
  typeface.otf = otf
  typeface.unitsPerEm = otf.head.unitsPerEm.float32
  typeface.bboxMin = vec2(otf.head.xMin.float32, otf.head.yMin.float32)
  typeface.bboxMax = vec2(otf.head.xMax.float32, otf.head.yMax.float32)
  var fontFamily, fontSubfamily: string
  for nameRecord in otf.name.nameRecords:
    if nameRecord.name == ntnFontFamily:
      fontFamily = nameRecord.text
    if nameRecord.name == ntnFontFamily:
      fontSubfamily = nameRecord.text
  typeface.name = fontSubfamily & " " & fontSubfamily

  typeface.ascent = otf.hhea.ascender.float32
  typeface.descent = otf.hhea.descender.float32

  if otf.os2 != nil:
    typeface.lineGap = otf.os2.sTypoLineGap.float32
    typeface.capHeight = otf.os2.sCapHeight.float32
  else:
    typeface.capHeight = typeface.ascent - typeface.descent
    typeface.lineGap = typeface.ascent

  typeface.glyphArr = newSeq[Glyph](otf.glyf.offsets.len)
  for i in 0 ..< typeface.glyphArr.len:
    var glyph = Glyph()
    glyph.index = i
    typeface.glyphArr[i] = glyph

  for i in 0 ..< typeface.glyphArr.len:
    if i < otf.hmtx.hMetrics.len:
      typeface.glyphArr[i].advance = otf.hmtx.hMetrics[i].advanceWidth.float32
    else:
      typeface.glyphArr[i].advance = otf.hmtx.hMetrics[^1].advanceWidth.float32

  typeface.glyphs = initTable[string, Glyph]()
  for unicode, glyphIndex in otf.cmap.glyphIndexMap:
    let code = Rune(unicode).toUTF8()
    typeface.glyphs[code] = typeface.glyphArr[glyphIndex]
    typeface.glyphs[code].code = code

  font.typeface.kerning = initTable[(string, string), float32]()
  if otf.kern != nil:
    for table in otf.kern.subTables:
      for pair in table.kerningPairs:
        var u1 = typeface.glyphArr[pair.left].code
        var u2 = typeface.glyphArr[pair.right].code
        if u1.len > 0 and u2.len > 0:
          font.typeface.kerning[(u1, u2)] = pair.value.float32

  return font

proc readFontOtf*(filePath: string): Font =
  if not fileExists(filePath):
    raise newException(IOError, "File `" & filePath & "` does not exist.")

  parseOtf(readFile(filePath))

proc readFontTtf*(filePath: string): Font =
  ## OTF Supports most of TTF features.
  readFontOtf(filePath)
