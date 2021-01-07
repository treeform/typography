import ../font, os, tables, unicode, vmath, types, pixie/paths, flatty/binny

proc readUint16Seq(buf: string, offset, len: int): seq[uint16] =
  result = newSeq[uint16](len)
  for i in 0 ..< len:
    result[i] = buf.readUint16(offset + i * 2).swap()

proc readFixed32(buf: string, offset: int): float32 =
  ## Packed 32-bit value with major and minor version numbers.
  ceil(buf.readInt32(offset).swap().float32 / 65536.0 * 100000.0) / 100000.0

proc readFixed16(buf: string, offset: int): float32 =
  ## Reads 16-bit signed fixed number with the low 14 bits of fraction (2.14).
  buf.readInt16(offset).swap().float32 / 16384.0

proc readLongDateTime(buf: string, offset: int): float64 =
  ## Date and time represented in number of seconds since 12:00 midnight,
  ## January 1, 1904, UTC.
  buf.readInt64(offset).swap().float64 - 2082844800

proc eofCheck(buf: string, readTo: int) {.inline.} =
  if readTo > buf.len:
    raise newException(
      TypographyError, "Unexpected error reading font data, EOF"
    )

proc failUnsupported() =
  raise newException(TypographyError, "Unsupported font data")

proc fromUtf16be(buf: string): string =
  ## Converts UTF-16 to UTF-8.
  var pos: int
  while pos < buf.len:
    buf.eofCheck(pos + 2)

    let u1 = buf.readUint16(pos).swap()
    pos += 2

    if u1 - 0xd800 >= 0x800'u16:
      result.add(Rune(u1.int32))
    else:
      buf.eofCheck(pos + 2)

      let u2 = buf.readUint16(pos).swap()
      pos += 2

      if ((u1 and 0xfc00) == 0xd800) and ((u2 and 0xfc00) == 0xdc00):
        result.add(Rune((u1.int32 shl 10) + u2.int32 - 0x35fdc00))
      else:
        # Error, produce tofu character.
        result.add("□")

proc parseHeadTable(buf: string, offset: int): HeadTable =
  buf.eofCheck(offset + 54)
  result = HeadTable()
  result.majorVersion = buf.readUint16(offset + 0).swap()
  if result.majorVersion != 1:
    failUnsupported()
  result.minorVersion = buf.readUint16(offset + 2).swap()
  if result.minorVersion != 0:
    failUnsupported()
  result.fontRevision = buf.readFixed32(offset + 4)
  result.checkSumAdjustment = buf.readUint32(offset + 8).swap()
  result.magicNumber = buf.readUint32(offset + 12).swap()
  result.flags = buf.readUint16(offset + 16).swap()
  result.unitsPerEm = buf.readUint16(offset + 18).swap()
  result.created = buf.readLongDateTime(offset + 20)
  result.modified = buf.readLongDateTime(offset + 28)
  result.xMin = buf.readInt16(offset + 36).swap()
  result.yMin = buf.readInt16(offset + 38).swap()
  result.xMax = buf.readInt16(offset + 40).swap()
  result.yMax = buf.readInt16(offset + 42).swap()
  result.macStyle = buf.readUint16(offset + 44).swap()
  result.lowestRecPPEM = buf.readUint16(offset + 46).swap()
  result.fontDirectionHint = buf.readInt16(offset + 48).swap()
  result.indexToLocFormat = buf.readInt16(offset + 50).swap()
  result.glyphDataFormat = buf.readInt16(offset + 52).swap()
  if result.glyphDataFormat != 0:
    failUnsupported()

proc parseNameTable(buf: string, offset: int): NameTable =
  var p = offset
  buf.eofCheck(p + 6)

  result = NameTable()
  result.format = buf.readUint16(p + 0).swap()
  if result.format != 0:
    failUnsupported()
  result.count = buf.readUint16(p + 2).swap()
  result.stringOffset = buf.readUint16(p + 4).swap()

  p += 6

  buf.eofCheck(p + result.count.int * 12)

  for i in 0 ..< result.count.int:
    var record = NameRecord()
    record.platformID = buf.readUint16(p + 0).swap()
    record.encodingID = buf.readUint16(p + 2).swap()
    record.languageID = buf.readUint16(p + 4).swap()
    record.nameID = buf.readUint16(p + 6).swap()
    record.length = buf.readUint16(p + 8).swap()
    record.offset = buf.readUint16(p + 10).swap()

    p += 12

    if record.nameID < ord(NameTableNames.low) or
      record.nameID > ord(NameTableNames.high):
      continue

    record.name = NameTableNames(record.nameID)

    let textOffset = offset + result.stringOffset.int + record.offset.int
    buf.eofCheck(textOffset + record.length.int)
    record.text = buf.readStr(textOffset, record.length.int)

    if record.platformID == 3:
      if record.encodingID == 0 or record.encodingID == 1:
        record.text = record.text.fromUtf16be()
    elif record.platformID == 1:
      if record.encodingId == 0:
        discard

    result.nameRecords.add(record)

proc parseMaxpTable(buf: string, offset: int): MaxpTable =
  buf.eofCheck(offset + 32)
  result = MaxpTable()
  result.version = buf.readFixed32(offset + 0)
  if result.version != 1.0:
    failUnsupported()
  result.numGlyphs = buf.readUint16(offset + 4).swap()
  result.maxPoints = buf.readUint16(offset + 6).swap()
  result.maxContours = buf.readUint16(offset + 8).swap()
  result.maxCompositePoints = buf.readUint16(offset + 10).swap()
  result.maxCompositeContours = buf.readUint16(offset + 12).swap()
  result.maxZones = buf.readUint16(offset + 14).swap()
  result.maxTwilightPoints = buf.readUint16(offset + 16).swap()
  result.maxStorage = buf.readUint16(offset + 18).swap()
  result.maxFunctionDefs = buf.readUint16(offset + 20).swap()
  result.maxInstructionDefs = buf.readUint16(offset + 22).swap()
  result.maxStackElements = buf.readUint16(offset + 24).swap()
  result.maxSizeOfInstructions = buf.readUint16(offset + 26).swap()
  result.maxComponentElements = buf.readUint16(offset + 28).swap()
  result.maxComponentDepth = buf.readUint16(offset + 30).swap()

proc parseOS2Table(buf: string, offset: int): OS2Table =
  var p = offset
  buf.eofCheck(p + 78)
  result = OS2Table()
  result.version = buf.readUint16(p + 0).swap()
  result.xAvgCharWidth = buf.readInt16(p + 2).swap()
  result.usWeightClass = buf.readUint16(p + 4).swap()
  result.usWidthClass = buf.readUint16(p + 6).swap()
  result.fsType = buf.readUint16(p + 8).swap()
  result.ySubscriptXSize = buf.readInt16(p + 10).swap()
  result.ySubscriptYSize = buf.readInt16(p + 12).swap()
  result.ySubscriptXOffset = buf.readInt16(p + 14).swap()
  result.ySubscriptYOffset = buf.readInt16(p + 16).swap()
  result.ySuperscriptXSize = buf.readInt16(p + 18).swap()
  result.ySuperscriptYSize = buf.readInt16(p + 20).swap()
  result.ySuperscriptXOffset = buf.readInt16(p + 22).swap()
  result.ySuperscriptYOffset = buf.readInt16(p + 24).swap()
  result.yStrikeoutSize = buf.readInt16(p + 26).swap()
  result.yStrikeoutPosition = buf.readInt16(p + 28).swap()
  result.sFamilyClass = buf.readInt16(p + 30).swap()
  p += 32
  for i in 0 ..< 10:
    result.panose[i] = buf.readUint8(p + i)
  p += 10
  result.ulUnicodeRange1 = buf.readUint32(p + 0).swap()
  result.ulUnicodeRange2 = buf.readUint32(p + 4).swap()
  result.ulUnicodeRange3 = buf.readUint32(p + 8).swap()
  result.ulUnicodeRange4 = buf.readUint32(p + 12).swap()
  result.achVendID = buf.readStr(p + 16, 4)
  result.fsSelection = buf.readUint16(p + 20).swap()
  result.usFirstCharIndex = buf.readUint16(p + 22).swap()
  result.usLastCharIndex = buf.readUint16(p + 24).swap()
  result.sTypoAscender = buf.readInt16(p + 26).swap()
  result.sTypoDescender = buf.readInt16(p + 28).swap()
  result.sTypoLineGap = buf.readInt16(p + 30).swap()
  result.usWinAscent = buf.readUint16(p + 32).swap()
  result.usWinDescent = buf.readUint16(p + 34).swap()
  p += 36

  if result.version >= 1.uint16:
    buf.eofCheck(p + 8)
    result.ulCodePageRange1 = buf.readUint32(p + 0).swap()
    result.ulCodePageRange2 = buf.readUint32(p + 4).swap()
    p += 8
  if result.version >= 2.uint16:
    buf.eofCheck(p + 10)
    result.sxHeight = buf.readInt16(p + 0).swap()
    result.sCapHeight = buf.readInt16(p + 2).swap()
    result.usDefaultChar = buf.readUint16(p + 4).swap()
    result.usBreakChar = buf.readUint16(p + 6).swap()
    result.usMaxContext = buf.readUint16(p + 8).swap()
    p += 10
  if result.version >= 5.uint16:
    buf.eofCheck(p + 4)
    result.usLowerOpticalPointSize = buf.readUint16(p + 0).swap()
    result.usUpperOpticalPointSize = buf.readUint16(p + 2).swap()
    p += 4

proc parseLocaTable(
  buf: string, offset: int, head: HeadTable, maxp: MaxpTable
): LocaTable =
  var p = offset

  result = LocaTable()
  if head.indexToLocFormat == 0:
    # Uses uint16.
    buf.eofCheck(p + maxp.numGlyphs.int * 2)
    for i in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(buf.readUint16(p).swap().uint32 * 2)
      p += 2
  else:
    # Uses uint32.
    buf.eofCheck(p + maxp.numGlyphs.int * 4)
    for i in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(buf.readUint32(p).swap())
      p += 4

proc parseHheaTable(buf: string, offset: int): HheaTable =
  buf.eofCheck(offset + 36)
  result = HheaTable()
  result.majorVersion = buf.readUint16(offset + 0).swap()
  if result.majorVersion != 1:
    failUnsupported()
  result.minorVersion = buf.readUint16(offset + 2).swap()
  if result.minorVersion != 0:
    failUnsupported()
  result.ascender = buf.readInt16(offset + 4).swap()
  result.descender = buf.readInt16(offset + 6).swap()
  result.lineGap = buf.readInt16(offset + 8).swap()
  result.advanceWidthMax = buf.readUint16(offset + 10).swap()
  result.minLeftSideBearing = buf.readInt16(offset + 12).swap()
  result.minRightSideBearing = buf.readInt16(offset + 14).swap()
  result.xMaxExtent = buf.readInt16(offset + 16).swap()
  result.caretSlopeRise = buf.readInt16(offset + 18).swap()
  result.caretSlopeRun = buf.readInt16(offset + 20).swap()
  result.caretOffset = buf.readInt16(offset + 22).swap()
  discard buf.readUint16(offset + 24).swap() # Reserved, discard
  discard buf.readUint16(offset + 26).swap() # Reserved, discard
  discard buf.readUint16(offset + 28).swap() # Reserved, discard
  discard buf.readUint16(offset + 30).swap() # Reserved, discard
  result.metricDataFormat = buf.readInt16(offset + 32).swap()
  if result.metricDataFormat != 0:
    failUnsupported()
  result.numberOfHMetrics = buf.readUint16(offset + 34).swap()

proc parseHmtxTable(
  buf: string, offset: int, maxp: MaxpTable, hhea: HheaTable
): HmtxTable =
  var p = offset

  result = HmtxTable()
  for i in 0 ..< maxp.numGlyphs.int:
    if i < hhea.numberOfHMetrics.int:
      buf.eofCheck(p + 4)
      var record = LongHorMetricRecrod()
      record.advanceWidth = buf.readUint16(p + 0).swap()
      record.lsb = buf.readInt16(p + 2).swap()
      result.hMetrics.add(record)
      p += 4
    else:
      buf.eofCheck(p + 2)
      result.leftSideBearings.add(buf.readInt16(p).swap())
      p += 2

proc parseKernTable(buf: string, offset: int): KernTable =
  var p = offset
  buf.eofCheck(p + 2)
  result = KernTable()
  result.version = buf.readUint16(p + 0).swap()
  if result.version == 0:
    # Windows format.
    buf.eofCheck(p + 4)
    result.nTables = buf.readUint16(p + 2).swap()
    p += 4
    for i in 0 ..< result.nTables.int:
      buf.eofCheck(p + 14)
      var subTable = KernSubTable()
      subTable.version = buf.readUint16(p + 0).swap()
      if subTable.version != 0:
        failUnsupported()
      subTable.length = buf.readUint16(p + 2).swap()
      subTable.coverage = buf.readUint16(p + 4).swap()
      # TODO: check coverage
      subTable.numPairs = buf.readUint16(p + 6).swap()
      subTable.searchRange = buf.readUint16(p + 8).swap()
      subTable.entrySelector = buf.readUint16(p + 10).swap()
      subTable.rangeShift = buf.readUint16(p + 12).swap()
      p += 14
      for i in 0 ..< subTable.numPairs.int:
        buf.eofCheck(p + 6)
        var pair = KerningPair()
        pair.left = buf.readUint16(p + 0).swap()
        pair.right = buf.readUint16(p + 2).swap()
        pair.value = buf.readInt16(p + 4).swap()
        subTable.kerningPairs.add(pair)
        p += 6
      result.subTables.add(subTable)
  elif result.version == 1:
    # TODO: Mac kern format
    discard
  else:
    failUnsupported()

proc parseCmapTable(buf: string, offset: int): CmapTable =
  var p = offset
  buf.eofCheck(p + 4)

  result = CmapTable()
  result.version = buf.readUint16(p + 0).swap()
  result.numTables = buf.readUint16(p + 2).swap()
  p += 4

  for i in 0 ..< result.numTables.int:
    buf.eofCheck(p + 8)
    var record = EncodingRecord()
    record.platformID = buf.readUint16(p + 0).swap()
    record.encodingID = buf.readUint16(p + 2).swap()
    record.offset = buf.readUint32(p + 4).swap()
    p += 8

    if record.platformID == 3:
      # Windows format unicode format.
      var p = offset + record.offset.int
      buf.eofCheck(p + 2)
      let format = buf.readUint16(p + 0).swap()
      if format == 4:
        buf.eofCheck(p + 14)
        var subRecord = SegmentMapping()
        subRecord.format = format
        subRecord.length = buf.readUint16(p + 2).swap()
        subRecord.language = buf.readUint16(p + 4).swap()
        subRecord.segCountX2 = buf.readUint16(p + 6).swap()
        let segCount = (subRecord.segCountX2 div 2).int
        subRecord.searchRange = buf.readUint16(p + 8).swap()
        subRecord.entrySelector = buf.readUint16(p + 10).swap()
        subRecord.rangeShift = buf.readUint16(p + 12).swap()
        p += 14
        buf.eofCheck(p + 2 + 4 * segCount * 2)
        subRecord.endCode = buf.readUint16Seq(p, segCount)
        p += segCount * 2
        subRecord.reservedPad = buf.readUint16(p + 0).swap()
        p += 2
        subRecord.startCode = buf.readUint16Seq(p, segCount)
        p += segCount * 2
        subRecord.idDelta = buf.readUint16Seq(p, segCount)
        p += segCount * 2
        let idRangeOffsetPos = p
        subRecord.idRangeOffset = buf.readUint16Seq(p, segCount)
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
              var glyphIndexOffset = idRangeOffsetPos + j * 2
              glyphIndexOffset += idRangeOffset
              glyphIndexOffset += (c - startCount) * 2
              buf.eofCheck(glyphIndexOffset + 2)
              glyphIndex = buf.readUint16(glyphIndexOffset).swap().int
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

proc parseGlyfTable(buf: string, offset: int, loca: LocaTable): GlyfTable =
  result = GlyfTable()
  for glyphIndex in 0 ..< loca.offsets.len:
    let locaOffset = loca.offsets[glyphIndex]
    result.offsets.add(offset + locaOffset.int)

proc parseGlyphPath(buf: string, offset: int, glyph: Glyph): seq[PathCommand] =
  if glyph.numberOfContours <= 0:
    return

  var p = offset
  buf.eofCheck(p + glyph.numberOfContours * 2)

  var endPtsOfContours = newSeq[int](glyph.numberOfContours)
  for i in 0 ..< glyph.numberOfContours:
    endPtsOfContours[i] = buf.readUint16(p).swap().int
    p += 2

  buf.eofCheck(p + 2)

  let instructionLength = buf.readUint16(p).swap()
  p += 2 + instructionLength.int

  let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
  var
    flags = newSeq[uint8]()
    coordinates = newSeq[TtfCoordinate](totalOfCoordinates)
    i = 0
  while i < totalOfCoordinates:
    buf.eofCheck(p + 1)
    let flag = buf.readUint8(p)
    flags.add(flag)
    inc i
    inc p

    if (flag and 0x8) != 0 and i < totalOfCoordinates:
      buf.eofCheck(p + 1)
      let repeat = buf.readUint8(p)
      inc p
      for j in 0 ..< repeat.int:
        flags.add(flag)
        inc i

  # Figure out xCoordinates.
  var prevX = 0
  for i, flag in flags:
    var x = 0
    if (flag and 0x2) != 0:
      buf.eofCheck(p + 1)
      x = buf.readUint8(p).int
      inc p
      if (flag and 16) == 0:
        x = -x
    elif (flag and 16) != 0:
      x = 0
    else:
      buf.eofCheck(p + 1)
      x = buf.readInt16(p).swap().int
      p += 2
    prevX += x
    coordinates[i].x = prevX.float32
    coordinates[i].isOnCurve = (flag and 1) != 0

  # Figure out yCoordinates.
  var prevY = 0
  for i, flag in flags:
    var y = 0
    if (flag and 0x4) != 0:
      buf.eofCheck(p + 1)
      y = buf.readUint8(p).int
      inc p
      if (flag and 32) == 0:
        y = -y
    elif (flag and 32) != 0:
      y = 0
    else:
      buf.eofCheck(p + 2)
      y = buf.readInt16(p).swap().int
      p += 2
    prevY += y
    coordinates[i].y = prevY.float32

  # Make an svg path out of this crazy stuff.

  var
    contours: seq[seq[TtfCoordinate]]
    currIdx = 0
  for endIdx in endPtsOfContours:
    contours.add(coordinates[currIdx .. endIdx])
    currIdx = endIdx + 1

  for contour in contours:
    var
      prev: TtfCoordinate
      curr: TtfCoordinate = contour[^1]
      next: TtfCoordinate = contour[0]

    if curr.isOnCurve:
      result.add(PathCommand(kind: Move, numbers: @[curr.x, curr.y]))
    else:
      if next.isOnCurve:
        result.add(PathCommand(kind: Move, numbers: @[next.x, next.y]))
      else:
        # If both first and last points are off-curve, start at their middle.
        result.add(PathCommand(
          kind: Move,
          numbers: @[(curr.x + next.x) / 2, (curr.y + next.y) / 2]
        ))

    for i in 0 ..< contour.len:
      prev = curr
      curr = next
      next = contour[(i + 1) mod contour.len]

      if curr.isOnCurve:
        # This is a straight line.
        result.add(PathCommand(kind: Line, numbers: @[curr.x, curr.y]))
      else:
        # var prev2 = prev
        var next2 = next

        # if not prev.isOnCurve:
        #   prev2 = TtfCoordinate(
        #     x: (curr.x + prev.x) div 2,
        #     y: (curr.y + prev.y) div 2
        #   )
        if not next.isOnCurve:
          next2 = TtfCoordinate(
            x: (curr.x + next.x) / 2,
            y: (curr.y + next.y) / 2
          )

        result.add(PathCommand(
          kind: Quad,
          numbers: @[curr.x, curr.y, next2.x, next2.y]
        ))

    result.add(PathCommand(kind: Close))

proc parseGlyph*(glyph: Glyph, font: Font)

proc parseCompositeGlyph(buf: string, offset: int, glyph: Glyph, font: Font): seq[PathCommand] =
  var
    typeface = font.typeface
    moreComponents = true
    p = offset
  while moreComponents:
    buf.eofCheck(p + 4)

    let flags = buf.readUint16(p + 0).swap()

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
    component.glyphIndex = buf.readUint16(p + 2).swap()
    component.xScale = 1
    component.yScale = 1

    p += 4

    proc checkBit(flags, bit: uint16): bool =
      (flags.int and bit.int) > 0.int

    if flags.checkBit(1):
      # The arguments are words.
      buf.eofCheck(p + 4)
      if flags.checkBit(2):
        # Values are offset.
        component.dx = buf.readInt16(p + 0).swap().float32
        component.dy = buf.readInt16(p + 2).swap().float32
      else:
        # Values are matched points.
        component.matchedPoints = [
          buf.readUint16(p + 0).swap().int,
          buf.readUint16(p + 2).swap().int
        ]
      p += 4
    else:
      # The arguments are bytes.
      buf.eofCheck(p + 2)
      if flags.checkBit(2):
        # Values are offset.
        component.dx = buf.readInt8(p + 0).float32
        component.dy = buf.readInt8(p + 1).float32
      else:
        # Values are matched points.
        component.matchedPoints = [
          buf.readInt8(p + 0).int,
          buf.readInt8(p + 1).int
        ]
      p += 2

    if flags.checkBit(8):
      # We have a scale.
      buf.eofCheck(p + 2)
      component.xScale = buf.readFixed16(p + 0)
      component.yScale = component.xScale
      p += 2
    elif flags.checkBit(64):
      # We have an X / Y scale.
      buf.eofCheck(p + 4)
      component.xScale = buf.readFixed16(p + 0)
      component.yScale = buf.readFixed16(p + 2)
      p += 4
    elif flags.checkBit(128):
      # We have a 2x2 transformation.
      buf.eofCheck(p + 8)
      component.xScale = buf.readFixed16(p + 0)
      component.scale10 = buf.readFixed16(p + 2)
      component.scale01 = buf.readFixed16(p + 4)
      component.yScale = buf.readFixed16(p + 6)
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
        newCommand.numbers.add([pos.x, pos.y])
      result.add(newCommand)
    moreComponents = flags.checkBit(32)

proc parseGlyph*(glyph: Glyph, font: Font) =
  var
    otf = font.typeface.otf
    index = glyph.index

  if index + 1 < otf.glyf.offsets.len and
    otf.glyf.offsets[index] == otf.glyf.offsets[index + 1]:
    glyph.isEmpty = true
    return

  var p = otf.glyf.offsets[index].int
  otf.buf.eofCheck(p + 10)
  glyph.numberOfContours = otf.buf.readInt16(p + 0).swap()
  let
    xMin = otf.buf.readInt16(p + 2).swap()
    yMin = otf.buf.readInt16(p + 4).swap()
    xMax = otf.buf.readInt16(p + 6).swap()
    yMax = otf.buf.readInt16(p + 8).swap()
  glyph.bboxMin = vec2(xMin.float32, yMin.float32)
  glyph.bboxMax = vec2(xMax.float32, yMax.float32)

  p += 10

  if glyph.numberOfContours == -1:
    glyph.isComposite = true
    glyph.commands = parseCompositeGlyph(otf.buf, p, glyph, font)
  else:
    glyph.commands = parseGlyphPath(otf.buf, p, glyph)

proc parseOtf(buf: string): Font =
  var
    otf = OTFFont()
    p: int

  buf.eofCheck(p + 12)

  otf.buf = buf
  otf.version = buf.readUint32(p + 0).swap()
  otf.numTables = buf.readUint16(p + 4).swap()
  otf.searchRange = buf.readUint16(p + 6).swap()
  otf.entrySelector = buf.readUint16(p + 8).swap()
  otf.rangeShift = buf.readUint16(p + 10).swap()

  p += 12

  buf.eofCheck(p + otf.numTables.int * 16)

  for i in 0 ..< otf.numTables.int:
    var chunk: Chunk
    chunk.tag = buf.readStr(p + 0, 4)
    chunk.checkSum = buf.readUint32(p + 4).swap()
    chunk.offset = buf.readUint32(p + 8).swap()
    chunk.length = buf.readUint32(p + 12).swap()
    otf.chunks[chunk.tag] = chunk
    p += 16

  otf.head = parseHeadTable(buf, otf.chunks["head"].offset.int)

  otf.name = parseNameTable(buf, otf.chunks["name"].offset.int)

  otf.maxp = parseMaxpTable(buf, otf.chunks["maxp"].offset.int)

  if "OS/2" in otf.chunks:
    otf.os2 = parseOS2Table(buf, otf.chunks["OS/2"].offset.int)

  otf.loca =
    parseLocaTable(buf, otf.chunks["loca"].offset.int, otf.head, otf.maxp)

  otf.hhea = parseHheaTable(buf, otf.chunks["hhea"].offset.int)

  otf.hmtx =
    parseHmtxTable(buf, otf.chunks["hmtx"].offset.int, otf.maxp, otf.hhea)

  if "kern" in otf.chunks:
    otf.kern = parseKernTable(buf, otf.chunks["kern"].offset.int)

  otf.cmap = parseCmapTable(buf, otf.chunks["cmap"].offset.int)

  otf.glyf = parseGlyfTable(buf, otf.chunks["glyf"].offset.int, otf.loca)

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
