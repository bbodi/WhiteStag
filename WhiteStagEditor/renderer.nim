import unicode

import pixel
import drawbuffer
import rect
import color
import font

type
  TColorRegion* = object
    color: color.TColor
    rect: rect.TRegion

  TDrawingRect* = tuple
    color: color.TColor
    rect: rect.TPixelRect

  TDrawingText* = tuple
    text: string
    color: color.TColor
    rect: rect.TPixelRect
    font: TFont
    styles: set[drawbuffer.TTextStyle]

proc getSameColorRegion*(buff: TDrawBuffer, x, y: int): TColorRegion = 
  var rect = rect(0, 0, 0, 1)
  if buff.outOfRange(x, y):
    echo("getSameColorRegion OUT OF RANGE: " & $x & ", " & $y & ", buff: " & repr(buff))
  var region: TColorRegion = TColorRegion(color: buff.cell(x, y).bg, rect: rect)
  let srcW = buff.w
  var srcX = x
  var srcY = y
  while srcY < buff.h:
    let srcCell = buff.cell(srcX, srcY)
    if srcCell.bg != region.color:
      let notSameColorLine = srcX != srcW
      if notSameColorLine:
        let hasMoreRow = region.rect.h != 1
        if hasMoreRow:
          region.rect.h = region.rect.h - 1
          region.rect.w = srcW
      return region
    srcX += 1
    region.rect.w = region.rect.w + 1
    if srcX >= srcW:
      let startPositionWasntAtTheBeginningOfALine = x > 0
      if startPositionWasntAtTheBeginningOfALine:
        return region
      srcX = 0
      region.rect.w = 0
      region.rect.h = region.rect.h + 1
      srcY += 1
  region.rect.h = region.rect.h - 1
  region.rect.w = srcW
  return region

proc collectCharacterBasedRegions(buff: TDrawBuffer): seq[TColorRegion] = 
  var srcX = 0
  var srcY = 0
  var regions: seq[TColorRegion] = @[]
  if buff.w == 0:
    return regions
  while srcY < buff.h:
    var region = getSameColorRegion(buff, srcX, srcY)
    if region.color != ColorNone:
      region.rect = region.rect.moveTo(srcX, srcY)
      regions.add(region)
    srcX += region.rect.w
    srcY += region.rect.h - 1
    if srcX >= buff.w:
      srcX = 0
      srcY += 1
  return regions

proc collectPixelBasedRegions*(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont): seq[TDrawingRect] =
  let regions = collectCharacterBasedRegions(buff)
  let fw = font.charWidth
  let fh = font.charHeight
  doAssert(int(fw) > 0 and int(fh) > 0, "Font character width and height must greater than 0! " & $int(fw) & ", " & $int(fh))
  var drawingRects: seq[TDrawingRect] = @[]
  for region in regions:
    let x = fw * region.rect.x + offsetX
    let y = fh * region.rect.y + offsetY
    let w = fw * region.rect.w
    let h = fh * region.rect.h
    let rect: TDrawingRect = (region.color, (x, y, w, h))
    drawingRects.add(rect)
  return drawingRects

proc getContinousCharacters(buff: TDrawBuffer, offX: var int, offY: int): string =
  let firstCell = buff.cell(offX, offY)
  let fg = firstCell.fg
  let styles = firstCell.styles
  var word: string = ""
  for i in offX..buff.w-1:
    let cell = buff.cell(offX, offY)
    let cellsDifferInColor = cell.fg != fg
    let cellsDiffInStyle = cell.styles != styles
    if cellsDifferInColor or cellsDiffInStyle:
      break
    let ch = if cell.ch == TRune(0): runeAt(" ", 0) else: cell.ch
    
    word = word & $ch
    offX += 1
  return word

proc collectTextRegions*(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont): seq[TDrawingText] =
  var x = 0
  var y = 0
  let fw = font.charWidth
  let fh = font.charHeight
  result = @[]
  if buff.w == 0:
    return
  while y < buff.h: 
    let color = buff.cell(x, y).fg
    let styles = buff.cell(x, y).styles
    let fromX = x
    let word = getContinousCharacters(buff, x, y)
    if word.len > 0:
      let w = x - fromX

      let xpos = offsetX + fw * fromX
      let ypos = offsetY + fh * y
      let textRect = (word, color, (xpos, ypos, fw * w, fh), font, styles)
      result.add(textRect)
      
    if x >= buff.w:
      y += 1
      x = 0

when isMainModule:
  import unittest

  suite "Renderer Test Suite":
    setup:
      var buff = createDrawBuffer(10, 10)

    test "getSameColorRegion for a non-colored region shorter than a line":
      # 0123456789
      # 01##456789
      # 0123456789
      buff.setCells(2, 1, 2, 1, bg = ColorRed)
      let region = getSameColorRegion(buff, 0, 1)
      check region.rect.w == 2
      check region.rect.h == 1
      check region.color == ColorNone

    test "getSameColorRegion for a colored region shorter than a line":
      # 0123456789
      # 01##456789
      # 0123456789
      buff.setCells(2, 1, 2, 1, bg = ColorRed)
      let region = getSameColorRegion(buff, 2, 1)
      check region.rect.w == 2
      check region.rect.h == 1
      check region.color == ColorRed

    test "getSameColorRegion for a colored region to the end of a line":
      # 0123456789
      # 01########
      # 0123456789
      buff.setCells(2, 1, 8, 1, bg = ColorRed)
      let region = getSameColorRegion(buff, 2, 1)
      check region.rect.w == 8
      check region.rect.h == 1
      check region.color == ColorRed

    test "getSameColorRegion for a colored region from the start to the end of a line":
      # 0123456789
      # ##########
      # 0123456789
      buff.setCells(0, 1, 10, 1, bg = ColorRed)
      let region = getSameColorRegion(buff, 0, 1)
      check region.rect.w == 10
      check region.rect.h == 1
      check region.color == ColorRed

    test "getSameColorRegion full line + part line":
      # 0123456789
      # ##########
      # ######6789
      buff.setCells(0, 1, 10, 1, bg = ColorRed)
      buff.setCells(0, 2, 6, 1, bg = ColorRed)
      let region = getSameColorRegion(buff, 0, 1)
      check region.rect.w == 10
      check region.rect.h == 1
      check region.color == ColorRed

    test "getSameColorRegion more full lines":
      # 0123456789
      # ##########
      # ##########
      buff.setCells(0, 1, 10, 1, bg = ColorRed)
      buff.setCells(0, 2, 10, 1, bg = ColorRed)
      let region = getSameColorRegion(buff, 0, 1)
      check region.rect.w == 10
      check region.rect.h == 2
      check region.color == ColorRed

    proc testRegion(region: TColorRegion, expectedColor: color.TColor, expectedX, expectedY, expectedW, expectedH: int) =
      check region.color == expectedColor
      check region.rect.x == expectedX
      check region.rect.y == expectedY
      check region.rect.w == expectedW
      check region.rect.h == expectedH

    test "getSameColorRegion more full lines":
      # 0123456789
      # ##########
      # ##########
      let region = getSameColorRegion(buff, 0, 3)
      check region.rect.w == 10
      check region.rect.h == 7
      check region.color == ColorNone

    test "collectCharacterBasedRegions with 0-sized buffer":
      buff = createDrawBuffer(0, 10)
      let regions = collectCharacterBasedRegions(buff)
      check 0 == regions.len

    test "collectCharacterBasedRegions":
      # 01BBBGGGGG
      # GGGGGGGGGG
      # GGGGGGGGGG
      # 0123456789
      buff.setCells(2, 0, 3, 1, bg = ColorBlue)
      buff.setCells(5, 0, 5, 1, bg = ColorGreen)
      buff.setCells(0, 1, 10, 2, bg = ColorGreen)
      let regions = collectCharacterBasedRegions(buff)
      check 3 == regions.len

      let blueColorRegion = regions[0]
      testRegion(blueColorRegion, ColorBlue, 2, 0, 3, 1)

      let greenColorRegion1 = regions[1]
      testRegion(greenColorRegion1, ColorGreen, 5, 0, 5, 1)

      let greenColorRegion2 = regions[2]
      testRegion(greenColorRegion2, ColorGreen, 0, 1, 10, 2)

    proc testPixelRegion(region: TDrawingRect, expectedColor: color.TColor, expectedX, expectedY, expectedW, expectedH: TPixel) =
      check region.color == expectedColor
      check region.rect.x == expectedX
      check region.rect.y == expectedY
      check region.rect.w == expectedW
      check region.rect.h == expectedH

    test "collectPixelBasedRegions":
      # 01BBBGGGGG
      # GGGGGGGGGG
      # GGGGGGGGGG
      # 0123456789
      buff.setCells(2, 0, 3, 1, bg = ColorBlue)
      buff.setCells(5, 0, 5, 1, bg = ColorGreen)
      buff.setCells(0, 1, 10, 2, bg = ColorGreen)
      let font = TFont(charWidth: TPixel(10), charHeight: TPixel(20))
      let rects = collectPixelBasedRegions(buff, TPixel(100), TPixel(200), font)
      check 3 == rects.len

      let blueColorRegion = rects[0]
      testPixelRegion(blueColorRegion, ColorBlue, TPixel(100+10*2), TPixel(200+20*0), TPixel(3*10), TPixel(1*20))

      let greenColorRegion1 = rects[1]
      testPixelRegion(greenColorRegion1, ColorGreen, TPixel(100+10*5), TPixel(200+20*0), TPixel(5*10), TPixel(1*20))

      let greenColorRegion2 = rects[2]
      testPixelRegion(greenColorRegion2, ColorGreen, TPixel(100+10*0), TPixel(200+20*1), TPixel(10*10), TPixel(2*20))

    test "getContinousCharacters for characters before lineend":
      # Hello56789
      # 0123456789
      buff.writeText(0, 0, "Hello", fg = ColorGreen)
      var offX = 0
      let str = getContinousCharacters(buff, offX, 0)
      check "Hello" == str
      check 5 == offX

    test "getContinousCharacters for empty spaces":
      # 01234Hello
      # Hello56789
      buff.writeText(5, 0, "Hello", fg = ColorGreen)
      buff.writeText(0, 1, "Hello", fg = ColorGreen)
      var offX = 0
      let str = getContinousCharacters(buff, offX, 0)
      check "     " == str
      check 5 == offX

    test "getContinousCharacters for characters to the lineend":
      # 01234Hello
      # Hello56789
      buff.writeText(5, 0, "Hello", fg = ColorGreen)
      buff.writeText(0, 1, "Hello", fg = ColorGreen)
      var offX = 5
      let str = getContinousCharacters(buff, offX, 0)
      check "Hello" == str
      check 10 == offX

    proc testTextRegion(region: TDrawingText, x, y, w, h: int, str: string, c: color.TColor) = 
      check region.text == str
      check region.rect.x == TPixel(x)
      check region.rect.y == TPixel(y)
      check region.rect.w == TPixel(w)
      check region.rect.h == TPixel(h)
      check region.color == c
      let emptySet: set[TTextStyle] = {}
      check region.styles == emptySet

    proc testTextRegionStyle(region: TDrawingText, x, y, w, h: int, str: string, styles: set[drawbuffer.TTextStyle]) = 
      check region.text == str
      check region.rect.x == TPixel(x)
      check region.rect.y == TPixel(y)
      check region.rect.w == TPixel(w)
      check region.rect.h == TPixel(h)
      check region.styles == styles
      check region.color == ColorBlue

    test "collectTextRegions with 0-sized buff":
      buff = createDrawBuffer(0, 10)
      let font = TFont(charWidth: TPixel(10), charHeight: TPixel(20))
      let rects = collectTextRegions(buff, TPixel(0), TPixel(0), font)
      check 0 == rects.len

    test "collectTextRegions":
      # --HelloHel
      # lo---Hello
      buff.writeText(2, 0, "HelloHel", fg = ColorBlue)
      buff.writeText(0, 1, "lo", fg = ColorRed)
      buff.writeText(5, 1, "Hello", fg = ColorGreen)
      let font = TFont(charWidth: TPixel(10), charHeight: TPixel(20))
      let rects = collectTextRegions(buff, TPixel(0), TPixel(0), font)
      check 13 == rects.len

      testTextRegion(rects[0], 0, 0, 2*10, 20, "  ", ColorNone)
      testTextRegion(rects[1], 2*10, 0, 8*10, 20, "HelloHel", ColorBlue)
      testTextRegion(rects[2], 0, 1*20, 2*10, 20, "lo", ColorRed)
      testTextRegion(rects[3], 2*10, 1*20, 3*10, 20, "   ", ColorNone)  
      testTextRegion(rects[4], 5*10, 1*20, 5*10, 20, "Hello", ColorGreen)

      for i in 0..7:
        testTextRegion(rects[5+i], 0, (2+i)*20, 10*10, 20, "          ", ColorNone)

    test "collectTextRegions with differentStyles":
      # --BBBBBBBB
      # II---QQQQQ
      buff.writeText(2, 0, "BBBBBBBB", fg = ColorBlue, styles = {drawbuffer.styleBold})
      buff.writeText(0, 1, "II", fg = ColorBlue, styles = {drawbuffer.styleItalic})
      buff.writeText(5, 1, "QQQQQ", fg = ColorBlue, styles = {drawbuffer.styleBold, drawbuffer.styleItalic})
      let font = TFont(charWidth: TPixel(10), charHeight: TPixel(20))
      let rects = collectTextRegions(buff, TPixel(0), TPixel(0), font)
      check 13 == rects.len

      testTextRegion(rects[0], 0, 0, 2*10, 20, "  ", ColorNone)
      testTextRegionStyle(rects[1], 2*10, 0, 8*10, 20, "BBBBBBBB", {drawbuffer.styleBold})
      testTextRegionStyle(rects[2], 0, 1*20, 2*10, 20, "II", {drawbuffer.styleItalic})
      testTextRegion(rects[3], 2*10, 1*20, 3*10, 20, "   ", ColorNone)  
      testTextRegionStyle(rects[4], 5*10, 1*20, 5*10, 20, "QQQQQ", {drawbuffer.styleBold, drawbuffer.styleItalic})

      for i in 0..7:
        testTextRegion(rects[5+i], 0, (2+i)*20, 10*10, 20, "          ", ColorNone)