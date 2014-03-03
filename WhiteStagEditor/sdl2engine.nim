import unicode

import sdl2/sdl2/sdl2
import sdl
import sdl_ttf

import pixel
import drawbuffer
import rect
import color
import font
import event

var inited: bool

type
  TColorRegion = tuple
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

  PSdlEngine* = ref TSdlEngine
  TSdlEngine* = object
    renderer: PRenderer
    window: PWindow
    w, h: int
    screenSurface: sdl2.PSurface
    pixelFormat: sdl2.PPixelFormat
    sdlEvent: sdl2.TEvent
    nextTickTime: uint32
    font12*: TFont
    font14*: TFont
    font16*: TFont
    font18*: TFont
    font20*: TFont
    font22*: TFont

proc isInitialized*(self: PSdlEngine): bool = return inited

proc clear*(self: PSdlEngine) = 
  discard self.renderer.setRenderDrawColor(0, 0, 0, 255'u8)
  discard self.renderer.renderClear()

proc loadFont*(self: PSdlEngine, size: int, name: string = "DejaVuSansMono.ttf"): TFont = 
  var font: TFont
  font.sdlFont = OpenFont(name, cint(size))
  doAssert(font.sdlFont != nil, "Cannot open font: " & name & ", size: " & $int(size))
  var charW, charH: cint
  discard font.sdlFont.SizeText("A", charW, charH)
  font.charWidth = TPixel(charW)
  font.charHeight = TPixel(charH)
  font.size = size
  return font

const cmdTickId = 1


proc init*(w, h: int, fontSize: int): PSdlEngine = 
  doAssert(inited == false)
  var engine = new(TSdlEngine)
  engine.w = w
  engine.h = h

  doAssert (sdl_ttf.init() == 0, "sdl_ttf")
  let font = engine.loadFont(fontSize)
  let screenW = font.charWidth * w
  let screenH = font.charHeight * h

  doAssert(sdl2.init(SDL_INIT_EVERYTHING) != -1, "SDL initialization failed")
  engine.window = createWindow("Hello World!", 100, 100, int(screenW), int(screenH), WINDOW_SHOWN)
  engine.renderer = engine.window.createRenderer(-1, int(RENDERER_ACCELERATED) or int(RENDERER_PRESENTVSYNC))
  engine.pixelFormat = allocFormat(PIXELFORMAT_RGBA8888)

  engine.screenSurface = createRGBSurface(0'u32,
                int(screenW), int(screenH),
                32,
                engine.pixelFormat.Rmask,
                engine.pixelFormat.Gmask,
                engine.pixelFormat.Bmask,
                engine.pixelFormat.Amask)

  #initTickTimer()

  engine.font12 = engine.loadFont(12)
  engine.font14 = engine.loadFont(14)
  engine.font16 = engine.loadFont(16)
  engine.font18 = engine.loadFont(18)
  engine.font20 = engine.loadFont(20)
  engine.font22 = engine.loadFont(22)

  inited = true
  return engine


proc getSameColorRegion(buff: TDrawBuffer, x, y: int): TColorRegion = 
  var region: TColorRegion = (buff.cell(x, y).bg, (x: 0, y: 0, w: 0, h: 1))
  let srcW = buff.w
  var srcX = x
  var srcY = y
  while srcY < buff.h:
    let srcCell = buff.cell(srcX, srcY)
    if srcCell.bg != region.color:
      let notSameColorLine = srcX != srcW
      if notSameColorLine:
        let hasMoreRow = region.h != 1
        if hasMoreRow:
          region.h -= 1
          region.w = srcW
      return region
    srcX += 1
    region.w += 1
    if srcX >= srcW:
      let startPositionWasntAtTheBeginningOfALine = x > 0
      if startPositionWasntAtTheBeginningOfALine:
        return region
      srcX = 0
      region.w = 0
      region.h += 1
      srcY += 1
  region.h -= 1
  region.w = srcW
  return region

proc swapBackBuffer*(self: PSdlEngine) =
  self.renderer.renderPresent()

proc drawRect(self: PSdlEngine, rect: TDrawingRect) =
  discard self.renderer.setRenderDrawColor(rect.color.r, rect.color.g, rect.color.b, 255'u8)

  var sdlRect = sdl2.TRect(x: int(rect.rect.x), y: int(rect.rect.y), w: int(rect.rect.w), h: int(rect.rect.h))
  discard self.renderer.renderFillRect(addr(sdlRect))

proc drawRects(self: PSdlEngine, rects: openarray[TDrawingRect]) =
  for rect in rects:
    self.drawRect(rect)
  

proc collectCharacterBasedRegions(buff: TDrawBuffer): seq[TColorRegion] = 
  var srcX = 0
  var srcY = 0
  
  var regions: seq[TColorRegion] = @[]
  while srcY < buff.h:
    var region = getSameColorRegion(buff, srcX, srcY)
    if region.color != ColorNone:
      region..x = srcX
      region.y = srcY
      regions.add(region)
    srcX += region.w
    srcY += region.h - 1
    if srcX >= buff.w:
      srcX = 0
      srcY += 1
  return regions

proc collectPixelBasedRegions(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont): seq[TDrawingRect] =
  let regions = collectCharacterBasedRegions(buff)
  let fw = font.charWidth
  let fh = font.charHeight
  doAssert(int(fw) > 0 and int(fh) > 0, "Font character width and height must greater than 0!")
  var drawingRects: seq[TDrawingRect] = @[]
  for region in regions:
    let x = fw * region..x + offsetX
    let y = fh * region.y + offsetY
    let w = fw * region.w
    let h = fh * region.h
    let rect: TDrawingRect = (region.color, (x, y, w, h))
    drawingRects.add(rect)
  return drawingRects

proc getContinousCharacters(buff: TDrawBuffer, offX: var int, offY: int): string =
  let firstCell = buff.cell(offX, offY)
  let fg = firstCell.fg
  var word: string = ""
  for i in offX..buff.w-1:
    let cell = buff.cell(offX, offY)
    if cell.fg != fg:
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
  let sdlFont = textRegion.font.sdlFont
  let textSurf = cast[sdl2.sdl2.PSurface](sdlFont.RenderUTF8_Solid(textRegion.text, toSdlColor(textRegion.color)))
  let textTexture = self.renderer.CreateTextureFromSurface(textSurf)
  var dstRect = sdl2.T.x: int(textRegion..x), y: int(textRegion.y), w: int(textRegion.w), h: int(textRegion.h))
  discard self.renderer.renderCopy(textTexture, nil, addr dstRect)
  freeSurface(textSurf)

proc collectTextRegions(buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont): seq[TDrawingText] =
  var x = 0
  var y = 0
  let fw = font.charWidth
  let fh = font.charHeight
  result = @[]
  while y < buff.h: 
    let color = buff.cell(x, y).fg
    let fromX = x
    let word = getContinousCharacters(buff, x, y)
    if word.len > 0:
      let w = x - fromX

      let xpos = offsetX + fw * fromX
      let ypos = offsetY + fh * y
      let textRect = (word, color, (xpos, ypos, fw * w, fh), font)
      result.add(textRect)
      
    if x >= buff.w:
      y += 1
      x = 0

proc drawTexts(self: PSdlEngine, texts: seq[TDrawingText]) =
  for textRect in texts:
    self.drawString(textRect)

proc drawToBackBuffer*(self: PSdlEngine, buff: TDrawBuffer, offsetX, offsetY: TPixel, font: TFont, clippingArea: TPixelRect) = 
  let backgroundRects = collectPixelBasedRegions(buff, offsetX, offsetY, font)

  var sdlClippingRect = sdl2.T.x: int(clippingArea.x), y: int(clippingArea.y), w: int(clippingArea.w), h: int(clippingArea.h))
  discard self.renderer.renderSetClipRect(addr sdlClippingRect)

  self.drawRects(backgroundRects)
  let textRects = collectTextRegions(buff, offsetX, offsetY, font)
  self.drawTexts(textRects)

  discard self.renderer.renderSetClipRect(nil)

proc convertModificationButtons(event: sdl2.PKeyboardEvent): TKeyModifier =
  let modifier = int(event.keysym.modifier)
  return TKeyModifier(
    leftAlt:     (modifier and int(TKeymod.KMOD_LALT)) != 0,
    rightAlt:     (modifier and int(TKeymod.KMOD_RALT)) != 0,
    alt:      (modifier and int(TKeymod.KMOD_ALT)) != 0,
    leftCtrl:    (modifier and int(TKeymod.KMOD_LCTRL)) != 0,
    rightCtrl:    (modifier and int(TKeymod.KMOD_RCTRL)) != 0,
    ctrl:     (modifier and int(TKeymod.KMOD_CTRL)) != 0,
    leftShift:   (modifier and int(TKeymod.KMOD_LSHIFT)) != 0,
    rightShift:   (modifier and int(TKeymod.KMOD_RSHIFT)) != 0,
    shift:    (modifier and int(TKeymod.KMOD_SHIFT)) != 0,
    capsLock: (modifier and int(TKeymod.KMOD_CAPS)) != 0,
    numLock:  (modifier and int(TKeymod.KMOD_NUM)) != 0,
  )

proc convertKey(ev: sdl2.PKeyboardEvent): event.TKey =
  case ev.keysym.sym:
  of sdl2.K_F1:
    return event.TKey.KeyF1
  of sdl2.K_F2:
    return event.TKey.KeyF2
  of sdl2.K_F3:
    return event.TKey.KeyF3
  of sdl2.K_F4:
    return event.TKey.KeyF4
  of sdl2.K_F5:
    return event.TKey.KeyF5
  of sdl2.K_F6:
    return event.TKey.KeyF6
  of sdl2.K_F7:
    return event.TKey.KeyF7
  of sdl2.K_F8:
    return event.TKey.KeyF8
  of sdl2.K_F9:
    return event.TKey.KeyF9
  of sdl2.K_F10:
    return event.TKey.KeyF10
  of sdl2.K_F11:
    return event.TKey.KeyF11
  of sdl2.K_F12:
    return event.TKey.KeyF12
  of sdl2.K_INSERT:
    return event.TKey.KeyInsert
  of TKeyCode(sdl2.K_DELETE):
    return event.TKey.KeyDelete
  of sdl2.K_HOME:
    return event.TKey.KeyHome
  of sdl2.K_END:
    return event.TKey.KeyEnd
  of sdl2.K_PAGEUP:
    return event.TKey.KeyPgup
  of sdl2.K_PAGEDOWN:
    return event.TKey.KeyPgdn
  of sdl2.K_UP:
    return event.TKey.KeyArrowUp
  of sdl2.K_DOWN:
    return event.TKey.KeyArrowDown
  of sdl2.K_LEFT:
    return event.TKey.KeyArrowLeft
  of sdl2.K_RIGHT:
    return event.TKey.KeyArrowRight
  of sdl2.K_TAB:
    return event.TKey.KeyTab
  of sdl2.K_RETURN:
    return event.TKey.KeyEnter
  of sdl2.K_BACKSPACE:
    return event.TKey.KeyBackspace
  of TKeyCode(sdl2.K_SPACE):
    return event.TKey.KeySpace
  of sdl2.K_ESCAPE:
    return event.TKey.KeyEsc
  else:
    return event.TKey.KeyNormal

proc processSdlEvent(self: PSdlEngine, sdlEvent: sdl2.PEvent): event.PEvent =
  case sdlEvent.kind:
  of sdl2.TEXTINPUT:
    let t = EvTextInput(sdlEvent)
    let ch = runeAt($t.text, 0)
    result = event.PEvent(kind: eventKey)
    result.ch = ch
    echo("TEXTINPUT")
  of sdl2.KEYDOWN:
    let t = EvKeyboard(sdlEvent)
    result = if int(t.repeat) == 1:
        event.PEvent(kind: eventKeyRepeat)
      else:
        event.PEvent(kind: eventKey)
    
    result.key = convertKey(t)
    if result.key == event.TKey.KeyNormal:
      return nil
    
    result.keyModifier = convertModificationButtons(t)

    echo("KEYDOWN")
  of sdl2.MOUSEBUTTONDOWN:
    let t = EvMouseButton(sdlEvent)
    result = event.PEvent(kind: eventMouseButtonDown)
    result.mouseX = TPixel(t.x)
    result.mouseY = TPixel(t.y)
  of sdl2.MOUSEBUTTONUP:
    let t = EvMouseButton(sdlEvent)
    result = event.PEvent(kind: eventMouseButtonUp)
    result.mouseX = TPixel(t.x)
    result.mouseY = TPixel(t.y)
  of sdl2.MOUSEMOTION:
    let t = EvMouseMotion(sdlEvent)
    result = event.PEvent(kind: eventMouseMove)
    result.mouseX = TPixel(t.x)
    result.mouseY = TPixel(t.y)
  of sdl2.USEREVENT:
    return nil
    #let t = EvUser(sdlEvent)
    #result = event.PEvent(kind: eventTick)
    #result.cmd = cmdTick
    #result.cmd = cast[TCmd](t.data1)

  of sdl2.QUITEVENT:
    result = event.PEvent(kind: eventCommand)
    result.cmd = CmdQuit

  else:
    return nil

proc readSdlEvent(self: PSdlEngine): sdl2.PEvent =
  var ok = false
  reset(self.sdlEvent)
  var pEvent = addr self.sdlEvent
  while ok == false:
    ok = sdl2.PollEvent(pEvent) == 1
    if ok:
      break 
    else:
      let now = sdl2.getTicks()
      if int(self.nextTickTime) < int(now):
        reset(pEvent[])
        pEvent.kind = sdl2.USEREVENT
        self.nextTickTime = uint32(int(now) + 1000)
        break
    sdl2.Delay(10)
  return addr self.sdlEvent

proc pollEvent*(self: PSdlEngine): event.PEvent =
  while true:
    let sdlEvent = self.readSdlEvent()
    let event = self.processSdlEvent(sdlEvent)
    if event != nil:
      return event      