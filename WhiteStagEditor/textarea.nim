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

proc handleKey*(self: PTextArea, event: PEvent) =
  case event.key:  
  of TKey.KeyNormal:
    self.text.insertChar(event.unicode, self.cursorPos)
  of TKey.KeySpace:
    self.text.insertChar(' ', self.cursorPos)
  of TKey.KeyArrowLeft:
    if self.cursorPos > 0:
      dec self.cursorPos
  of TKey.KeyArrowRight:
    if self.cursorPos < self.text.runeLen:
      inc self.cursorPos
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

method draw*(self: PTextArea): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.h, ch="", bg = TextPanelColor.color(self.isFocused))

  var drawX, drawY: int
  var horizontalIndex: int
  for ch in runes(self.text):
    if ch == TRune(0x0009): 
      inc drawX, 4
      if drawX >= self.w - 1:
        drawX = 0
        inc drawY
      inc horizontalIndex
      continue
    elif ch == TRune(0x000A): 
      inc drawY
      drawX = 0
      inc horizontalIndex
      continue
    self.buff.writeText(drawX, drawY, ch.toUTF8, fg = TextPanelTextColor.color(self.isFocused))
    if horizontalIndex == self.cursorPos and self.showCursor and self.isFocused:
      self.buff.setCell(drawX, drawY, bg = ColorRed)
    if drawX == self.w - 1:
      drawX = 0
      inc drawY
    else:
      inc drawX
    inc horizontalIndex
  if horizontalIndex == self.cursorPos and self.showCursor and self.isFocused:
      self.buff.setCell(drawX, drawY, bg = ColorRed)
  return self.buff

proc createTextArea*(w, h: int): PTextArea = 
  result = new(TTextArea)
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
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("0", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("1", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("2", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("3", 0)))
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"

      check buff.cell(0, 1).ch.toUTF8 == "2"
      check buff.cell(1, 1).ch.toUTF8 == "3"

      #cursor
      check buff.cell(2, 1).bg == ColorRed

    test "selecting forward":
      textArea.showCursor = true
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("0", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("1", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("2", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("3", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("4", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("4", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("5", 0)))
      textArea.cursorPos = 0

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.selectRegionEnd == 1

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.selectRegionEnd == 2

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.selectRegionEnd == 3

    test "selecting forward then deselect":
      textArea.showCursor = true
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("0", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("1", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("2", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("3", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("4", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("4", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("5", 0)))
      textArea.cursorPos = 0

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == 0
      check textArea.selectRegionEnd == 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyShift, up: true)

      #cursor
      check buff.cell(2, 2).bg == ColorRed


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