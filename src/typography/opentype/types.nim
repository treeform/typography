import tables, streams

type
  Offset16 = uint16
  Offset32 = uint32

  HeadTable* = ref object
    majorVersion*: uint16 ## Major version number of the font header table — set to 1.
    minorVersion*: uint16 ## Minor version number of the font header table — set to 0.
    fontRevision*: float ## Set by font manufacturer.
    checkSumAdjustment*: uint32 #
    magicNumber*: uint32 ## Set to 0x5F0F3CF5.
    flags*: uint16
    unitsPerEm*: uint16 ## Set to a value from 16 to 16384.
    created*: float64
    modified*: float64
    xMin*: int16 ## For all glyph bounding boxes.
    yMin*: int16 ## For all glyph bounding boxes.
    xMax*: int16 ## For all glyph bounding boxes.
    yMax*: int16 ## For all glyph bounding boxes.
    macStyle*: uint16
    lowestRecPPEM*: uint16 ## Smallest readable size in pixels.
    fontDirectionHint*: int16 ## Deprecated
    indexToLocFormat*: int16 ## for short offsets (Offset16), 1 for (Offset32).
    glyphDataFormat*: int16 ## 0 for current format.

  NameTable* = ref object
    format*: uint16
    count*: uint16
    stringOffset*: Offset16
    nameRecords*: seq[NameRecord]

  NameRecord* = object
    platformID*: uint16 # Platform ID.
    encodingID*: uint16 # Platform-specific encoding ID.
    languageID*: uint16 # Language ID.
    nameID*: uint16 # Name ID.
    name*: NameTableNames
    length*: uint16 # String length (in bytes).
    offset*: Offset16 # String offset from start of storage area (in bytes).

    text*: string

  NameTableNames* = enum
    ntnCopyright,              # 0
    ntnFontFamily,             # 1
    ntnFontSubfamily,          # 2
    ntnUniqueID,               # 3
    ntnFullName,               # 4
    ntnVersion,                # 5
    ntnPostScriptName,         # 6
    ntnTrademark,              # 7
    ntnManufacturer,           # 8
    ntnDesigner,               # 9
    ntnDescription,            # 10
    ntnManufacturerURL,        # 11
    ntnDesignerURL,            # 12
    ntnLicense,                # 13
    ntnLicenseURL,             # 14
    ntnReserved,               # 15
    ntnPreferredFamily,        # 16
    ntnPreferredSubfamily,     # 17
    ntnCompatibleFullName,     # 18
    ntnSampleText,             # 19
    ntnPostScriptFindFontName, # 20
    ntnWwsFamily,              # 21
    ntnWwsSubfamily            # 22

  MaxpTable* = ref object
    version*: float ## 0x00010000 for version 1.0.
    numGlyphs*: uint16 ## The number of glyphs in the otf.
    maxPoints*: uint16 ## Maximum points in a non-composite glyph.
    maxContours*: uint16 ## Maximum contours in a non-composite glyph.
    maxCompositePoints*: uint16 ## Maximum points in a composite glyph.
    maxCompositeContours*: uint16 ## Maximum contours in a composite glyph.
    maxZones*: uint16 ## 1 if instructions do not use the twilight zone (Z0), or 2 if instructions do use Z0; should be set to 2 in most cases.
    maxTwilightPoints*: uint16 ## Maximum points used in Z0.
    maxStorage*: uint16 ## Number of Storage Area locations.
    maxFunctionDefs*: uint16 ## Number of FDEFs, equal to the highest function number + 1.
    maxInstructionDefs*: uint16 ## Number of IDEFs.
    maxStackElements*: uint16 ## Maximum stack depth across Font Program ('fpgm' table), CVT Program ('prep' table) and all glyph instructions (in the 'glyf' table).
    maxSizeOfInstructions*: uint16 ## Maximum byte count for glyph instructions.
    maxComponentElements*: uint16 ## Maximum number of components referenced at “top level” for any composite glyph.
    maxComponentDepth*: uint16 ## Maximum levels of recursion; 1 for simple components.

  OS2Table* = ref object
    version*: uint16
    xAvgCharWidth*: int16
    usWeightClass*: uint16
    usWidthClass*: uint16
    fsType*: uint16
    ySubscriptXSize*: int16
    ySubscriptYSize*: int16
    ySubscriptXOffset*: int16
    ySubscriptYOffset*: int16
    ySuperscriptXSize*: int16
    ySuperscriptYSize*: int16
    ySuperscriptXOffset*: int16
    ySuperscriptYOffset*: int16
    yStrikeoutSize*: int16
    yStrikeoutPosition*: int16
    sFamilyClass*: int16
    panose*: array[10, uint8]
    ulUnicodeRange1*: uint32
    ulUnicodeRange2*: uint32
    ulUnicodeRange3*: uint32
    ulUnicodeRange4*: uint32
    achVendID*: string
    fsSelection*: uint16
    usFirstCharIndex*: uint16
    usLastCharIndex*: uint16
    sTypoAscender*: int16
    sTypoDescender*: int16
    sTypoLineGap*: int16
    usWinAscent*: uint16
    usWinDescent*: uint16
    ulCodePageRange1*: uint32
    ulCodePageRange2*: uint32
    sxHeight*: int16
    sCapHeight*: int16
    usDefaultChar*: uint16
    usBreakChar*: uint16
    usMaxContext*: uint16
    usLowerOpticalPointSize*: uint16
    usUpperOpticalPointSize*: uint16

  LocaTable* = ref object
    offsets*: seq[uint32]

  HheaTable* = ref object
    ## Horizontal Header Table.
    majorVersion*: uint16 ## Major version number of the horizontal header table — set to 1.
    minorVersion*: uint16 ## Minor version number of the horizontal header table — set to 0.
    ascender*: int16 ## Typographic ascent (Distance from baseline of highest ascender).
    descender*: int16 ## Typographic descent (Distance from baseline of lowest descender).
    lineGap*: int16 ## Typographic line gap. Negative LineGap values are treated as zero in some legacy platform implementations.
    advanceWidthMax*: uint16 ## Maximum advance width value in 'hmtx' table.
    minLeftSideBearing*: int16 ## Minimum left sidebearing value in 'hmtx' table.
    minRightSideBearing*: int16 ## Minimum right sidebearing value; calculated as Min(aw - lsb - (xMax - xMin)).
    xMaxExtent*: int16 ## Max(lsb + (xMax - xMin)).
    caretSlopeRise*: int16 ## Used to calculate the slope of the cursor (rise/run); 1 for vertical.
    caretSlopeRun*: int16 ## 0 for vertical.
    caretOffset*: int16 ## The amount by which a slanted highlight on a glyph needs to be shifted to produce the best appearance. Set to 0 for non-slanted fonts
    metricDataFormat*: int16 ## 0 for current format.
    numberOfHMetrics*: uint16 ## Number of hMetric entries in 'hmtx' table.

  HmtxTable* = ref object
    ## Horizontal Metrics Table
    hMetrics*: seq[LongHorMetricRecrod]
    leftSideBearings*: seq[int16]

  LongHorMetricRecrod* = object
    advanceWidth*: uint16 ## Advance width, in font design units.
    lsb*: int16 ## Glyph left side bearing, in font design units.

  KernTable* = ref object
    version*: uint16 ## Table version number (0)
    nTables*: uint16 ## Number of subtables in the kerning table.
    subTables*: seq[KernSubTable]

  KernSubTable* = object
    version*: uint16
    length*: uint16
    coverage*: uint16

    numPairs*: uint16
    searchRange*: uint16
    entrySelector*: uint16
    rangeShift*: uint16

    kerningPairs*: seq[KerningPair]

  KerningPair* = object
    left*: uint16
    right*: uint16
    value*: int16

  CmapTable* = ref object
    version*: uint16 ## Table version number (0).
    numTables*: uint16 ##	Number of encoding tables that follow.
    encodingRecords*: seq[EncodingRecord]
    glyphIndexMap*: Table[int, int]

  EncodingRecord* = object
    platformID*: uint16 ## Platform ID.
    encodingID*: uint16 ## Platform-specific encoding ID.
    offset*: Offset32 ## Byte offset from beginning of table to the subtable for this encoding.

  SegmentMapping* = ref object
    format*: uint16 ## Format number is set to 4.
    length*: uint16 ## This is the length in bytes of the subtable.
    language*: uint16 ## For requirements on use of the language field, see “Use of the language field in 'cmap' subtables” in this document.
    segCountX2*: uint16 ## 2 × segCount.
    searchRange*: uint16 ## 2 × (2**floor(log2(segCount)))
    entrySelector*: uint16 ## log2(searchRange/2)
    rangeShift*: uint16 ## 2 × segCount - searchRange
    endCode*: seq[uint16] ## [segCount]	End characterCode for each segment, last=0xFFFF.
    reservedPad*: uint16 ## Set to 0.
    startCode*: seq[uint16] ## [segCount]	Start character code for each segment.
    idDelta*: seq[uint16] ## [segCount]	Delta for all character codes in segment.
    idRangeOffset*: seq[uint16] ## [segCount]	Offsets into glyphIdArray or 0
    glyphIdArray*: seq[uint16] ## Glyph index array (arbitrary length)

  GlyfTable* = ref object
    offsets*: seq[int]

  # GlyphRecord = ref object
  #   numberOfContours: int16 ## If the number of contours is greater than or equal to zero, this is a simple glyph. If negative, this is a composite glyph — the value -1 should be used for composite glyphs.
  #   xMin: int16 ## Minimum x for coordinate data.
  #   yMin: int16 ## Minimum y for coordinate data.
  #   xMax: int16 ## Maximum x for coordinate data.
  #   yMax: int16 ## Maximum y for coordinate data.

  #   isNull: bool ## if glyph occupies 0 bytes
  #   isComposite: bool ## if numberOfContours is -1
  #   path: seq[PathCommand]

  TtfCoridante* = object
    x*: int
    y*: int
    isOnCurve*: bool

  Chunk* = object
    tag*: string
    checkSum*: uint32
    offset*: uint32
    length*: uint32

  OtfFont* = ref object
    stream*: Stream
    version*: float
    numTables*: uint16
    searchRenge*: uint16
    entrySelector*: uint16
    rengeShift*: uint16

    chunks*: Table[string, Chunk]

    head*: HeadTable
    name*: NameTable
    maxp*: MaxpTable
    os2*: OS2Table
    loca*: LocaTable
    hhea*: HheaTable
    hmtx*: HmtxTable
    kern*: KernTable
    cmap*: CmapTable
    glyf*: GlyfTable