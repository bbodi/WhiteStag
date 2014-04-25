when defined(windows):
  import windows
else:
  quit "Currently only windows is supported!"
import sdl_ttf
import sdl

import pixel
import drawbuffer
import rect
import color
import font
import event
import utfstring
import renderer
import unicode

var inited: bool

type
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
      var engine = PSdlEngine()

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