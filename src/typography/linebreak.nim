import strutils, tables, unicode

type
  BreakRegon = object
    start: int
    stop: int
    code: BreakCode

  BreakCode {.pure.} = enum
    MandatoryBreak           # table["BK"] = BreakCode.Cause a line break (after)
    CarriageReturn           # CR Cause a line break (after), except between CR and LF
    LineFeed                 # LF Cause a line break (after)
    CombiningMark # CM Prohibit a line break between the character and the preceding character
    NextLine                 # NL Cause a line break (after)
    Surrogate                # SG Do not occur in well-formed text
    WordJoiner               # WJ Prohibit line breaks before and after
    ZeroWidthSpace           # ZW Provide a break opportunity
    NonBreaking              # GL Prohibit line breaks before and after
    Space                    # SP Enable indirect line breaks
    ZeroWidthJoiner          # ZWJ Prohibit line breaks within joiner sequences
    ## Break Opportunities
    BreakOpportunityBeforeAndAfter # B2 Provide a line break opportunity before and after the character
    BreakAfter # BA Generally provide a line break opportunity after the character
    BreakBefore # BB Generally provide a line break opportunity before the character
    Hyphen # HY Provide a line break opportunity after the character, except in numeric context
    ContingentBreakOpportunity # CB Provide a line break opportunity contingent on additional information
    ## Characters Prohibiting Certain Breaks
    ClosePunctuation         # CL Prohibit line breaks before
    CloseParenthesis         # CP Prohibit line breaks before
    ExclamationInterrogation # EX Prohibit line breaks before
    Inseparable              # IN Allow only indirect line breaks between pairs
    Nonstarter               # NS Allow only indirect line breaks before
    OpenPunctuation          # OP Prohibit line breaks after
    Quotation                # QU Act like they are both opening and closing
    ## Numeric Context
    InfixNumericSeparator    # IS Prevent breaks after any and before numeric
    Numeric                  # NU Form numeric expressions for line breaking purposes
    PostfixNumeric           # PO Do not break following a numeric expression
    PrefixNumeric            # PR Do not break in front of a numeric expression
    SymbolsAllowingBreakAfter # SY Prevent a break before, and allow a break after
    ## Other Characters
    Ambiguous # (Alphabetic or Ideographic) AI Act like AL when the resolved EAW is N; otherwise, act as ID
    Alphabetic # AL Are alphabetic characters or symbols that are used with alphabetic characters
    ConditionalJapaneseStarter # CJ Treat as NS or ID for strict or normal breaking.
    EmojiBase                # EB Do not break from following Emoji Modifier
    EmojiModifier            # EM Do not break from preceding Emoji Base
    HangulLVSyllable         # H2 Form Korean syllable blocks
    HangulLVTSyllable        # H3 Form Korean syllable blocks
    HebrewLetter # HL Do not break around a following hyphen; otherwise act as Alphabetic
    Ideographic              # ID Break before or after, except in some numeric context
    HangulLJamo              # JL Form Korean syllable blocks
    HangulVJamo              # JV Form Korean syllable blocks
    HangulTJamo              # JT Form Korean syllable blocks
    RegionalIndicator # RI Keep pairs together. For pairs, break before and after other classes
    ComplexContextDependent # South East Asian SA Provide a line break opportunity contingent on additional, language-specific context analysis
    Unknown # XX Have as yet unknown line breaking behavior or unassigned code positions

var table = newTable[string, BreakCode]()
table["BK"] = BreakCode.MandatoryBreak
table["CR"] = BreakCode.CarriageReturn
table["LF"] = BreakCode.LineFeed
table["CM"] = BreakCode.CombiningMark
table["NL"] = BreakCode.NextLine
table["SG"] = BreakCode.Surrogate
table["WJ"] = BreakCode.WordJoiner
table["ZW"] = BreakCode.ZeroWidthSpace
table["GL"] = BreakCode.NonBreaking
table["SP"] = BreakCode.Space
table["ZWJ"] = BreakCode.ZeroWidthJoiner
table["B2"] = BreakCode.BreakOpportunityBeforeAndAfter
table["BA"] = BreakCode.BreakAfter
table["BB"] = BreakCode.BreakBefore
table["HY"] = BreakCode.Hyphen
table["CB"] = BreakCode.ContingentBreakOpportunity
table["CL"] = BreakCode.ClosePunctuation
table["CP"] = BreakCode.CloseParenthesis
table["EX"] = BreakCode.ExclamationInterrogation
table["IN"] = BreakCode.Inseparable
table["NS"] = BreakCode.Nonstarter
table["OP"] = BreakCode.OpenPunctuation
table["QU"] = BreakCode.Quotation
table["IS"] = BreakCode.InfixNumericSeparator
table["NU"] = BreakCode.Numeric
table["PO"] = BreakCode.PostfixNumeric
table["PR"] = BreakCode.PrefixNumeric
table["SY"] = BreakCode.SymbolsAllowingBreakAfter
table["AI"] = BreakCode.Ambiguous
table["AL"] = BreakCode.Alphabetic
table["CJ"] = BreakCode.ConditionalJapaneseStarter
table["EB"] = BreakCode.EmojiBase
table["EM"] = BreakCode.EmojiModifier
table["H2"] = BreakCode.HangulLVSyllable
table["H3"] = BreakCode.HangulLVTSyllable
table["HL"] = BreakCode.HebrewLetter
table["ID"] = BreakCode.Ideographic
table["JL"] = BreakCode.HangulLJamo
table["JV"] = BreakCode.HangulVJamo
table["JT"] = BreakCode.HangulTJamo
table["RI"] = BreakCode.RegionalIndicator
table["SA"] = BreakCode.ComplexContextDependent
table["XX"] = BreakCode.Unknown

var breakRegons = newSeq[BreakRegon]()

const lineBreakText = staticRead("linebreak.txt")
for line in lineBreakText.splitLines:
  var line = line
  let index = line.find('#')
  if index >= 0:
    line = line[0..<index]
  if line.len == 0:
    continue
  var arr = line.split(";")
  let code = arr[1].strip()
  var range = arr[0].split("..")
  var start = 0
  var stop = 0
  if range.len == 1:
    start = parseHexInt(range[0])
    stop = start
  else:
    start = parseHexInt(range[0])
    stop = parseHexInt(range[1])
  breakRegons.add BreakRegon(start: start, stop: stop, code: table[code])

proc getBreakCode*(rune: Rune): BreakCode =
  for b in breakRegons:
    if b.start >= int(rune) and b.stop <= int(rune):
      return b.code
  return BreakCode.Unknown
