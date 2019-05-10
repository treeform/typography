import tables, streams, strutils, endians, unicode, os, encodings
import font
import vmath, print
import opentypedata

proc read[T](s: Stream, result: var T) =
  if readData(s, addr(result), sizeof(T)) != sizeof(T):
    quit("cannot read from stream at " & $s.getPosition())

proc readUInt8(stream: Stream): uint8 =
  var val: uint8 = 0
  stream.read(val)
  return val

proc readInt8(stream: Stream): int8 =
  var val: int8 = 0
  stream.read(val)
  return val

proc readUInt16(stream: Stream): uint16 =
  var val: uint16 = 0
  stream.read(val)
  swapEndian16(addr val, addr val)
  return val

proc readUint16Seq(stream: Stream, len: int): seq[uint16] =
  result = newSeq[uint16](len)
  for i in 0..<len:
    result[i] = stream.readUInt16()

proc readInt16(stream: Stream): int16 =
  var val: int16 = 0
  stream.read(val)
  swapEndian16(addr val, addr val)
  return val

proc readUInt32(stream: Stream): uint32 =
  var val: uint32 = 0
  stream.read(val)
  swapEndian32(addr val, addr val)
  return val

proc readInt32(stream: Stream): int32 =
  var val: int32 = 0
  stream.read(val)
  swapEndian32(addr val, addr val)
  return val

proc readString(stream: Stream, size: int): string =
  var val = ""
  var i = 0
  while i < size:
    let c = stream.readChar()
    if ord(c) == 0:
      break
    val &= c
    inc i
  while i < size:
    discard stream.readChar()
    inc i
  return val

proc readStringUtf16(stream: Stream, size: int): string =
  for i in 0..<(size div 2):
    let l = stream.readUint8()
    let h = stream.readUint8()
    let code = int(h) + int(l * 255)
    result.add Rune(code).toUTF8()

proc readFixed32(stream: Stream): float =
  var val: int32 = 0
  stream.read(val)
  swapEndian32(addr val, addr val)
  return ceil(float(val) / 65536.0 * 100000.0) / 100000.0

proc readLongDateTime(stream: Stream): float64 =
  discard stream.readUInt32()
  let seconds = stream.readUInt32()
  return float64(seconds - 2082844800) # 1904/1/1

type Chunk = object
  tag: string
  checkSum: uint32
  offset: uint32
  length: uint32

type Head = object
  version: float32
  fontRevision: float32
  checkSumAdjustment: uint32
  magickNumber: uint32
  flags: uint16
  unitsPerEm: uint16
  created: float64
  modified: float64
  xMin: int16
  yMin: int16
  xMax: int16
  yMax: int16
  macStyle: uint16
  lowestRecPPEM:uint16
  fontDirectionHint: int16
  indexToLocFormat: int16
  glyphDataFormat: int16

proc readHead(f: Stream, chunks: Table[string, Chunk]): Head =
  # head
  f.setPosition(int chunks["head"].offset)
  result.version = f.readFixed32()
  result.fontRevision = f.readFixed32()
  result.checkSumAdjustment = f.readUint32()
  result.magickNumber = f.readUint32()
  result.flags = f.readUint16()
  result.unitsPerEm = f.readUint16()
  result.created = f.readLongDateTime()
  result.modified = f.readLongDateTime()
  result.xMin = f.readInt16()
  result.yMin = f.readInt16()
  result.xMax = f.readInt16()
  result.yMax = f.readInt16()
  result.macStyle = f.readUint16()
  result.lowestRecPPEM = f.readUint16()
  result.fontDirectionHint = f.readInt16()
  result.indexToLocFormat = f.readInt16()
  result.glyphDataFormat = f.readInt16()

type LangString = object
  lang: string
  value: string

type Name = object
  format: uint16
  count: uint16
  stringOffset: int
  entries: Table[string, seq[LangString]]


proc getLanguageCode(platformID, languageID: uint16): string =
  case platformID:
    of 0:  # Unicode
      return "en"
    of 1:  # Macintosh
        return macLanguages[int languageID];
    of 3:  # Windows
        return windowsLanguages[int languageID];
    else:
      return "??"


proc readName(f: Stream, chunks: Table[string, Chunk]): Name =
  f.setPosition(int chunks["name"].offset)
  var at = f.getPosition()
  result.format = f.readUint16()
  assert result.format == 0
  result.count = f.readUint16()
  result.stringOffset = int f.readUint16()
  var baseName, fullName: string
  result.entries = initTable[string, seq[LangString]]()
  for i in 0..<(int result.count):
    let platformID = f.readUint16() #Platform identifier code.
    let platformSpecificID = f.readUint16() #Platform-specific encoding identifier.
    let languageID = f.readUint16() #Language identifier.
    let languageCode = getLanguageCode(platformID, languageID)
    let nameID = f.readUint16() #Name identifiers.
    let nameIDEnum = cast[NameTableNames](nameID)
    let length = f.readUint16() #Name string length in bytes.
    let offset = f.readUint16() #Name string offset in bytes from stringOffset.
    let save = f.getPosition()
    f.setPosition(at + result.stringOffset + int(offset))
    let value = f.readStringUtf16(int length)
    if $nameIDEnum notin result.entries:
      result.entries[$nameIDEnum] = @[]
    result.entries[$nameIDEnum].add LangString(lang: languageCode, value: value)
    f.setPosition(save)


type Maxp = object
  version: float
  numGlyphs: uint16
  maxPoints: uint16
  maxCompositePoints: uint16
  maxCompositeContours: uint16
  maxZones: uint16
  maxTwilightPoints: uint16
  maxStorage: uint16
  maxFunctionDefs: uint16
  maxInstructionDefs: uint16
  maxStackElements: uint16
  sizeOfInstructions: uint16
  maxComponentElements: uint16
  maxComponentDepth: uint16

proc readMaxp(f: Stream, chunks: Table[string, Chunk]): Maxp =
  # maxp
  f.setPosition(int chunks["maxp"].offset)
  result.version = f.readFixed32()
  result.numGlyphs = f.readUint16()
  result.maxPoints = f.readUint16()
  result.maxCompositePoints = f.readUint16()
  result.maxCompositeContours = f.readUint16()
  result.maxZones = f.readUint16()
  result.maxTwilightPoints = f.readUint16()
  result.maxStorage = f.readUint16()
  result.maxFunctionDefs = f.readUint16()
  result.maxInstructionDefs = f.readUint16()
  result.maxStackElements = f.readUint16()
  discard f.readUint16()
  result.sizeOfInstructions = f.readUint16()
  result.maxComponentElements = f.readUint16()
  result.maxComponentDepth = f.readUint16()


type Os2 = object
  version: uint16
  xAvgCharWidth: int16
  usWeightClass: uint16
  usWidthClass: uint16
  fsType: uint16
  ySubscriptXSize: int16
  ySubscriptYSize: int16
  ySubscriptXOffset: int16
  ySubscriptYOffset: int16
  ySuperscriptXSize: int16
  ySuperscriptYSize: int16
  ySuperscriptXOffset: int16
  ySuperscriptYOffset: int16
  yStrikeoutSize: int16
  yStrikeoutPosition: int16
  sFamilyClass: int16
  panose: seq[uint8]
  ulUnicodeRange1: uint32
  ulUnicodeRange2: uint32
  ulUnicodeRange3: uint32
  ulUnicodeRange4: uint32
  achVendID: seq[uint8]
  fsSelection: uint32
  usFirstCharIndex: uint32
  usLastCharIndex: uint32
  ascent: int16
  descent: int16
  sTypoLineGap: int16
  usWinAscent: uint16
  usWinDescent: uint16
  ulCodePageRange1: uint32
  ulCodePageRange2: uint32
  sxHeight: int16
  sCapHeight: int16
  usDefaultChar: uint16
  usBreakChar: uint16
  usMaxContent: uint16

proc readOs2(f: Stream, chunks: Table[string, Chunk]): Os2 =
  f.setPosition(int chunks["OS/2"].offset)
  result.version = f.readUInt16()
  result.xAvgCharWidth = f.readInt16()
  result.usWeightClass = f.readUInt16()
  result.usWidthClass = f.readUInt16()
  result.fsType = f.readUInt16()
  result.ySubscriptXSize = f.readInt16()
  result.ySubscriptYSize = f.readInt16()
  result.ySubscriptXOffset = f.readInt16()
  result.ySubscriptYOffset = f.readInt16()
  result.ySuperscriptXSize = f.readInt16()
  result.ySuperscriptYSize = f.readInt16()
  result.ySuperscriptXOffset = f.readInt16()
  result.ySuperscriptYOffset = f.readInt16()
  result.yStrikeoutSize = f.readInt16()
  result.yStrikeoutPosition = f.readInt16()
  result.sFamilyClass = f.readInt16()

  for i in 0..<10:
    result.panose.add f.readUInt8()

  result.ulUnicodeRange1 = f.readUInt32()
  result.ulUnicodeRange2 = f.readUInt32()
  result.ulUnicodeRange3 = f.readUInt32()
  result.ulUnicodeRange4 = f.readUInt32()
  result.achVendID = @[f.readUInt8(), f.readUInt8(), f.readUInt8(), f.readUInt8()]
  result.fsSelection = f.readUInt16()
  result.usFirstCharIndex = f.readUInt16()
  result.usLastCharIndex = f.readUInt16()
  result.ascent = f.readInt16()
  result.descent = f.readInt16()
  result.sTypoLineGap = f.readInt16()
  result.usWinAscent = f.readUInt16()
  result.usWinDescent = f.readUInt16()
  if result.version >= 1.uint16:
      result.ulCodePageRange1 = f.readUInt32()
      result.ulCodePageRange2 = f.readUInt32()
  if result.version >= 2.uint16:
      result.sxHeight = f.readInt16()
      result.sCapHeight = f.readInt16()
      result.usDefaultChar = f.readUInt16()
      result.usBreakChar = f.readUInt16()
      result.usMaxContent = f.readUInt16()


type Loca = object
  loca: seq[int]
  offsetSize: seq[int]

proc readLoca(f: Stream, chunks: Table[string, Chunk], head: Head, maxp: Maxp): Loca =
  f.setPosition(int chunks["loca"].offset)
  result.loca = newSeq[int]()
  var locaOffset = int chunks["loca"].offset
  result.offsetSize = newSeq[int]()

  if head.indexToLocFormat == 0:
    # locaType Uint16
    for i in 0..<int(maxp.numGlyphs):
      result.loca.add int f.readUint16() * 2
      result.offsetSize.add int locaOffset
      locaOffset += 2
  else:
    # locaType Uint32
    for i in 0..<int(maxp.numGlyphs):
      result.loca.add int f.readUint32()
      result.offsetSize.add int locaOffset
      locaOffset += 4

type Hhea = object
  majorVersion: uint16
  minorVersion: uint16
  ascent: int16
  descent: int16
  lineGap: int16
  advanceWidthMax: uint16
  minLeftSideBearing: int16
  minRightSideBearing: int16
  xMaxExtent: int16
  caretSlopeRise: int16
  caretSlopeRun: int16
  caretOffset: int16
  metricDataFormat: int16
  numberOfHMetrics: uint16

proc readHhea(f: Stream, chunks: Table[string, Chunk]): Hhea =
  f.setPosition(int chunks["hhea"].offset)
  result.majorVersion = f.readUInt16()
  assert result.majorVersion == 1
  result.minorVersion = f.readUInt16()
  assert result.minorVersion == 0
  result.ascent = f.readInt16()
  result.descent = f.readInt16()
  result.lineGap = f.readInt16()
  result.advanceWidthMax = f.readUInt16()
  result.minLeftSideBearing = f.readInt16()
  result.minRightSideBearing = f.readInt16()
  result.xMaxExtent = f.readInt16()
  result.caretSlopeRise = f.readInt16()
  result.caretSlopeRun = f.readInt16()
  result.caretOffset = f.readInt16()
  discard f.readUInt16()
  discard f.readUInt16()
  discard f.readUInt16()
  discard f.readUInt16()
  result.metricDataFormat = f.readInt16()
  assert result.metricDataFormat == 0
  result.numberOfHMetrics = f.readUInt16()

type Hmtx = object
  advanceWidths: seq[uint16]
  leftSideBearings: seq[int16]

proc readHmtx(f: Stream, chunks: Table[string, Chunk], maxp: Maxp, hhea: Hhea): Hmtx =
  # hmtx
  f.setPosition(int chunks["hmtx"].offset)
  for i in 0..<int(maxp.numGlyphs):
    if i < int hhea.numberOfHMetrics:
      result.advanceWidths.add f.readUInt16()
      result.leftSideBearings.add f.readInt16()

type Cmap = object
  version: uint16
  numberSubtables: uint16
  platformID: uint16
  platformSpecificID: uint16
  format: uint16
  mapping: Table[int, int]
  mappingRev: Table[int, int]

proc readCmap(f: Stream, chunks: Table[string, Chunk], head: Head, maxp: Maxp): Cmap =
  # cmap
  var glyphsIndexToRune = newSeq[string](maxp.numGlyphs)
  f.setPosition(int chunks["cmap"].offset)
  let cmapOffset = int chunks["cmap"].offset
  result.version = f.readUint16()
  result.numberSubtables = f.readUint16()

  for i in 0..<int(result.numberSubtables):
    result.platformID = f.readUint16()
    result.platformSpecificID = f.readUint16()
    let tableOffset = f.readUint32()

    if result.platformID == 3: # we are only going to use Windows cmap
      f.setPosition(cmapOffset + int tableOffset)
      result.format = f.readUint16()
      if result.format == 4:
        # why is this so hard?
        # just a mapping of unicode -> id
        result.mapping = initTable[int, int]()
        result.mappingRev = initTable[int, int]()

        let cmapLength = f.readUint16()
        let cmapLanguage = f.readUint16()
        let segCount = f.readUint16() div 2
        let searchRange = f.readUint16()
        let entrySelector = f.readUint16()
        let rangeShift = f.readUint16()

        let endCountSeq = f.readUint16Seq(int segCount)
        discard f.readUint16()
        let startCountSeq = f.readUint16Seq(int segCount)
        let idDeltaSeq = f.readUint16Seq(int segCount)
        let idRangeAddress =  f.getPosition()
        let idRangeOffsetSeq = f.readUint16Seq(int segCount)
        var glyphIndexAddress = f.getPosition()
        for j in 0..<int(segCount):
          var glyphIndex = 0
          let endCount = endCountSeq[j]
          let startCount = startCountSeq[j]
          let idDelta = idDeltaSeq[j]
          let idRangeOffset = idRangeOffsetSeq[j]

          for c in startCount..endCount:
            if idRangeOffset != 0:
                var glyphIndexOffset = idRangeAddress + j * 2
                glyphIndexOffset += int(idRangeOffset)
                glyphIndexOffset += int(c - startCount) * 2
                f.setPosition(glyphIndexOffset)
                glyphIndex = int f.readUint16()
                if glyphIndex != 0:
                    glyphIndex = int((uint16(glyphIndex) + idDelta) and 0xFFFF)

            else:
              glyphIndex = int((c + idDelta) and 0xFFFF)

            if glyphIndex < int maxp.numGlyphs:
              result.mapping[int c] = glyphIndex
              result.mappingRev[glyphIndex] = int c
            else:
              discard

type Kern = object
  version: uint16
  numTables: uint16
  subtableVersion: uint16
  subtableLength: uint16
  subtableCoverage: uint16
  numPairs: uint16
  searchRange: uint16
  entrySelector: uint16
  rangeShift: uint16
  kerning: Table[(int, int), int]

proc readKern(f: Stream, chunks: Table[string, Chunk], head: Head, maxp: Maxp): Kern =
  result.kerning = initTable[(int, int), int]()
  # kern
  if "kern" in chunks:
    f.setPosition(int chunks["kern"].offset)
    result.version = f.readUint16()
    if result.version == 0:
      # Windows format
      result.numTables = f.readUint16()
      result.subtableVersion = f.readUint16()
      assert result.subtableVersion == 0
      result.subtableLength = f.readUint16()
      result.subtableCoverage = f.readUint16()
      result.numPairs = f.readUint16()
      result.searchRange = f.readUint16()
      result.entrySelector = f.readUint16()
      result.rangeShift = f.readUint16()
      for i in 0..<int(result.numPairs):
        let leftIndex = f.readUint16()
        let rightIndex = f.readUint16()
        let value = f.readInt16()
        result.kerning[(int leftIndex, int rightIndex)] = value
    elif result.version == 1:
      # Mac format
      assert false
    else:
      assert false


type Glyf = object
  table: Table[int, Glyph]
  list: seq[Glyph]

proc readGlyf(f: Stream, chunks: Table[string, Chunk], head: Head, maxp: Maxp, loca: Loca): Glyf =
  # glyf
  f.setPosition(int chunks["glyf"].offset)
  result.table = initTable[int, Glyph]()
  result.list = newSeq[Glyph](loca.loca.len)
  let glyphOffset = int chunks["glyf"].offset
  for glyphIndex in 0..<loca.loca.len:
    let locaOffset = loca.loca[glyphIndex]
    let offset = glyphOffset + locaOffset
    f.setPosition(int offset)
    if not result.table.hasKey(offset):

      result.table[offset] = Glyph()
      result.table[offset].ready = false

      var isNull = glyphIndex + 1 < loca.loca.len and loca.loca[glyphIndex] == loca.loca[glyphIndex + 1]
      if isNull:
        result.table[offset].isEmpty = true
        result.table[offset].ready = true

      let numberOfContours = f.readInt16()
      if numberOfContours <= 0:
        result.table[offset].isEmpty = true
        result.table[offset].ready = true

      if not result.table[offset].isEmpty:
        result.table[offset].ttfStream = f
        result.table[offset].ttfOffset = offset
        result.table[offset].numberOfContours = numberOfContours

    result.list[glyphIndex] = result.table[offset]


proc readFontOTF*(filename: string): Font =
  ## Reads OTF font
  var font = Font()

  if not existsFile(filename):
    raise newException(IOError, "File name " & filename & " not found")

  var f = newFileStream(filename, fmRead)
  var version = f.readFixed32()
  #assert version == 1.0

  var numTables = f.readUInt16()
  #assert numTables == 21

  var searchRenge = f.readUInt16()
  #assert searchRenge == 256

  var entrySelector = f.readUInt16()
  #assert entrySelector == 4

  var rengeShift = f.readUInt16()
  #assert rengeShift == 80

  var chunks = initTable[string, Chunk]()

  for i in 0..<int(numTables):
    var chunk: Chunk
    chunk.tag = f.readString(4)
    chunk.checkSum = f.readUInt32()
    chunk.offset = f.readUInt32()
    chunk.length = f.readUInt32()
    chunks[chunk.tag] = chunk

    echo chunk.tag

  let head = f.readHead(chunks)
  echo head
  let name = f.readName(chunks)
  let maxp = f.readMaxp(chunks)
  echo maxp
  let os2 = f.readOs2(chunks)
  echo os2
  let loca = f.readLoca(chunks, head, maxp)
  # echo loca
  let hhea = f.readHhea(chunks)
  echo hhea
  let hmtx = f.readHmtx(chunks, maxp, hhea)
  echo hmtx
  let cmap = f.readCmap(chunks, head, maxp)
  #echo cmap
  let kern = f.readKern(chunks, head, maxp)
  echo kern
  let glyf = f.readGlyf(chunks, head, maxp, loca)
  echo glyf


  # convert tables to font vars
  font.unitsPerEm = float head.unitsPerEm
  font.bboxMin = vec2(float head.xMin, float head.yMin)
  font.bboxMax = vec2(float head.xMax, float head.yMax)
  font.ascent = float os2.ascent
  font.descent = float os2.descent

  if "fontFamily" in name.entries and name.entries.len > 0:
    font.name = name.entries["fontFamily"][0].value

  font.glyphs = initTable[string, Glyph]()
  for k, glyph in glyf.table.pairs():
    let uni = Rune(k).toUTF8()
    glyph.code = uni
    font.glyphs[uni] = glyph

  font.kerning = initTable[string, float]()
  for k, value in kern.kerning.pairs():
    if (int k[0]) in cmap.mappingRev and (int k[1]) in cmap.mappingRev:
      let u1 = Rune(cmap.mappingRev[int k[0]]).toUTF8()
      let u2 = Rune(cmap.mappingRev[int k[1]]).toUTF8()
      if u1.len > 0 and u2.len > 0:
            font.kerning[u1 & ":" & u2] = float value

  return font

proc ttfGlyphToPath*(glyph: var Glyph) =
  var
    f = glyph.ttfStream
    offset = glyph.ttfOffset

  f.setPosition(0)
  f.setPosition(int offset)
  let numberOfContours = f.readInt16()
  assert numberOfContours == glyph.numberOfContours

  type TtfCoridante = object
    x: int
    y: int
    isOnCurve: bool

  let xMin = f.readInt16()
  let yMin = f.readInt16()
  let xMax = f.readInt16()
  let yMax = f.readInt16()

  var endPtsOfContours = newSeq[int]()
  if numberOfContours >= 0:
    for i in 0..<numberOfContours:
      endPtsOfContours.add int f.readUint16()

  if endPtsOfContours.len == 0:
    return

  let instructionLength = f.readUint16()
  for i in 0..<int(instructionLength):
    discard f.readChar()

  let flagsOffset = f.getPosition()
  var flags = newSeq[uint8]()

  if numberOfContours >= 0:
    let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
    var coordinates = newSeq[TtfCoridante](totalOfCoordinates)

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

    # xCoordinates
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
        x = int f.readInt16()
      prevX += x
      coordinates[i].x = prevX
      coordinates[i].isOnCurve = (flag and 1) != 0

    # yCoordinates
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
        y = int f.readInt16()
      prevY += y
      coordinates[i].y = prevY

    # make an svg path out of this crazy stuff
    var path = ""
    var
      startPts = 0
      currentPts = 0
      endPts = 0
      prevPoint: TtfCoridante
      currentPoint: TtfCoridante
      nextPoint: TtfCoridante

    for i in 0..<endPtsOfContours.len:
      endPts = endPtsOfContours[i]
      while currentPts < endPts + 1:
        currentPoint = coordinates[currentPts]
        if currentPts != startPts:
          prevPoint = coordinates[currentPts - 1]
        else:
          prevPoint = coordinates[endPts]
        if currentPts != endPts and currentPts + 1 < coordinates.len:
          nextPoint = coordinates[currentPts + 1]
        else:
          nextPoint = coordinates[startPts]

        if currentPts == startPts:
          if currentPoint.isOnCurve:
            path.add "M" & $currentPoint.x & "," & $currentPoint.y & " "
          else:
            path.add "M" & $prevPoint.x & "," & $prevPoint.y & " "
            path.add "Q" & $currentPoint.x & "," & $currentPoint.y & " "
        else:
          if currentPoint.isOnCurve and prevPoint.isOnCurve:
            path.add " L"
          elif not currentPoint.isOnCurve and not prevPoint.isOnCurve:
            var midx = (prevPoint.x + currentPoint.x) div 2
            var midy = (prevPoint.y + currentPoint.y) div 2
            path.add $midx & "," & $midy & " "
          elif not currentPoint.isOnCurve:
            path.add " Q"
          path.add $currentPoint.x & "," & $currentPoint.y & " "

        inc currentPts

      if not currentPoint.isOnCurve:
        if coordinates[startPts].isOnCurve:
          path.add $coordinates[startPts].x & "," & $coordinates[startPts].y & " "
        else:
          var midx = (prevPoint.x + currentPoint.x) div 2
          var midy = (prevPoint.y + currentPoint.y) div 2
          path.add $midx & "," & $midy & " "
      path.add " Z "
      startPts = endPtsOfContours[i] + 1

    glyph.path = path


proc ttfGlyphToCommands*(glyph: var Glyph) =
  var
    f = glyph.ttfStream
    offset = glyph.ttfOffset

  f.setPosition(0)
  f.setPosition(int offset)
  let numberOfContours = f.readInt16()
  assert numberOfContours == glyph.numberOfContours

  type TtfCoridante = object
    x: int
    y: int
    isOnCurve: bool

  let xMin = f.readInt16()
  let yMin = f.readInt16()
  let xMax = f.readInt16()
  let yMax = f.readInt16()

  var endPtsOfContours = newSeq[int]()
  if numberOfContours >= 0:
    for i in 0..<numberOfContours:
      endPtsOfContours.add int f.readUint16()

  if endPtsOfContours.len == 0:
    return

  let instructionLength = f.readUint16()
  for i in 0..<int(instructionLength):
    discard f.readChar()

  let flagsOffset = f.getPosition()
  var flags = newSeq[uint8]()

  if numberOfContours >= 0:
    let totalOfCoordinates = endPtsOfContours[endPtsOfContours.len - 1] + 1
    var coordinates = newSeq[TtfCoridante](totalOfCoordinates)

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

    # xCoordinates
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
        x = int f.readInt16()
      prevX += x
      coordinates[i].x = prevX
      coordinates[i].isOnCurve = (flag and 1) != 0

    # yCoordinates
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
        y = int f.readInt16()
      prevY += y
      coordinates[i].y = prevY

    # make an svg path out of this crazy stuff
    var path = newSeq[PathCommand]()

    proc cmd(kind: PathCommandKind, x, y: int) =
      path.add PathCommand(kind: kind, numbers: @[float x, float y])

    proc cmd(kind: PathCommandKind) =
      path.add PathCommand(kind: kind, numbers: @[])

    proc cmd(x, y: int) =
      path[^1].numbers.add float(x)
      path[^1].numbers.add float(y)

    var
      startPts = 0
      currentPts = 0
      endPts = 0
      prevPoint: TtfCoridante
      currentPoint: TtfCoridante
      nextPoint: TtfCoridante

    for i in 0..<endPtsOfContours.len:
      endPts = endPtsOfContours[i]
      while currentPts < endPts + 1:
        currentPoint = coordinates[currentPts]
        if currentPts != startPts:
          prevPoint = coordinates[currentPts - 1]
        else:
          prevPoint = coordinates[endPts]
        if currentPts != endPts and currentPts + 1 < coordinates.len:
          nextPoint = coordinates[currentPts + 1]
        else:
          nextPoint = coordinates[startPts]

        if currentPts == startPts:
          if currentPoint.isOnCurve:
            cmd(Move, currentPoint.x, currentPoint.y)
          else:
            cmd(Move, prevPoint.x, prevPoint.y)
            cmd(Quad, currentPoint.x, currentPoint.y)
        else:
          if currentPoint.isOnCurve and prevPoint.isOnCurve:
            cmd(Line)
          elif not currentPoint.isOnCurve and not prevPoint.isOnCurve:
            var midx = (prevPoint.x + currentPoint.x) div 2
            var midy = (prevPoint.y + currentPoint.y) div 2
            cmd(midx, midy)
          elif not currentPoint.isOnCurve:
            cmd(Quad)
          cmd(currentPoint.x, currentPoint.y)

        inc currentPts

      if not currentPoint.isOnCurve:
        if coordinates[startPts].isOnCurve:
         cmd(coordinates[startPts].x, coordinates[startPts].y)
        else:
          var midx = (prevPoint.x + currentPoint.x) div 2
          var midy = (prevPoint.y + currentPoint.y) div 2
          cmd(midx, midy)
      cmd(End)
      startPts = endPtsOfContours[i] + 1

    glyph.commands = path


