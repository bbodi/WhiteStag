import view
import frame
import font
import color
import drawbuffer
import event
import option
import sdlengine
import selectbox
import rect
import pixel

type
  PWindow* = ref TWindow
  TWindow* = object of TView
    frame*: TWindowFrame
    closeable*: bool
    resizable*: bool
    dragging: bool
    resizing: bool
    lastMousePosX, lastMousePosY :int

var fontSelectBox = createStringSelectBox("Fonts", false)
discard fontSelectBox.addItem("12", cmdOk)
discard fontSelectBox.addItem("14", cmdOk)
discard fontSelectBox.addItem("16", cmdOk)
discard fontSelectBox.addItem("18", cmdOk)
discard fontSelectBox.addItem("20", cmdOk)
discard fontSelectBox.addItem("22", cmdOk)

method name*(self: PWindow): string = 
  "Window(" & self.frame.title & ")"

proc clickedInFontChooser(self: PWindow, event: PEvent): bool =
  let yOk = event.localMouseY == 0
  let mx = event.localMouseX
  let xOk = (mx >= self.w-9) and (mx < self.w-7)
  return yOk and xOk

proc clickedInResizerCorner(self: PWindow, event: PEvent): bool =
  let yOk = event.localMouseY == self.h - 1
  let xOk = event.localMouseX == self.w - 1
  return yOk and xOk

proc resize(self: PWindow, deltaX, deltaY: int) =
  self.grow(deltaX, deltaY)

proc windowHandleEvent*(self: PWindow, event: PEvent) = 
  case event.kind:
  of TEventKind.eventKey:
    case event.key:
    of TKey.KeyArrowDown, TKey.KeyArrowRight, TKey.KeyTab:
      self.selectNext()
      event.setProcessed()
    of TKey.KeyArrowUp, TKey.KeyArrowLeft:
      self.selectNext(backward = true)
      event.setProcessed()
    else:
      discard
  of TEventKind.eventMouseButtonDown:
    if event.local and self.clickedInFontChooser(event) and self.resizable:
      let fontSize = cast[string](self.executeView(fontSelectBox, self.w-9, 1).data)
      var font: TFont
      case fontSize:
      of "12": font = engine.font12
      of "14": font = engine.font14
      of "16": font = engine.font16
      of "18": font = engine.font18
      of "20": font = engine.font20
      of "22": font = engine.font22
      else: 
        event.setProcessed()
        return
      self.font = some[TFont](font)
      self.modified()
    elif event.local and event.localMouseY == 0:
      self.dragging = true
      self.lastMousePosX = event.mouseX div self.font.charWidth
      self.lastMousePosY = event.mouseY div self.font.charHeight
    elif self.clickedInResizerCorner(event) and self.resizable:
      self.resizing = true
      self.lastMousePosX = event.mouseX div self.font.charWidth
      self.lastMousePosY = event.mouseY div self.font.charHeight
    if event.local:
      event.setProcessed()
  of TEventKind.eventMouseButtonUp:
    if self.dragging:
      self.dragging = false
    elif self.resizing:
      self.resizing = false
  of TEventKind.eventMouseMove:
    if self.dragging or self.resizing:
      let newPosX = event.mouseX div self.font.charWidth
      let newPosY = event.mouseY div self.font.charHeight
      let localDeltaX = newPosX - self.lastMousePosX
      let localDeltaY = newPosY - self.lastMousePosY
      self.lastMousePosX = newPosX
      self.lastMousePosY = newPosY
      if self.dragging:
        self.move(localDeltaX, localDeltaY)
      elif self.resizing:
        self.grow(localDeltaX, localDeltaY)
      self.modified()
  else:
    discard

method handleEvent*(self: PWindow, event: PEvent) = 
  windowHandleEvent(self, event)

proc drawWindow*(self: PWindow): TDrawBuffer =
  self.frame.draw(self, self.buff)
  if self.closeable:
    self.buff.setCell(self.w - 5, 0, fg = BorderColor.color(self.isFocused), ch = "[")
    self.buff.setCell(self.w - 4, 0, fg = BorderActionColor.color(self.closeable), ch = "x")
    self.buff.setCell(self.w - 3, 0, fg = BorderColor.color(self.isFocused), ch = "]")

  let fontSizeStr = $int(self.font.size)
  let lenStr = fontSizeStr.len
  self.buff.setCell(self.w-10, 0, fg = BorderColor.color(self.isFocused), ch = "[")
  self.buff.writeText(self.w-9, 0, fontSizeStr, fg = BorderActionColor.color(self.resizable))
  self.buff.setCell(self.w-9+lenStr, 0, fg = BorderColor.color(self.isFocused), ch = "]")

  self.buff.writeText(self.w-1, self.h-1, "┘", fg = BorderActionColor.color(self.resizable))

  return self.buff

method draw*(self: PWindow): TDrawBuffer = 
  return drawWindow(self)

proc createWindow*(w, h: int, title: string): PWindow = 
  result = new(TWindow)
  result.frame = (title: title, hasBorder: true)
  result.minWidth = 2
  result.minHeight = 2
  result.growMode = gmGrowAsParent
  result.setWidthHeight(w, h)

when isMainModule:
  import unittest
  import streams

  test "inheritance":
    let view: PView = createWindow(0, 0, "title")
    view.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
    discard view.draw()
    check view.name == "Window(title)"

  test "Ignores mouse clickes outside its area":
    let win = createWindow(10, 10, "test")
    let event = PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 30, localMouseY: 40, local: false)
    win.handleEvent(event)
    check event.kind == TEventKind.eventMouseButtonDown

  test "Catches mouse events that occurs inside of it":
    let win = createWindow(10, 10, "test")
    let event = PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 5, localMouseY: 5, local: true)
    win.handleEvent(event)
    check event.kind == TEventKind.eventNothing

  test "Doesn't catch keyboard events":
    let win = createWindow(10, 10, "test")
    let event = PEvent(kind: TEventKind.eventKey)
    win.handleEvent(event)
    check event.kind == TEventKind.eventKey

  test "writeData":
    let view: PView = createWindow(10, 10, "test")
    let stream = newStringStream()
    view.writeData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)

  test "readData":
    let view: PView = createWindow(10, 10, "test")
    let stream = newStringStream()
    view.readData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)