
type
  TColor* = tuple
    r, g, b: uint8
    visible: bool

  TColorPair* = tuple
    first, second: TColor

  TColorTriplet* = tuple
    first, second, third: TColor

proc `==`*(a, b: TColor): bool =
  result = int(a.r) == int(b.r) and 
          int(a.g) == int(b.g) and 
          int(a.b) == int(b.b) and 
          a.visible == b.visible

proc createColor(col: int): TColor =
  result.r = (col shr 16) and 0xFF
  result.g = (col shr 8) and 0xFF
  result.b = (col) and 0xFF
  result.visible = true


const
  ColorNone*:TColor    = (r: 0'u8, g: 0'u8, b: 0'u8, visible: false)
  ColorBlack*:TColor   = (r: 0'u8, g: 0'u8, b: 0'u8, visible: true)
  ColorRed*:TColor     = (r: 255'u8, g: 0'u8, b: 0'u8, visible: true)
  ColorDarkGreen*:TColor   = (r: 50'u8, g: 200'u8, b: 50'u8, visible: true)
  ColorGreen*:TColor   = (r: 0'u8, g: 255'u8, b: 0'u8, visible: true)
  ColorYellow*:TColor  = (r: 255'u8, g: 255'u8, b: 0'u8, visible: true)
  ColorDarkYellow*:TColor  = (r: 200'u8, g: 200'u8, b: 50'u8, visible: true)
  ColorBlue*:TColor    = (r: 0'u8, g: 0'u8, b: 255'u8, visible: true)
  ColorMagenta*:TColor = (r: 255'u8, g: 0'u8, b: 255'u8, visible: true)
  ColorCyan*:TColor    = (r: 0'u8, g: 255'u8, b: 255'u8, visible: true)
  ColorWhite*:TColor   = (r: 255'u8, g: 255'u8, b: 255'u8, visible: true)
  ColorGray*:TColor    = (r: 100'u8, g: 100'u8, b: 100'u8, visible: true)
  ColorLightGray*:TColor    = (r: 230'u8, g: 230'u8, b: 230'u8, visible: true)
  ColorDarkGray*:TColor    = (r: 40'u8, g: 40'u8, b: 40'u8, visible: true)

  ColorPurple*:TColor  = (r: 76'u8, g: 0'u8, b: 153'u8, visible: true)

  

proc color*(self: TColorPair, second: bool): TColor = 
  if second: self.second else: self.first

proc color*(self: TColorTriplet, second: bool, third: bool = false): TColor = 
  if second: self.second elif third: self.third else: self.first
