import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect


type
  PProgressBar* = ref TProgressBar
  TProgressBar* = object of TView
    maxValue: int
    minValue: int
    currentValue: int
    text*: string


method name*(self: PProgressBar): string = 
  "ProgressBar"

proc `value=`*(self: PProgressBar, val: int) =
  self.currentValue = val

proc value*(self: PProgressBar): int = self.currentValue

proc getPosition*(self: PProgressBar, minVal, maxVal, curVal: int): int = 
  let valuesRange =  maxVal - minVal
  if valuesRange == 0:
    return 0

  let displaySpace = self.w
  let cur = ((curVal - minVal) * displaySpace + (valuesRange div 2-1)) / valuesRange
  return int(cur)

method handleEvent*(self: PProgressBar, event: PEvent) = 
  discard

method draw*(self: PProgressBar): TDrawBuffer = 
  let pos = self.getPosition(self.minValue, self.maxValue, self.currentValue)

  self.buff.setCells(0, 0, pos, self.h, bg = (r: 50'u8, g: 200'u8, b: 50'u8, visible: true))
  self.buff.setCells(pos, 0, self.w-pos, self.h, bg= (r: 200'u8, g: 50'u8, b: 50'u8, visible: true))
  var textOnBar: string
  if self.text != nil:
    textOnBar = self.text
  else:
    let r = self.maxValue - self.minValue
    let percent = int((self.currentValue - self.minValue) / r * 100)
    textOnBar = $percent & "%"
  let center = self.w div 2 - textOnBar.len div 2
  self.buff.writeText(center, 0, textOnBar, fg = ColorWhite)
  return self.buff

proc createProgressBar*(min, max, w, h: int): PProgressBar = 
  result = new(TProgressBar)
  result.setWidthHeight(w, h)
  result.minValue = min
  result.maxValue = max
  result.growMode = {gmRightToParentsRight}

when isMainModule:
  import unittest
  import streams

  test "inheritance":
    let scrollBar: PView = new(TProgressBar)
    discard scrollBar.draw()
    check scrollBar.name == "ProgressBar"

  test "scroll position":
    let scrollBar = new(TProgressBar)
    scrollBar.setWidthHeight(10, 1)
    check 5 == scrollBar.getPosition(0, 10, 5)
    check 0 == scrollBar.getPosition(0, 100, 5)
    check 1 == scrollBar.getPosition(0, 100, 10)

    check 5 == scrollBar.getPosition(0, 100, 50)

    scrollBar.setWidthHeight(5, 1)
    check 2 == scrollBar.getPosition(0, 100, 50)
    check 0 == scrollBar.getPosition(0, 100, 10)
    check 1 == scrollBar.getPosition(0, 100, 20)

    check 0 == scrollBar.getPosition(50, 100, 50)
    check 3 == scrollBar.getPosition(50, 100, 80)

  test "writeData":
    let view: PView = new(TProgressBar)
    let stream = newStringStream()
    view.writeData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)

  test "readData":
    let view: PView = new(TProgressBar)
    let stream = newStringStream()
    view.readData(stream)
    check(stream.data == "")
    check(stream.getPosition == 0)
  