import ../font, os, streams, tables, unicode, vmath, types, pixie/paths,
  flatty/binny

proc readUint16Seq(stream: Stream, len: int): seq[uint16] =
  result = newSeq[uint16](len)
  for i in 0 ..< len:
    result[i] = stream.readUint16().swap()

proc readFixed32(stream: Stream): float32 =
  ## Packed 32-bit value with major and minor version numbers.
  ceil(stream.readInt32().swap().float32 / 65536.0 * 100000.0) / 100000.0

proc readFixed16(stream: Stream): float32 =
  ## Reads 16-bit signed fixed number with the low 14 bits of fraction (2.14).
  float32(stream.readInt16().swap()) / 16384.0

proc readLongDateTime*(stream: Stream): float64 =
  result = stream.readInt64().swap().float64 - 2082844800

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

proc readHeadTable(f: Stream): HeadTable =
  result = HeadTable()
  result.majorVersion = f.readUint16().swap()
  assert result.majorVersion == 1
  result.minorVersion = f.readUint16().swap()
  assert result.minorVersion == 0
  result.fontRevision = f.readFixed32()
  result.checkSumAdjustment = f.readUint32().swap()
  result.magicNumber = f.readUint32().swap()
  result.flags = f.readUint16().swap()
  result.unitsPerEm = f.readUint16().swap()
  result.created = f.readLongDateTime()
  result.modified = f.readLongDateTime()
  result.xMin = f.readInt16().swap()
  result.yMin = f.readInt16().swap()
  result.xMax = f.readInt16().swap()
  result.yMax = f.readInt16().swap()
  result.macStyle = f.readUint16().swap()
  result.lowestRecPPEM = f.readUint16().swap()
  result.fontDirectionHint = f.readInt16().swap()
  result.indexToLocFormat = f.readInt16().swap()
  result.glyphDataFormat = f.readInt16().swap()
  assert result.glyphDataFormat == 0

proc readNameTable*(f: Stream): NameTable =
  result = NameTable()
  let at = f.getPosition()
  result.format = f.readUint16().swap()
  assert result.format == 0
  result.count = f.readUint16().swap()
  result.stringOffset = f.readUint16().swap()

  for i in 0 ..< result.count.int:
    var record = NameRecord()
    record.platformID = f.readUint16().swap()
    record.encodingID = f.readUint16().swap()
    record.languageID = f.readUint16().swap()
    record.nameID = f.readUint16().swap()
    record.name = cast[NameTableNames](record.nameID)
    record.length = f.readUint16().swap()
    record.offset = f.readUint16().swap()

    let save = f.getPosition()
    f.setPosition(at + int(result.stringOffset + record.offset))
    record.text = f.readStr(record.length.int)
    f.setPosition(save)

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

proc readMaxpTable*(f: Stream): MaxpTable =
  result = MaxpTable()
  result.version = f.readFixed32()
  result.numGlyphs = f.readUint16().swap()
  result.maxPoints = f.readUint16().swap()
  result.maxContours = f.readUint16().swap()
  result.maxCompositePoints = f.readUint16().swap()
  result.maxCompositeContours = f.readUint16().swap()
  result.maxZones = f.readUint16().swap()
  result.maxTwilightPoints = f.readUint16().swap()
  result.maxStorage = f.readUint16().swap()
  result.maxFunctionDefs = f.readUint16().swap()
  result.maxInstructionDefs = f.readUint16().swap()
  result.maxStackElements = f.readUint16().swap()
  result.maxSizeOfInstructions = f.readUint16().swap()
  result.maxComponentElements = f.readUint16().swap()
  result.maxComponentDepth = f.readUint16().swap()

proc readOS2Table*(f: Stream): OS2Table =
  result = OS2Table()
  result.version = f.readUint16().swap()
  result.xAvgCharWidth = f.readInt16().swap()
  result.usWeightClass = f.readUint16().swap()
  result.usWidthClass = f.readUint16().swap()
  result.fsType = f.readUint16().swap()
  result.ySubscriptXSize = f.readInt16().swap()
  result.ySubscriptYSize = f.readInt16().swap()
  result.ySubscriptXOffset = f.readInt16().swap()
  result.ySubscriptYOffset = f.readInt16().swap()
  result.ySuperscriptXSize = f.readInt16().swap()
  result.ySuperscriptYSize = f.readInt16().swap()
  result.ySuperscriptXOffset = f.readInt16().swap()
  result.ySuperscriptYOffset = f.readInt16().swap()
  result.yStrikeoutSize = f.readInt16().swap()
  result.yStrikeoutPosition = f.readInt16().swap()
  result.sFamilyClass = f.readInt16().swap()
  for i in 0 ..< 10:
    result.panose[i] = f.readUint8()
  result.ulUnicodeRange1 = f.readUint32().swap()
  result.ulUnicodeRange2 = f.readUint32().swap()
  result.ulUnicodeRange3 = f.readUint32().swap()
  result.ulUnicodeRange4 = f.readUint32().swap()
  result.achVendID = f.readStr(4)
  result.fsSelection = f.readUint16().swap()
  result.usFirstCharIndex = f.readUint16().swap()
  result.usLastCharIndex = f.readUint16().swap()
  result.sTypoAscender = f.readInt16().swap()
  result.sTypoDescender = f.readInt16().swap()
  result.sTypoLineGap = f.readInt16().swap()
  result.usWinAscent = f.readUint16().swap()
  result.usWinDescent = f.readUint16().swap()
  if result.version >= 1.uint16:
    result.ulCodePageRange1 = f.readUint32().swap()
    result.ulCodePageRange2 = f.readUint32().swap()
  if result.version >= 2.uint16:
    result.sxHeight = f.readInt16().swap()
    result.sCapHeight = f.readInt16().swap()
    result.usDefaultChar = f.readUint16().swap()
    result.usBreakChar = f.readUint16().swap()
    result.usMaxContext = f.readUint16().swap()
  if result.version >= 5.uint16:
    result.usLowerOpticalPointSize = f.readUint16().swap()
    result.usUpperOpticalPointSize = f.readUint16().swap()

proc readLocaTable*(f: Stream, head: HeadTable, maxp: MaxpTable): LocaTable =
  result = LocaTable()
  var locaOffset = f.getPosition()
  if head.indexToLocFormat == 0:
    # Uses uint16.
    for i in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(f.readUint16().swap().uint32 * 2)
      locaOffset += 2
  else:
    # Users uint32.
    for i in 0 ..< maxp.numGlyphs.int:
      result.offsets.add(f.readUint32().swap())
      locaOffset += 4

proc readHheaTable*(f: Stream): HheaTable =
  result = HheaTable()
  result.majorVersion = f.readUint16().swap()
  assert result.majorVersion == 1
  result.minorVersion = f.readUint16().swap()
  assert result.minorVersion == 0
  result.ascender = f.readInt16().swap()
  result.descender = f.readInt16().swap()
  result.lineGap = f.readInt16().swap()
  result.advanceWidthMax = f.readUint16().swap()
  result.minLeftSideBearing = f.readInt16().swap()
  result.minRightSideBearing = f.readInt16().swap()
  result.xMaxExtent = f.readInt16().swap()
  result.caretSlopeRise = f.readInt16().swap()
  result.caretSlopeRun = f.readInt16().swap()
  result.caretOffset = f.readInt16().swap()
  discard f.readUint16().swap()
  discard f.readUint16().swap()
  discard f.readUint16().swap()
  discard f.readUint16().swap()
  result.metricDataFormat = f.readInt16().swap()
  assert result.metricDataFormat == 0
  result.numberOfHMetrics = f.readUint16().swap()

proc readHmtxTable*(f: Stream, maxp: MaxpTable, hhea: HheaTable): HmtxTable =
  result = HmtxTable()
  for i in 0 ..< maxp.numGlyphs.int:
    if i < hhea.numberOfHMetrics.int:
      var record = LongHorMetricRecrod()
      record.advanceWidth = f.readUint16().swap()
      record.lsb = f.readInt16().swap()
      result.hMetrics.add(record)
    else:
      result.leftSideBearings.add(f.readInt16().swap())

proc readKernTable*(f: Stream): KernTable =
  result = KernTable()
  result.version = f.readUint16().swap()
  if result.version == 0:
    # Windows format.
    result.nTables = f.readUint16().swap()
    for i in 0 ..< result.nTables.int:
      var subTable = KernSubTable()
      subTable.version = f.readUint16().swap()
      assert subTable.version == 0
      subTable.length = f.readUint16().swap()
      subTable.coverage = f.readUint16().swap()
      # TODO: check coverage
      subTable.numPairs = f.readUint16().swap()
      subTable.searchRange = f.readUint16().swap()
      subTable.entrySelector = f.readUint16().swap()
      subTable.rangeShift = f.readUint16().swap()
      for i in 0 ..< subTable.numPairs.int:
        var pair = KerningPair()
        pair.left = f.readUint16().swap()
        pair.right = f.readUint16().swap()
        pair.value = f.readInt16().swap()
        subTable.kerningPairs.add(pair)
      result.subTables.add(subTable)
  elif result.version == 1:
    # Mac format.
    # TODO: add mac kern format
    discard
  else:
    assert false

proc readCmapTable*(f: Stream): CmapTable =
  let cmapOffset = f.getPosition()
  result = CmapTable()
  result.version = f.readUint16().swap()
  result.numTables = f.readUint16().swap()
  for i in 0 ..< result.numTables.int:
    var record = EncodingRecord()
    record.platformID = f.readUint16().swap()
    record.encodingID = f.readUint16().swap()
    record.offset = f.readUint32().swap()

    if record.platformID == 3:
      # Windows format unicode format.
      f.setPosition(cmapOffset + record.offset.int)
      let format = f.readUint16().swap()
      if format == 4:
        var subRecord = SegmentMapping()
        subRecord.format = format
        subRecord.length = f.readUint16().swap()
        subRecord.language = f.readUint16().swap()
        subRecord.segCountX2 = f.readUint16().swap()
        let segCount = (subRecord.segCountX2 div 2).int
        subRecord.searchRange = f.readUint16().swap()
        subRecord.entrySelector = f.readUint16().swap()
        subRecord.rangeShift = f.readUint16().swap()
        subRecord.endCode = f.readUint16Seq(segCount)
        subRecord.reservedPad = f.readUint16().swap()
        subRecord.startCode = f.readUint16Seq(segCount)
        subRecord.idDelta = f.readUint16Seq(segCount)
        let idRangeAddress = f.getPosition()
        subRecord.idRangeOffset = f.readUint16Seq(segCount)
        for j in 0 ..< segCount:
          let endCount = subRecord.endCode[j].uint16
          let startCount = subRecord.startCode[j].uint16
          let idDelta = subRecord.idDelta[j].uint16
          let idRangeOffset = subRecord.idRangeOffset[j].uint16
          for c in startCount .. endCount:
            var glyphIndex = 0
            if idRangeOffset != 0:
              var glyphIndexOffset = idRangeAddress + j * 2
              glyphIndexOffset += int(idRangeOffset)
              glyphIndexOffset += int(c - startCount) * 2
              f.setPosition(glyphIndexOffset)
              glyphIndex = int f.readUint16().swap()
              if glyphIndex != 0:
                glyphIndex = int((uint16(glyphIndex) + idDelta) and 0xFFFF)
            else:
              glyphIndex = int((c + idDelta) and 0xFFFF)
            if c != 65535:
              result.glyphIndexMap[c.int] = glyphIndex
      else:
        # TODO implement other record formats
        discard

    else:
      # TODO implement other cmap formats
      discard

    result.encodingRecords.add(record)

proc readGlyfTable*(f: Stream, loca: LocaTable): GlyfTable =
  result = GlyfTable()

  let glyphOffset = f.getPosition()
  for glyphIndex in 0 ..< loca.offsets.len:
    let locaOffset = loca.offsets[glyphIndex]
    let offset = glyphOffset + locaOffset.int
    result.offsets.add(offset)

proc parseGlyphPath(f: Stream, glyph: Glyph): seq[PathCommand] =
  var endPtsOfContours = newSeq[int]()
  if glyph.numberOfContours >= 0:
    for i in 0 ..< glyph.numberOfContours:
      endPtsOfContours.add int f.readUint16().swap()

  if endPtsOfContours.len == 0:
    return

  let instructionLength = f.readUint16().swap()
  for i in 0..<int(instructionLength):
    discard f.readChar()

  var flags = newSeq[uint8]()

  if glyph.numberOfContours >= 0:
    let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
    var coordinates = newSeq[TtfCoordinate](totalOfCoordinates)

    var i = 0
    while i < totalOfCoordinates:
      let flag = f.readUint8()
      flags.add(flag)
      inc i

      if (flag and 0x8) != 0 and i < totalOfCoordinates:
        let repeat = f.readUint8()
        for j in 0..<int(repeat):
          flags.add(flag)
          inc i

    # Figure out xCoordinates.
    var prevX = 0
    for i, flag in flags:
      var x = 0
      if (flag and 0x2) != 0:
        x = int f.readUint8()
        if (flag and 16) == 0:
          x = -x
      elif (flag and 16) != 0:
        x = 0
      else:
        x = int f.readInt16().swap()
      prevX += x
      coordinates[i].x = prevX
      coordinates[i].isOnCurve = (flag and 1) != 0

    # Figure out yCoordinates.
    var prevY = 0
    for i, flag in flags:
      var y = 0
      if (flag and 0x4) != 0:
        y = int f.readUint8()
        if (flag and 32) == 0:
          y = -y
      elif (flag and 32) != 0:
        y = 0
      else:
        y = int f.readInt16().swap()
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

proc parseCompositeGlyph(f: Stream, glyph: Glyph, font: Font): seq[PathCommand] =
  var moreComponents = true
  var typeface = font.typeface
  while moreComponents:
    let flags = f.readUint16().swap()

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
    component.glyphIndex = f.readUint16().swap()
    component.xScale = 1
    component.yScale = 1

    proc checkBit(flags, bit: uint16): bool =
      (flags.int and bit.int) > 0.int

    if flags.checkBit(1):
      # The arguments are words.
      if flags.checkBit(2):
        # Values are offset.
        component.dx = f.readInt16().swap().float32
        component.dy = f.readInt16().swap().float32
      else:
        # Values are matched points.
        component.matchedPoints = [int f.readUint16().swap(), int f.readUint16().swap()]

    else:
      # The arguments are bytes.
      if flags.checkBit(2):
        # Values are offset.
        component.dx = f.readInt8().float32
        component.dy = f.readInt8().float32
      else:
        # Values are matched points.
        component.matchedPoints = [int f.readInt8(), int f.readInt8()]

    if flags.checkBit(8):
      # We have a scale.
      component.xScale = f.readFixed16()
      component.yScale = component.xScale
    elif flags.checkBit(64):
      # We have an X / Y scale.
      component.xScale = f.readFixed16()
      component.yScale = f.readFixed16()
    elif flags.checkBit(128):
      # We have a 2x2 transformation.
      component.xScale = f.readFixed16()
      component.scale10 = f.readFixed16()
      component.scale01 = f.readFixed16()
      component.yScale = f.readFixed16()

    var subGlyph = typeface.glyphArr[component.glyphIndex]
    if subGlyph.commands.len == 0:
      let savedPosition = f.getPosition()
      parseGlyph(subGlyph, font)
      f.setPosition(savedPosition)

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
    typeface = font.typeface
    otf = typeface.otf
    f = typeface.stream
    index = glyph.index

  f.setPosition(otf.glyf.offsets[index].int)

  if index + 1 < otf.glyf.offsets.len and
    otf.glyf.offsets[index] == otf.glyf.offsets[index + 1]:
    glyph.isEmpty = true
    return

  glyph.numberOfContours = f.readInt16().swap()
  let
    xMin = f.readInt16().swap()
    yMin = f.readInt16().swap()
    xMax = f.readInt16().swap()
    yMax = f.readInt16().swap()
  glyph.bboxMin = vec2(xMin.float32, yMin.float32)
  glyph.bboxMax = vec2(xMax.float32, yMax.float32)

  if glyph.numberOfContours == -1:
    glyph.isComposite = true
    glyph.commands = f.parseCompositeGlyph(glyph, font)
  else:
    glyph.commands = f.parseGlyphPath(glyph)

proc readFontOtf*(f: Stream): Font =

  var otf = OTFFont()
  otf.stream = f
  otf.version = f.readUint32().swap()
  otf.numTables = f.readUint16().swap()
  otf.searchRange = f.readUint16().swap()
  otf.entrySelector = f.readUint16().swap()
  otf.rangeShift = f.readUint16().swap()

  for i in 0 ..< otf.numTables.int:
    var chunk: Chunk
    chunk.tag = f.readStr(4)
    chunk.checkSum = f.readUint32().swap()
    chunk.offset = f.readUint32().swap()
    chunk.length = f.readUint32().swap()
    otf.chunks[chunk.tag] = chunk

  f.setPosition(otf.chunks["head"].offset.int)
  otf.head = f.readHeadTable()

  f.setPosition(otf.chunks["name"].offset.int)
  otf.name = f.readNameTable()

  f.setPosition(otf.chunks["maxp"].offset.int)
  otf.maxp = f.readMaxpTable()

  if "OS/2" in otf.chunks:
    f.setPosition(otf.chunks["OS/2"].offset.int)
    otf.os2 = f.readOS2Table()

  f.setPosition(otf.chunks["loca"].offset.int)
  otf.loca = f.readLocaTable(otf.head, otf.maxp)

  f.setPosition(otf.chunks["hhea"].offset.int)
  otf.hhea = f.readHheaTable()

  f.setPosition(otf.chunks["hmtx"].offset.int)
  otf.hmtx = f.readHmtxTable(otf.maxp, otf.hhea)

  if "kern" in otf.chunks:
    f.setPosition(otf.chunks["kern"].offset.int)
    otf.kern = f.readKernTable()

  f.setPosition(otf.chunks["cmap"].offset.int)
  otf.cmap = f.readCmapTable()

  f.setPosition(otf.chunks["glyf"].offset.int)
  otf.glyf = f.readGlyfTable(otf.loca)

  var font = Font()
  var typeface = Typeface()
  font.typeface = typeface
  typeface.otf = otf
  typeface.stream = f
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

  readFontOtf(newStringStream(readFile(filePath)))

proc readFontTtf*(filePath: string): Font =
  ## OTF Supports most of TTF features.
  readFontOtf(filePath)
