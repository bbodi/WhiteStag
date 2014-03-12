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
    cursorPos: TPoint
    showCursor: bool
    selectRegionStart: TPoint
    

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
  var goingBackward, goingForward: bool
  case event.key:  
  of TKey.KeyHome, TKey.KeyArrowLeft:
    goingBackward = true
  of TKey.KeyEnd , TKey.KeyArrowRight:
    goingForward = true
  else:
    discard

  let shiftJustPressed = self.selectRegionStart == (-1, -1) and event.keyModifier.shift
  let shiftJustReleased = self.selectRegionStart != (-1, -1) and not event.keyModifier.shift

  if shiftJustPressed:
    self.selectRegionStart = self.cursorPos
  elif shiftJustReleased:
    let wentForward = self.cursorPos > self.selectRegionStart
    let wentBackward = self.cursorPos < self.selectRegionStart
    if goingBackward and wentForward:
      self.cursorPos = self.selectRegionStart
    elif goingForward and wentBackward:
      self.cursorPos = self.selectRegionStart
    self.selectRegionStart = (-1, -1)

  if event.key == TKey.KeyArrowLeft and self.cursorPos.x > 0 and not shiftJustReleased:
    dec self.cursorPos.x
  elif event.key == TKey.KeyArrowRight and self.cursorPos.x < self.text.runeLen and not shiftJustReleased:
    inc self.cursorPos.x
  elif event.key == TKey.KeyHome:
    self.cursorPos.x = 0
  elif event.key == TKey.KeyEnd:
    self.cursorPos.x = self.text.runeLen

  if self.cursorPos == self.selectRegionStart:
    self.selectRegionStart = (-1, -1)

proc handleKey*(self: PTextArea, event: PEvent) =
  case event.key:  
  of TKey.KeyNormal:
    self.text.insertChar(event.unicode, self.cursorPos.x)
  of TKey.KeySpace:
    self.text.insertChar(' ', self.cursorPos.x)
  of TKey.KeyArrowRight, TKey.KeyArrowLeft, TKey.KeyHome, TKey.KeyEnd:
    self.handleCursorMoving(event)
  of TKey.KeyBackspace:
    let pos = self.cursorPos
    if pos.x != 0:
      removeChar(self.text, self.cursorPos.x-1)
      dec self.cursorPos.x
  of TKey.KeyDelete:
    removeChar(self.text, self.cursorPos.x)
    if self.cursorPos.x >= self.text.runeLen:
      self.cursorPos.x = self.text.runeLen-1
  of TKey.KeyEnter:
    self.text.insertChar(TRune(0x000A), self.cursorPos.x)
  of TKey.KeyTab:
    self.text.insertChar(TRune(0x0009), self.cursorPos.x)
  else:
    return
  self.modified()
  event.setProcessed()

    
method name*(self: PTextArea): string = "TextArea"

method handleEvent*(self: PTextArea, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if not event.local:
      return
    let pos = event.localMouseY * self.w + event.localMouseX
    self.cursorPos.x = if pos > self.text.runeLen: self.text.runeLen else: pos
    
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
    startSelection, endSelection: TPoint
    horizontalIndex: int
    textArea: PTextArea

proc createTextDrawer(textArea: PTextArea): ref TTextDrawer =
  result = new(TTextDrawer)
  result.startSelection.x = if textArea.selectRegionStart.x != -1: min(textArea.selectRegionStart.x, textArea.cursorPos.x) else: -1
  result.endSelection.x = if textArea.selectRegionStart.x != -1: max(textArea.selectRegionStart.x, textArea.cursorPos.x) else: -1
  result.textArea = textArea

proc drawChar(self: ref TTextDrawer, charToDraw: string, buff: var TDrawBuffer) =
    buff.writeText(self.xPos, self.yPos, charToDraw, fg = TextPanelTextColor.color(self.textArea.isFocused))
    if self.startSelection.x != -1 and self.horizontalIndex >= self.startSelection.x and self.horizontalIndex < self.endSelection.x:
      buff.setCell(self.xPos, self.yPos, bg = ColorGreen)
    if self.horizontalIndex == self.textArea.cursorPos.x and self.textArea.showCursor and self.textArea.isFocused:
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
  if self.horizontalIndex == self.textArea.cursorPos.x and self.textArea.showCursor and self.textArea.isFocused:
      buff.setCell(self.xPos, self.yPos, bg = ColorRed)

method draw*(self: PTextArea): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.h, ch="", bg = TextPanelColor.color(self.isFocused))
  let drawer = createTextDrawer(self)
  drawer.draw(self.buff)
  return self.buff

proc createTextArea*(w, h: int): PTextArea = 
  result = new(TTextArea)
  result.selectRegionStart = (-1, -1)
  result.setWidthHeight(w, h)
  result.text = ""


when isMainModule:
  import unittest

  suite "TextField Test Suite":
    setup:
      let parent = PTestView()
      let textArea: PTextArea = createTextArea(5, 5)
      parent.addView(textArea, 0, 0)
      textArea.setFocused()
      
    test "inheritance":
      let view: PView = createTextArea(10, 10)
      check "TextArea" == view.name
      discard view.draw()

    test "backspace":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "ést"
      check textArea.cursorPos.x == 0

    test "backspace 2":
      textArea.text = "tést"
      textArea.cursorPos.x = 2
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "tst"
      check textArea.cursorPos.x == 1

    test "backspace on first char":
      textArea.text = "tést"
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 0

    test "del":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check textArea.text == "tst"
      check textArea.cursorPos.x == 1

    test "del on last char":
      textArea.text = "tést"
      textArea.cursorPos.x = 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check textArea.text == "tés"
      check textArea.cursorPos.x == 2

    test "left":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 0

    test "left on first char":
      textArea.text = "tést"
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 0

    test "right":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 2

    test "right to the last char":
      textArea.text = "tést"
      textArea.cursorPos.x = 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 4

    test "right on last char":
      textArea.text = "tést"
      textArea.cursorPos.x = 4
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 4

    test "home":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 0

    test "end":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd))
      check textArea.text == "tést"
      check textArea.cursorPos.x == 4
      
    test "write at the end":
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("á", 0)))
      check textArea.text == "á"
      check textArea.cursorPos.x == 1

    test "write at the end 2":
      textArea.text = "á"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("á", 0)))
      check textArea.text == "áá"
      check textArea.cursorPos.x == 2

    test "insert a char":
      textArea.text = "áá"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("b", 0)))
      check textArea.text == "ábá"
      check textArea.cursorPos.x == 2

    test "insert at head":
      textArea.text = "áá"
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("b", 0)))
      check textArea.text == "báá"

    test "insert newline":
      textArea.text = "áá"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      check textArea.text == "á" & $TRune(10) & "á"
      check textArea.cursorPos.x == 2

    test "insert tab":
      textArea.text = "áá"
      textArea.cursorPos.x = 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
      check textArea.text == "á\tá"
      check textArea.cursorPos.x == 2

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
      textArea.cursorPos.x = 0

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 1

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 2

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 3

    test "selecting forward then deselect by right without shift":
      textArea.imitateKeyPresses("01234\t56")
      check textArea.text.runeLen == 8
      textArea.cursorPos.x = 0

      check textArea.selectRegionStart.x == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 3

    test "if selection is ended by left key, the cursor must jump to the start of the selection":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos.x = 0

      check textArea.selectRegionStart.x == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 0

    test "selecting backward":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.cursorPos.x == 8
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 8
      check textArea.cursorPos.x == 7

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 8
      check textArea.cursorPos.x == 6

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 8
      check textArea.cursorPos.x == 5

    test "selecting backward then deselect by left without shift":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.selectRegionStart.x == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 8
      check textArea.cursorPos.x == 5
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 5

    test "if selection is ended by right key, the cursor must jump to the start of the selection (which is the right side of the selction)":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.selectRegionStart.x == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 8
      check textArea.cursorPos.x == 5
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 8

    test "selection with shift+home button":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 8
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 8
      check textArea.cursorPos.x == 0

    test "selection with shift+end button":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos.x = 0

      check textArea.selectRegionStart.x == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 8

    test "selection with shift+end button at the end of the text":
      textArea.imitateKeyPresses("01234\t56")

      check textArea.selectRegionStart.x == -1
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 8

    test "selection ends with home button":
      textArea.imitateKeyPresses("01234\t56")

      textArea.selectRegionStart.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 0

    test "selection ends with end button":
      textArea.imitateKeyPresses("01234\t56")

      textArea.selectRegionStart.x = 8
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd))
      check textArea.selectRegionStart.x == -1
      check textArea.cursorPos.x == 8

    test "selected range are highlighted":
      textArea.imitateKeyPresses("01234\t56")
      textArea.cursorPos.x = 0

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
      textArea.cursorPos.x = 0

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

    test "Changing cursor position with mouse":
      textArea.imitateKeyPresses("01234\t56")
      
      check textArea.cursorPos.x == 8
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 3, localMouseY: 0, local: true))
      check textArea.cursorPos.x == 3
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 0, localMouseY: 0, local: true))
      check textArea.cursorPos.x == 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 6, localMouseY: 0, local: true))
      check textArea.cursorPos.x == 6
      # clicking after the end of the text
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 10, localMouseY: 0, local: true))
      check textArea.cursorPos.x == 8

    test "Pressing Home in the second row":
      textArea.imitateKeyPresses("01234567")
      
      check textArea.cursorPos == (2, 1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome))
      check textArea.cursorPos == (0, 1)

    test "Pressing End in the second row":
      textArea.imitateKeyPresses("01234567")
      
      check textArea.cursorPos == (2, 1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd))
      check textArea.cursorPos == (4, 1)

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