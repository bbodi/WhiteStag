import unicode
import streams

import view
import frame
import color
import drawbuffer
import event
import option
import sdlengine
import rect

type
  PTextArea* = ref TTextArea
  TTextArea* = object of TView
    text*: string
    cursorPos: int
    showCursor: bool
    selectRegionStart: int
    

method writeData*(self: PTextArea, stream: PStream) = 
  let copy = self.text
  stream.write(cast[int32](copy))
  
method readData*(self: PTextArea, stream: PStream) = 
  let strPtr = cast[string](stream.readInt32())
  self.text = strPtr

proc handleMouse(self: PTextArea, event: PEvent) =
  discard

proc insertChar(self: var string, ch: TRune, cursorPos: var int) =
  if cursorPos == 0:
    self = $ch & self
  else:
    var runePos = 0
    for i in 0..cursorPos-1:
      runePos += self.runeLenAt(runePos)
    self = self[0..runePos-1] & $ch & self[runePos..high(self)]
  inc cursorPos

proc removeChar(self: var string, cursorPos: int) =
  var startRunePos = 0
  if cursorPos > 0:
    for i in 0..cursorPos-1:
      startRunePos += self.runeLenAt(startRunePos)

  let endRunePos = startRunePos + self.runeLenAt(startRunePos)
  var firstHalf: string
  if startRunePos == 0:
    firstHalf = ""
  else:
    firstHalf = self[0..startRunePos-1]
  self = firstHalf & self[endRunePos..high(self)]
    

proc insertChar(self: var string, ch: char, cursorPos: var int) =
  self.insertChar(runeAt($ch, 0), cursorPos)

proc handleCursorMoving*(self:PTextArea, event: PEvent) =
  let shiftJustPressed = self.selectRegionStart == -1 and event.keyModifier.shift
  let shiftJustReleased = self.selectRegionStart != -1 and not event.keyModifier.shift

  if shiftJustPressed:
    self.selectRegionStart = self.cursorPos
  elif shiftJustReleased:
    let goingForward = self.cursorPos > self.selectRegionStart
    let goingBackward = self.cursorPos < self.selectRegionStart
    if event.key == TKey.KeyArrowLeft and goingForward:
      self.cursorPos = self.selectRegionStart
    elif event.key == TKey.KeyArrowRight and goingBackward:
      self.cursorPos = self.selectRegionStart
    self.selectRegionStart = -1

  if event.key == TKey.KeyArrowLeft and self.cursorPos > 0 and not shiftJustReleased:
    dec self.cursorPos
  elif event.key == TKey.KeyArrowRight and self.cursorPos < self.text.runeLen and not shiftJustReleased:
    inc self.cursorPos

proc handleKey*(self: PTextArea, event: PEvent) =
  case event.key:  
  of TKey.KeyNormal:
    self.text.insertChar(event.unicode, self.cursorPos)
  of TKey.KeySpace:
    self.text.insertChar(' ', self.cursorPos)
  of TKey.KeyArrowRight, TKey.KeyArrowLeft:
    self.handleCursorMoving(event)
  of TKey.KeyBackspace:
    let pos = self.cursorPos
    if pos != 0:
      removeChar(self.text, self.cursorPos-1)
      dec self.cursorPos
  of TKey.KeyDelete:
    removeChar(self.text, self.cursorPos)
    if self.cursorPos >= self.text.runeLen:
      self.cursorPos = self.text.runeLen-1
  of TKey.KeyHome:
    self.cursorPos = 0
  of TKey.KeyEnd:
    self.cursorPos = self.text.runeLen
  of TKey.KeyEnter:
    self.text.insertChar(TRune(0x000A), self.cursorPos)
  of TKey.KeyTab:
    self.text.insertChar(TRune(0x0009), self.cursorPos)
  else:
    return
  self.modified()
  event.setProcessed()

    
method name*(self: PTextArea): string = "TextArea"

method handleEvent*(self: PTextArea, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    discard
  of TEventKind.eventKey:
    if self.isFocused:
      self.handleKey(event)
  of TEventKind.eventTick:
    self.showCursor = not self.showCursor
    self.modified()
  else:
    discard

type
  TTextDrawer = object
    xPos, yPos: int
    startSelection, endSelection: int
    horizontalIndex: int
    textArea: PTextArea

proc createTextDrawer(textArea: PTextArea): ref TTextDrawer =
  result = new(TTextDrawer)
  result.startSelection = if textArea.selectRegionStart != -1: min(textArea.selectRegionStart, textArea.cursorPos) else: -1
  result.endSelection = if textArea.selectRegionStart != -1: max(textArea.selectRegionStart, textArea.cursorPos) else: -1
  result.textArea = textArea

proc drawChar(self: ref TTextDrawer, charToDraw: string, buff: var TDrawBuffer) =
    buff.writeText(self.xPos, self.yPos, charToDraw, fg = TextPanelTextColor.color(self.textArea.isFocused))
    if self.startSelection != -1 and self.horizontalIndex >= self.startSelection and self.horizontalIndex < self.endSelection:
      buff.setCell(self.xPos, self.yPos, bg = ColorGreen)
    if self.horizontalIndex == self.textArea.cursorPos and self.textArea.showCursor and self.textArea.isFocused:
      buff.setCell(self.xPos, self.yPos, bg = ColorRed)
    if self.xPos == self.textArea.w - 1:
      self.xPos = 0
      inc self.yPos
    else:
      inc self.xPos

proc draw(self: ref TTextDrawer, buff: var TDrawBuffer) =
  for ch in runes(self.textArea.text):
    if ch == TRune(0x0009): 
      for i in 0..3:
        self.drawChar(" ", buff)
    elif ch == TRune(0x000A): 
      inc self.yPos
      self.xPos = 0
    else:
      self.drawChar(ch.toUTF8, buff)
    inc self.horizontalIndex
  if self.horizontalIndex == self.textArea.cursorPos and self.textArea.showCursor and self.textArea.isFocused:
      buff.setCell(self.xPos, self.yPos, bg = ColorRed)

method draw*(self: PTextArea): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.h, ch="", bg = TextPanelColor.color(self.isFocused))
  let drawer = createTextDrawer(self)
  drawer.draw(self.buff)
  return self.buff

proc createTextArea*(w, h: int): PTextArea = 
  result = new(TTextArea)
  result.selectRegionStart = -1
  result.setWidthHeight(w, h)
  result.text = ""


when isMainModule:
  import unittest

  suite "TextField Test Suite":
    setup:
      let parent = PTestView()
      let textArea: PTextArea = createTextArea(5, 5)
      textArea.text = "tést"
      parent.addView(textArea, 0, 0)
      textArea.setFocused()
      
    test "inheritance":
      let view: PView = createTextArea(10, 10)
      check "TextArea" == view.name
      discard view.draw()

    test "backspace":
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "ést"
      check textArea.cursorPos == 0

    test "backspace 2":
      textArea.cursorPos = 2
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "tst"
      check textArea.cursorPos == 1

    test "backspace on first char":
      textArea.cursorPos = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "tést"
      check textArea.cursorPos == 0

    test "del":
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check textArea.text == "tst"
      check textArea.cursorPos == 1

    test "del on last char":
      textArea.cursorPos = 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check textArea.text == "tés"
      check textArea.cursorPos == 2

    test "left":
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.text == "tést"
      check textArea.cursorPos == 0

    test "left on first char":
      textArea.cursorPos = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.text == "tést"
      check textArea.cursorPos == 0

    test "right":
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.text == "tést"
      check textArea.cursorPos == 2

    test "right to the last char":
      textArea.cursorPos = 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.text == "tést"
      check textArea.cursorPos == 4

    test "right on last char":
      textArea.cursorPos = 4
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.text == "tést"
      check textArea.cursorPos == 4

    test "home":
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome))
      check textArea.text == "tést"
      check textArea.cursorPos == 0

    test "end":
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd))
      check textArea.text == "tést"
      check textArea.cursorPos == 4
      
    test "write at the end":
      textArea.text = ""
      textArea.cursorPos = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("á", 0)))
      check textArea.text == "á"
      check textArea.cursorPos == 1

    test "write at the end 2":
      textArea.text = "á"
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("á", 0)))
      check textArea.text == "áá"
      check textArea.cursorPos == 2

    test "insert a char":
      textArea.text = "áá"
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("b", 0)))
      check textArea.text == "ábá"
      check textArea.cursorPos == 2

    test "insert at head":
      textArea.text = "áá"
      textArea.cursorPos = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("b", 0)))
      check textArea.text == "báá"

    test "insert newline":
      textArea.text = "áá"
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      check textArea.text == "á" & $TRune(10) & "á"
      check textArea.cursorPos == 2

    test "insert tab":
      textArea.text = "áá"
      textArea.cursorPos = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
      check textArea.text == "á\tá"
      check textArea.cursorPos == 2

    test "drawing chars in the first row":
      textArea.text = "áá"
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "á"
      check buff.cell(1, 0).ch.toUTF8 == "á"

    test "drawing chars in the first two rows":
      textArea.text = "0123456789"
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(2, 0).ch.toUTF8 == "2"
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(4, 0).ch.toUTF8 == "4"

      check buff.cell(0, 1).ch.toUTF8 == "5"
      check buff.cell(1, 1).ch.toUTF8 == "6"
      check buff.cell(2, 1).ch.toUTF8 == "7"
      check buff.cell(3, 1).ch.toUTF8 == "8"
      check buff.cell(4, 1).ch.toUTF8 == "9"

    test "drawing chars in the first three rows":
      textArea.text = "012345678901234"
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(2, 0).ch.toUTF8 == "2"
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(4, 0).ch.toUTF8 == "4"

      check buff.cell(0, 1).ch.toUTF8 == "5"
      check buff.cell(1, 1).ch.toUTF8 == "6"
      check buff.cell(2, 1).ch.toUTF8 == "7"
      check buff.cell(3, 1).ch.toUTF8 == "8"
      check buff.cell(4, 1).ch.toUTF8 == "9"

      check buff.cell(0, 2).ch.toUTF8 == "0"
      check buff.cell(1, 2).ch.toUTF8 == "1"
      check buff.cell(2, 2).ch.toUTF8 == "2"
      check buff.cell(3, 2).ch.toUTF8 == "3"
      check buff.cell(4, 2).ch.toUTF8 == "4"

    proc imitateKeyPresses(textArea: PTextArea, input: string) =
      for i, ch in input:
        if ch == '\t':
          textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
        else:
          textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt(input, i))) 

    test "drawing newLines":
      textArea.showCursor = true
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("0", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("1", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("2", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("3", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("4", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("5", 0)))
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"

      check buff.cell(0, 1).ch.toUTF8 == "2"
      check buff.cell(1, 1).ch.toUTF8 == "3"

      check buff.cell(0, 2).ch.toUTF8 == "4"
      check buff.cell(1, 2).ch.toUTF8 == "5"

      #cursor
      check buff.cell(2, 2).bg == ColorRed

    test "drawing tab":
      textArea.showCursor = true
      textArea.imitateKeyPresses("01\t23")
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(2, 0).ch.toUTF8 == " "
      check buff.cell(3, 0).ch.toUTF8 == " "
      check buff.cell(4, 0).ch.toUTF8 == " "

      check buff.cell(0, 1).ch.toUTF8 == " "
      check buff.cell(1, 1).ch.toUTF8 == "2"
      check buff.cell(2, 1).ch.toUTF8 == "3"

      #cursor
      check buff.cell(3, 1).bg == ColorRed
  
    test "selecting forward":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos = 0

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.cursorPos == 1

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.cursorPos == 2

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.cursorPos == 3

    test "selecting forward then deselect by right without shift":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos = 0

      check textArea.selectRegionStart == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.cursorPos == 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.selectRegionStart == -1
      check textArea.cursorPos == 3

    test "if selection is ended by left key, the cursor must jump to the start of the selection":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos = 0

      check textArea.selectRegionStart == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.cursorPos == 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.selectRegionStart == -1
      check textArea.cursorPos == 0

    test "selecting backward":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.cursorPos == 8
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 8
      check textArea.cursorPos == 7

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 8
      check textArea.cursorPos == 6

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 8
      check textArea.cursorPos == 5

    test "selecting backward then deselect by left without shift":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.selectRegionStart == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 8
      check textArea.cursorPos == 5
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.selectRegionStart == -1
      check textArea.cursorPos == 5

    test "if selection is ended by right key, the cursor must jump to the start of the selection (which is the right side of the selction)":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.selectRegionStart == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 8
      check textArea.cursorPos == 5
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.selectRegionStart == -1
      check textArea.cursorPos == 8

    test "selected range are highlighted":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos = 0

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))

      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      let defaultColor = buff.cell(0, 0).bg

      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(1, 0).bg != defaultColor
      check buff.cell(2, 0).ch.toUTF8 == "2"
      check buff.cell(2, 0).bg != defaultColor
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(3, 0).bg != defaultColor

      check buff.cell(4, 0).ch.toUTF8 == "4"
      check buff.cell(4, 0).bg == defaultColor

    test "selected tabs are highlighted":
      textArea.imitateKeyPresses("01\t2")
      textArea.cursorPos = 0

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))

      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      let defaultColor = buff.cell(0, 0).bg

      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(1, 0).bg != defaultColor
      check buff.cell(2, 0).ch.toUTF8 == " "
      check buff.cell(2, 0).bg != defaultColor
      check buff.cell(3, 0).ch.toUTF8 == " "
      check buff.cell(3, 0).bg != defaultColor
      check buff.cell(4, 0).ch.toUTF8 == " "
      check buff.cell(4, 0).bg != defaultColor
      check buff.cell(5, 0).ch.toUTF8 == " "
      check buff.cell(5, 0).bg != defaultColor


    type 
      TTestData = object
        str: string

    test "writeData":
      textArea.text = "árvíztűrő fúrógép"
      var data: TTestData
      data.str = "123"
      textArea.groupWriteDataTo(data)
      check(data.str  == "árvíztűrő fúrógép")

    test "readData":
      var data: TTestData
      data.str = "árvíztűrő fúrógép"
      textArea.groupReadDataFrom(data)
      check(textArea.text == "árvíztűrő fúrógép")

    test "writeReadData":
      var data: TTestData
      textArea.text = "árvíztűrő fúrógép"
      textArea.groupWriteDataTo(data)
      check(data.str  == "árvíztűrő fúrógép")
      textArea.text = ""
      textArea.groupReadDataFrom(data)
      check(textArea.text == "árvíztűrő fúrógép")