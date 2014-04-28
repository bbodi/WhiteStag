import view
import frame
import color
import drawbuffer
import event
import option
import rect


type
  PScrollBar* = ref TScrollBar
  TScrollBar* = object of TView
    view: PView
    maxValue: int
    minValue: int
    currentValue: int
    step: int

const
  cmdScrollBarChanged* = TCmd("system.scrollbar.cmdScrollBarChanged")

method name*(self: PScrollBar): string = 
  "ScrollBar"

proc setRange*(self: PScrollBar, min, max: int) =
  self.minValue = min
  self.maxValue = max
  self.step = int((max-min) / self.h)

proc `value`*(self: PScrollBar): int = self.currentValue

proc `value=`*(self: PScrollBar, value: int) =
  self.currentValue = value

proc `add`*(self: PScrollBar, value: int) =
  inc self.currentValue, value

proc moveDown(self: PScrollBar) = 
  self.currentValue += self.step

proc moveUp(self: PScrollBar) = 
  self.currentValue -= self.step

proc getPosition(self: PScrollBar, minVal, maxVal, curVal: int): int = 
  let valuesRange =  maxVal - minVal
  if valuesRange == 0:
    return 0

  let displaySpace = self.h
  let cur = ((curVal - minVal) * displaySpace + (valuesRange div 2-1)) / valuesRange
  return int(cur)

method handleEvent*(self: PScrollBar, event: PEvent) = 
  if event.kind == TEventKind.eventMouseButtonDown and event.local:
    let pos = self.getPosition(self.minValue, self.maxValue, self.currentValue)
    if event.localMouseY > pos:
      self.moveDown()
    else:
      self.moveUp()
    self.broadcastCommand(cmdScrollBarChanged, self)
    event.setProcessed()
  elif event.kind == TEventKind.eventKey:
    discard

method draw*(self: PScrollBar): TDrawBuffer = 
  var buff = createDrawBuffer(self.w, self.h)
  buff.setCell(0, 1, ch = "↑", bg= ColorGray)
  buff.setCell(0, self.h-1, ch = "↓", bg= ColorGray)
  buff.setCells(0, 2, 3, self.h, bg= ColorGray)

  let pos = self.getPosition(self.minValue, self.maxValue, self.currentValue)
  buff.setCell(0, 1 + 1 + pos, ch = "X")
  return buff

proc addScrollBarToRight*(view: PView): PScrollBar = 
  let scrollBar = new(TScrollBar)
  scrollbar.setWidthHeight(1, view.h-1)
  let x = view.w-1
  let y = 0
  view.addView(scrollBar, x, y)
  scrollBar.view = view
  return scrollBar

when isMainModule:
  import unittest
  import streams

  test "inheritance":
    let scrollBar: PView = new(TScrollBar)
    discard scrollBar.draw()
    check scrollBar.name == "ScrollBar"

  test "scroll position":
    let scrollBar = new(TScrollBar)
    scrollbar.setWidthHeight(1, 10)
    check 5 == scrollBar.getPosition(0, 10, 5)
    check 0 == scrollBar.getPosition(0, 100, 5)
    check 1 == scrollBar.getPosition(0, 100, 10)

    check 5 == scrollBar.getPosition(0, 100, 50)

    scrollbar.setWidthHeight(1, 5)
    check 2 == scrollBar.getPosition(0, 100, 50)
    check 0 == scrollBar.getPosition(0, 100, 10)
    check 1 == scrollBar.getPosition(0, 100, 20)

    check 0 == scrollBar.getPosition(50, 100, 50)
    check 3 == scrollBar.getPosition(50, 100, 80)

  test "writeData":
    let view: PView = new(TScrollBar)
    let stream = newStringStream()
    view.writeData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)

  test "readData":
    let view: PView = new(TScrollBar)
    let stream = newStringStream()
    view.readData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)

  