import unicode
when defined(windows):
  import windows
when defined(Posix):
  import posix
import sdl_ttf
import sdl

import pixel
import drawbuffer
import rect
import color
import font
import event
import utfstring

var inited: bool

type
  TColorRegion = object
    color: color.TColor
    rect: rect.TRegion

  TDrawingRect = tuple
    color: color.TColor
    rect: rect.TPixelRect

  TDrawingText = tuple
    text: string
    color: color.TColor
    rect: rect.TPixelRect
    font: TFont
    styles: set[drawbuffer.TTextStyle]

  PSdlEngine* = ref TSdlEngine
  TSdlEngine* = object
    screen: PSurface
    w, h: int
    sdlEvent: sdl.TEvent
    nextTickTime: uint32
    lastMouseButtonDownEvent: event.TEvent
    lastMouseButtonDownTimeStamp: int32
    font12*: TFont
    font14*: TFont
    font16*: TFont
    font18*: TFont
    font20*: TFont
    font22*: TFont

proc isInitialized*(self: PSdlEngine): bool = return inited

proc clear*(self: PSdlEngine) = 
  discard sdl.fillRect(self.screen, nil, 0x000000)

proc loadSdlFont(fileName: string, size: cint): sdl_ttf.PFont  =
  let font = OpenFont(fileName, cint(size))
  doAssert(font != nil, "Cannot open font: " & fileName & ", size: " & $int(size))
  return font

proc loadFont*(self: PSdlEngine, size: int, name: string = "DejaVuSansMono"): TFont = 
  var font: TFont
  font.normalSdlFont = loadSdlFont(name & ".ttf", cint(size))

  font.boldSdlFont = loadSdlFont(name & "-Bold.ttf", cint(size))
  font.italicSdlFont = loadSdlFont(name & "-Oblique.ttf", cint(size))
  font.boldItalicSdlFont = loadSdlFont(name & "-BoldOblique.ttf", cint(size))

  var charW, charH: cint
  discard font.normalSdlFont.SizeText("A", charW, charH)
  font.charWidth = TPixel(charW)
  font.charHeight = TPixel(charH)
  font.size = size
  return font


proc init*(w, h: int, fontSize: int): PSdlEngine = 
  doAssert(inited == false)
  var engine = new(TSdlEngine)
  engine.w = w
  engine.h = h

  doAssert (sdl.init(sdl.INIT_EVERYTHING) == 0, "sdl init")
  doAssert (sdl_ttf.init() == 0, "sdl_ttf")
  discard sdl.enableUnicode(1)
  discard sdl.enableKeyRepeat(sdl.DEFAULT_REPEAT_DELAY, sdl.DEFAULT_REPEAT_INTERVAL)

  let font = engine.loadFont(fontSize)
  let screenW = font.charWidth * w
  let screenH = font.charHeight * h

  engine.screen = SetVideoMode(int(screenW), int(screenH), 0, sdl.RESIZABLE);

  engine.font12 = engine.loadFont(12)
  engine.font14 = engine.loadFont(14)
  engine.font16 = engine.loadFont(16)
  engine.font18 = engine.loadFont(18)
  engine.font20 = engine.loadFont(20)
  engine.font22 = engine.loadFont(22)

  inited = true
  return engine


proc getSameColorRegion(buff: TDrawBuffer, x, y: int): TColorRegion = 
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

proc swapBackBuffer*(self: PSdlEngine) =
  discard self.screen.flip()

proc createSdlColor(sur: PSurface, c: color.TColor, alpha: int = 0): int32 =
  let x = c
  return sdl.MapRGBA(sur.format, int(x.r) and 0xff, int(x.g) and 0xff, 
                     int(x.b) and 0xff, alpha and 0xff)

proc drawRect(self: PSdlEngine, rect: TDrawingRect) =
  var sdlRect = sdl.TRect(x: int16(rect.rect.x), y: int16(rect.rect.y), w: uint16(rect.rect.w), h: uint16(rect.rect.h))
  discard sdl.fillRect(self.screen, addr sdlRect, self.screen.createSdlColor(rect.color))

proc drawRects(self: PSdlEngine, rects: openarray[TDrawingRect]) =
  for rect in rects:
    self.drawRect(rect)
  

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

proc collectPixelBasedRegions(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont): seq[TDrawingRect] =
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

proc toSdlColor*(c: color.TColor): sdl.TColor =
  result.r = c.r
  result.g = c.g
  result.b = c.b

proc drawString(self: PSdlEngine, textRegion: TDrawingText) =
  var sdlFont: sdl_ttf.PFont
  if drawbuffer.styleBold in textRegion.styles and drawbuffer.styleItalic in textRegion.styles:
    sdlFont = textRegion.font.boldItalicSdlFont
  elif drawbuffer.styleBold in textRegion.styles:
    sdlFont = textRegion.font.boldSdlFont
  elif drawbuffer.styleItalic in textRegion.styles:
    sdlFont = textRegion.font.italicSdlFont
  else:
    sdlFont = textRegion.font.normalSdlFont

  let textSurf = (sdl_ttf.RenderUTF8_Solid(sdlFont, textRegion.text, toSdlColor(textRegion.color)))
  var dstRect = sdl.TRect(x: int16(textRegion.rect.x), y: int16(textRegion.rect.y), w: uint16(textRegion.rect.w), h: uint16(textRegion.rect.h))
  discard sdl.blitSurface(textSurf, nil, self.screen, addr(dstRect))
  freeSurface(textSurf)

proc collectTextRegions(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont): seq[TDrawingText] =
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

proc drawTexts(self: PSdlEngine, texts: seq[TDrawingText]) =
  for textRect in texts:
    self.drawString(textRect)

proc drawToBackBuffer*(self: PSdlEngine, buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont, clippingArea: TPixelRect) = 
  let backgroundRects = collectPixelBasedRegions(buff, offsetX, offsetY, font)

  var sdlClippingRect = sdl.TRect(x: int16(clippingArea.x), y: int16(clippingArea.y), w: uint16(clippingArea.w), h: uint16(clippingArea.h))
  sdl.setClipRect(self.screen, addr sdlClippingRect)

  self.drawRects(backgroundRects)
  let textRects = collectTextRegions(buff, offsetX, offsetY, font)
  self.drawTexts(textRects)

  sdl.setClipRect(self.screen, nil)

proc convertModificationButtons(event: sdl.PKeyboardEvent): TKeyModifier =
  let modifier = int(event.keysym.modifier)
  return TKeyModifier(
    leftAlt:     (modifier and int(KMOD_LALT)) != 0,
    rightAlt:     (modifier and int(KMOD_RALT)) != 0,
    alt:      (modifier and int(KMOD_ALT)) != 0,
    leftCtrl:    (modifier and int(KMOD_LCTRL)) != 0,
    rightCtrl:    (modifier and int(KMOD_RCTRL)) != 0,
    ctrl:     (modifier and int(KMOD_CTRL)) != 0,
    leftShift:   (modifier and int(KMOD_LSHIFT)) != 0,
    rightShift:   (modifier and int(KMOD_RSHIFT)) != 0,
    shift:    (modifier and int(KMOD_SHIFT)) != 0,
    capsLock: (modifier and int(KMOD_CAPS)) != 0,
    numLock:  (modifier and int(KMOD_NUM)) != 0,
  )

proc convertKey(ev: PKeyboardEvent): event.TKey =
  case ev.keysym.sym:
  of sdl.K_F1:
    return event.TKey.KeyF1
  of sdl.K_F2:
    return event.TKey.KeyF2
  of sdl.K_F3:
    return event.TKey.KeyF3
  of sdl.K_F4:
    return event.TKey.KeyF4
  of sdl.K_F5:
    return event.TKey.KeyF5
  of sdl.K_F6:
    return event.TKey.KeyF6
  of sdl.K_F7:
    return event.TKey.KeyF7
  of sdl.K_F8:
    return event.TKey.KeyF8
  of sdl.K_F9:
    return event.TKey.KeyF9
  of sdl.K_F10:
    return event.TKey.KeyF10
  of sdl.K_F11:
    return event.TKey.KeyF11
  of sdl.K_F12:
    return event.TKey.KeyF12
  of sdl.K_INSERT:
    return event.TKey.KeyInsert
  of sdl.K_DELETE:
    return event.TKey.KeyDelete
  of sdl.K_HOME:
    return event.TKey.KeyHome
  of sdl.K_END:
    return event.TKey.KeyEnd
  of sdl.K_PAGEUP:
    return event.TKey.KeyPgup
  of sdl.K_PAGEDOWN:
    return event.TKey.KeyPgdn
  of sdl.K_UP:
    return event.TKey.KeyArrowUp
  of sdl.K_DOWN:
    return event.TKey.KeyArrowDown
  of sdl.K_LEFT:
    return event.TKey.KeyArrowLeft
  of sdl.K_RIGHT:
    return event.TKey.KeyArrowRight
  of sdl.K_TAB:
    return event.TKey.KeyTab
  of sdl.K_RETURN:
    return event.TKey.KeyEnter
  of sdl.K_BACKSPACE:
    return event.TKey.KeyBackspace
  of sdl.K_SPACE:
    return event.TKey.KeySpace
  of sdl.K_ESCAPE:
    return event.TKey.KeyEsc

  of sdl.K_NUMLOCK:
    return event.TKey.KeyModifier
  of sdl.K_CAPSLOCK:
    return event.TKey.KeyModifier
  of sdl.K_SCROLLOCK:
    return event.TKey.KeyModifier
  of sdl.K_RSHIFT, sdl.K_LSHIFT:
    return event.TKey.KeyShift
  of sdl.K_RCTRL, sdl.K_LCTRL:
    return event.TKey.KeyCtrl
  of sdl.K_RALT, sdl.K_LALT:
    return event.TKey.KeyAlt
  else:
    return event.TKey.KeyNormal

proc readMouseButton(ev: PMouseButtonEvent): TMouseButton =
  if int(ev.button) == sdl.BUTTON_LEFT:
    return TMouseButton.mbtnLeft
  elif int(ev.button) == sdl.BUTTON_MIDDLE:
    return TMouseButton.mbtnMiddle
  else:
    return TMouseButton.mbtnRight


proc processSdlEvent(self: PSdlEngine, sdlEvent: sdl.PEvent): event.PEvent =
  case sdlEvent.kind:
  of sdl.KEYUP:
    let t = EvKeyboard(sdlEvent)
    result = event.PEvent(kind: eventKeyUp)
    result.key = convertKey(t)

  of sdl.KEYDOWN:
    let t = EvKeyboard(sdlEvent)
    result = event.PEvent(kind: eventKey)
    
    result.key = convertKey(t)
    if result.key == event.TKey.KeyNormal:
      result.unicode = TRune(t.keysym.unicode)
      if t.keysym.sym <= 255:
        result.ch = char(t.keysym.sym)
      else:
        result.ch = '?'
    result.keyModifier = convertModificationButtons(t)
  of sdl.MOUSEBUTTONDOWN:
    let t = EvMouseButton(sdlEvent)
    result = event.PEvent(kind: eventMouseButtonDown)
    result.mouseX = TPixel(t.x)
    result.mouseY = TPixel(t.y)
    result.mouseButton = readMouseButton(t)
    let now = sdl.getTicks()
    if int(now - self.lastMouseButtonDownTimeStamp) < 500 and self.lastMouseButtonDownEvent.kind == eventMouseButtonDown:
      let sameX = self.lastMouseButtonDownEvent.mouseX == result.mouseX
      let sameY = self.lastMouseButtonDownEvent.mouseY == result.mouseY
      result.doubleClick = sameX and sameY
    self.lastMouseButtonDownTimeStamp = now
    self.lastMouseButtonDownEvent = result[]
  of sdl.MOUSEBUTTONUP:
    let t = EvMouseButton(sdlEvent)
    result = event.PEvent(kind: eventMouseButtonUp)
    result.mouseX = TPixel(t.x)
    result.mouseY = TPixel(t.y)
  of sdl.MOUSEMOTION:
    let t = EvMouseMotion(sdlEvent)
    result = event.PEvent(kind: eventMouseMove)
    result.mouseX = TPixel(t.x)
    result.mouseY = TPixel(t.y)
  of sdl.USEREVENT:
    result = event.PEvent(kind: eventTick)
  of sdl.QUITEV:
    result = event.PEvent(kind: eventCommand)
    result.cmd = CmdQuit
  of sdl.VIDEORESIZE:
    let t = EvResize(sdlEvent)
    self.w = t.w
    self.h = t.h
    self.screen = SetVideoMode(self.w, self.h, 0, sdl.RESIZABLE);
    result = event.PEvent(kind: eventWindowResized, newWidth: TPixel(t.w), newHeight: TPixel(t.h))

  else:
    return nil

proc readSdlEvent(self: PSdlEngine): sdl.PEvent =
  var ok = false
  reset(self.sdlEvent)
  var pEvent = addr self.sdlEvent
  while ok == false:
    ok = sdl.PollEvent(pEvent) == 1
    if ok:
      break 
    else:
      let now = sdl.getTicks()
      if int(self.nextTickTime) < int(now):
        reset(pEvent[])
        pEvent.kind = sdl.USEREVENT
        self.nextTickTime = uint32(int(now) + 300)
        break
    sdl.Delay(10)
  return addr self.sdlEvent

proc pollEvent*(self: PSdlEngine): event.PEvent =
  while true:
    let sdlEvent = self.readSdlEvent()
    let event = self.processSdlEvent(sdlEvent)
    if event != nil:
      return event

proc readClipBoard*(self: PSdlEngine): PUTFString = 
  result = utf""
  if OpenClipboard(0) != 0:
    let clip = GetClipboardData(CF_UNICODETEXT)
    var clipPtr = cast[TAddress](clip)
    while true:
      let rune = TRune(cast[PWideChar](clipPtr)[])
      if rune == TRune(0):
        break
      result.append(rune)
      clipPtr = clipPtr + sizeof(int16)
  discard CloseClipboard()

when isMainModule:
  import unittest

  suite "SDLEngine Test Suite":
    setup:
      var buff = createDrawBuffer(10, 10)
      var engine = PSdlEngine()

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

    test "event processing: double click":
      var mouseButtonEvent = TMouseButtonEvent()
      mouseButtonEvent.x = 1
      mouseButtonEvent.y = 1
      mouseButtonEvent.kind = MOUSEBUTTONDOWN
      mouseButtonEvent.button = sdl.BUTTON_LEFT
      let result = engine.processSdlEvent(cast[ptr sdl.TEvent](addr mouseButtonEvent))
      check result.kind == eventMouseButtonDown

      let result2 = engine.processSdlEvent(cast[ptr sdl.TEvent](addr mouseButtonEvent))
      check result.kind == eventMouseButtonDown
      check result2.doubleClick