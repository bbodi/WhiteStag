import unicode
import streams

import utfstring
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
    lines: seq[UTFString]
    cursorPos: TPoint
    showCursor: bool
    selectRegionStart: TPoint

proc findFirstWhiteSpace(str: UTFString, runePos: int): int =
  var pos = runePos
  var lastPos = pos
  while pos > 0 and pos < str.len:
    if str.runeAt(pos).isWhiteSpace:
      return lastPos
    lastPos = pos
    dec pos
  return pos

proc findLastWhiteSpace(str: UTFString, runePos: int): int =
  var pos = runePos
  var lastPos = pos
  while pos < str.len-1:
    if str.runeAt(pos).isWhiteSpace:
      return lastPos
    lastPos = pos
    inc pos
  return pos

proc updateText(self: PTextArea, cstr: string) =
  self.lines = @[]
  var str = initString(cstr)

  var currentLineText = ""
  var i = 0
  while i < str.len:
    let ch = str.at(i)
    if ch == "\n":
      self.lines.add(initString(currentLineText))
      currentLineText = ""
    else:
      currentLineText &= ch
    inc i
  self.lines.add(initString(currentLineText))

proc `text=`*(self: PTextArea, txt: string) =
  self.updateText(txt)

proc `text`*(self: PTextArea): string =
  result = ""
  for i, line in self.lines:
    if i != 0:
      result &= "\n"
    result &= line

method writeData*(self: PTextArea, stream: PStream) = 
  let copy = self.text
  stream.write(cast[int32](copy))
  
method readData*(self: PTextArea, stream: PStream) = 
  let strPtr = cast[string](stream.readInt32())
  self.text = strPtr

proc clearSelection(self: PTextArea) =
  self.selectRegionStart = (-1, -1)

proc handleMouse(self: PTextArea, event: PEvent) =
  discard

proc insertCharAtCursor(self: PTextArea, ch: TRune) =
  self.lines[self.cursorPos.y].insert(ch, self.cursorPos.x)
  inc self.cursorPos.x

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

proc handleCursorMoving*(self:PTextArea, event: PEvent) =
  let currentLineText = self.lines[self.cursorPos.y]

  var goingBackward, goingForward: bool
  case event.key:  
  of TKey.KeyHome, TKey.KeyArrowLeft, TKey.KeyArrowUp:
    goingBackward = true
  of TKey.KeyEnd , TKey.KeyArrowRight, TKey.KeyArrowDown:
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
    self.clearSelection()

  if event.key == TKey.KeyArrowLeft and self.cursorPos.x > 0 and not shiftJustReleased:
    dec self.cursorPos.x
  elif event.key == TKey.KeyArrowRight and self.cursorPos.x < currentLineText.len and not shiftJustReleased:
    inc self.cursorPos.x
  elif event.key == TKey.KeyHome:
    self.cursorPos.x = 0
  elif event.key == TKey.KeyEnd:
    self.cursorPos.x = currentLineText.len
  elif event.key == TKey.KeyArrowDown and self.cursorPos.y < self.lines.len-1:
    inc self.cursorPos.y
    let newLineText = self.lines[self.cursorPos.y]
    if newLineText.len <= self.cursorPos.x:
      self.cursorPos.x = newLineText.len
  elif event.key == TKey.KeyArrowUp and self.cursorPos.y > 0:
    dec self.cursorPos.y
    let newLineText = self.lines[self.cursorPos.y]
    if newLineText.len <= self.cursorPos.x:
      self.cursorPos.x = newLineText.len

  if self.cursorPos == self.selectRegionStart:
    self.clearSelection()

proc handleKey*(self: PTextArea, event: PEvent) =
  case event.key:  
  of TKey.KeyNormal:
    self.insertCharAtCursor(event.unicode)
  of TKey.KeySpace:
    self.insertCharAtCursor(TRune(0x0020))
  of TKey.KeyArrowRight, TKey.KeyArrowLeft, TKey.KeyHome, TKey.KeyEnd, TKey.KeyArrowUp, TKey.KeyArrowDown:
    self.handleCursorMoving(event)
  of TKey.KeyBackspace:
    let pos = self.cursorPos
    if pos.x != 0:
      self.lines[self.cursorPos.y].remove(self.cursorPos.x-1)
      dec self.cursorPos.x
  of TKey.KeyDelete:
    self.lines[self.cursorPos.y].remove(self.cursorPos.x)
    let currentLineText = self.lines[self.cursorPos.y]
    if self.cursorPos.x >= currentLineText.len:
      if currentLineText.len > 0:
        self.cursorPos.x = currentLineText.len-1
  of TKey.KeyEnter:
    let cursorX = self.cursorPos.x
    let cursorY = self.cursorPos.y
    let line = self.lines[cursorY]
    self.lines.insert(initString(""), cursorY+1)
    self.lines[cursorY].set("")

    var 
      i: int
    while i < line.len:
      let ch = line.runeAt(i)
      if i < cursorX:
        self.lines[cursorY].append(ch)
      else:
        self.lines[cursorY+1].append(ch)
      inc i
    inc self.cursorPos.y
    self.cursorPos.x = 0
  of TKey.KeyTab:
    self.insertCharAtCursor(TRune(0x0009))
  else:
    return
  self.modified()
  event.setProcessed()

    
method name*(self: PTextArea): string = "TextArea"

proc handleDoubleClick(self: PTextArea) =
  var cursorX = self.cursorPos.x
  let cursorY = self.cursorPos.y
  let currentLineText = self.lines[cursorY]
  let clickedAfterText = cursorX == currentLineText.len
  if clickedAfterText:
    dec cursorX
  let firstPos = findFirstWhiteSpace(currentLineText, cursorX)
  let lastPos = 
    if clickedAfterText:
      cursorX + 1
    else:
      findLastWhiteSpace(currentLineText, cursorX)+1
  self.selectRegionStart = (firstPos, cursorY)
  self.cursorPos = (lastPos, cursorY)

method handleEvent*(self: PTextArea, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    if not event.local:
      return
    if self.lines.len == 0:
      event.setProcessed()
      return
    let posY = event.localMouseY
    self.cursorPos.y = if posY >= self.lines.len: self.lines.len-1 else: posY
    var currentLineText = self.lines[self.cursorPos.y]
    let posX = event.localMouseX
    self.cursorPos.x = if posX > currentLineText.len: currentLineText.len else: posX
    self.clearSelection()
    if event.doubleClick:
      self.handleDoubleClick()
    self.modified()
    event.setProcessed()
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
  result.startSelection = (-1, -1)
  result.endSelection = (-1, -1)
  if textArea.selectRegionStart != (-1, -1):
    if textArea.selectRegionStart.y < textArea.cursorPos.y:
      result.startSelection = textArea.selectRegionStart
      result.endSelection = textArea.cursorPos
    elif textArea.selectRegionStart.y > textArea.cursorPos.y:
      result.startSelection = textArea.cursorPos
      result.endSelection = textArea.selectRegionStart
    elif textArea.selectRegionStart.x < textArea.cursorPos.x:
      result.startSelection = textArea.selectRegionStart
      result.endSelection = textArea.cursorPos
    elif textArea.selectRegionStart.x > textArea.cursorPos.x:
      result.startSelection = textArea.cursorPos
      result.endSelection = textArea.selectRegionStart

  result.textArea = textArea

proc drawCursorIfNeeded(self: ref TTextDrawer, buff: var TDrawBuffer) =
  let isCurrentRow = self.yPos == self.textArea.cursorPos.y
  let isCurrentColumn = self.horizontalIndex == self.textArea.cursorPos.x
  if isCurrentRow and isCurrentColumn and self.textArea.showCursor and self.textArea.isFocused:
    buff.setCell(self.xPos, self.yPos, bg = ColorRed)

proc drawChar(self: ref TTextDrawer, charToDraw: string, buff: var TDrawBuffer) =
  buff.writeText(self.xPos, self.yPos, charToDraw, fg = TextPanelTextColor.color(self.textArea.isFocused))
  if self.startSelection.x != -1:
    let oneLineSelection = self.yPos == self.startSelection.y and self.yPos == self.endSelection.y
    let xIsOk = self.horizontalIndex >= self.startSelection.x and self.horizontalIndex < self.endSelection.x

    let firstSelectedLine = self.yPos == self.startSelection.y and self.horizontalIndex >= self.startSelection.x
    let middleSelectedLine = self.yPos > self.startSelection.y and self.yPos < self.endSelection.y
    let lastSelectedLine = self.yPos == self.endSelection.y and self.horizontalIndex < self.endSelection.x
    var needHighlight = false
    if oneLineSelection:
      if xIsOk:
        needHighlight = true
    elif firstSelectedLine or middleSelectedLine or lastSelectedLine:
      needHighlight = true
    if needHighlight:
      buff.setCell(self.xPos, self.yPos, bg = ColorGreen)
  self.drawCursorIfNeeded(buff)
  inc self.xPos

proc draw(self: ref TTextDrawer, buff: var TDrawBuffer) =
  self.yPos = -1
  for line in self.textArea.lines:
    inc self.yPos
    self.xPos = 0
    self.horizontalIndex = 0
    for i in 0..line.len-1:
      let ch = line.at(i)
      if ch == "\t":
        for j in 0..3:
          self.drawChar(" ", buff)
      else:
        self.drawChar(ch, buff)
      inc self.horizontalIndex
    self.drawCursorIfNeeded(buff)
    

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
      let textArea: PTextArea = createTextArea(10, 5)
      parent.addView(textArea, 0, 0)
      textArea.setFocused()
      
    test "inheritance":
      let view: PView = createTextArea(10, 10)
      check "TextArea" == view.name
      discard view.draw()

    test "setting text with newlines":
      textArea.text = "a\nb\nc"
      check textArea.lines.len == 3
      check textArea.lines[0] == "a"
      check textArea.lines[1] == "b"
      check textArea.lines[2] == "c"

    test "setting long text: line wrapping occurs at drawing, long lines are stored in one line!":
      textArea.text = "012340123401234"
      check textArea.lines.len == 1
      check textArea.lines[0] == "012340123401234"

    test "setting UTF8 text":
      textArea.text = "áéőúóáéőúóáéőúó"
      check textArea.lines.len == 1
      check textArea.lines[0] == "áéőúóáéőúóáéőúó"

    test "backspace":
      textArea.text = "tést"
      textArea.cursorPos.x = 1
      check textArea.cursorPos.y == 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check textArea.text == "ést"
      check textArea.cursorPos.x == 0
      check textArea.cursorPos.y == 0

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

    test "del single char":
      textArea.text = "é"
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check textArea.text == ""
      check textArea.cursorPos.x == 0

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
      check textArea.cursorPos.y == 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      check textArea.text == "á\ná"
      check textArea.cursorPos.x == 0
      check textArea.cursorPos.y == 1
      check textArea.lines.len == 2
      check textArea.lines[0] == "á"
      check textArea.lines[1] == "á"

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

    test "drawing long text: there is no line wrapping!":
      textArea.text = "01234567890123456789"
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(2, 0).ch.toUTF8 == "2"
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(4, 0).ch.toUTF8 == "4"
      check buff.cell(5, 0).ch.toUTF8 == "5"
      check buff.cell(6, 0).ch.toUTF8 == "6"
      check buff.cell(7, 0).ch.toUTF8 == "7"
      check buff.cell(8, 0).ch.toUTF8 == "8"
      check buff.cell(9, 0).ch.toUTF8 == "9"

      check buff.cell(10, 0).ch == TRune(0)
      check buff.cell(0, 1).ch == TRune(0)
      check buff.cell(1, 1).ch == TRune(0)

    proc imitateKeyPresses(textArea: PTextArea, input: string) =
      var i = 0
      let str = initString(input)
      while i < str.len:
        let ch = str.at(i)
        if ch == "\t":
          textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyTab))
        elif ch == "!":
          textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
        elif ch == " ":
          textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeySpace))
        else:
          textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: str.runeAt(i))) 
        inc i


    test "pressing enter":
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("0", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("1", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("2", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("3", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnter))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("4", 0)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("5", 0)))
      check textArea.lines.len == 3
      check textArea.lines[0] == "01"
      check textArea.lines[1] == "23"
      check textArea.lines[2] == "45"
      check textArea.text == "01\n23\n45"

    test "drawing newLines":
      textArea.showCursor = true
      textArea.imitateKeyPresses("01!23!45")
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == "1"

      check buff.cell(0, 1).ch.toUTF8 == "2"
      check buff.cell(1, 1).ch.toUTF8 == "3"

      check buff.cell(0, 2).ch.toUTF8 == "4"
      check buff.cell(1, 2).ch.toUTF8 == "5"

      #cursor
      check buff.cell(2, 2).bg == ColorRed

    test "drawing cursor on a multirow text. The cursor can be highlighted only in the current row and column!":
      textArea.showCursor = true
      textArea.imitateKeyPresses("02!23!45")
      textArea.cursorPos.x = 1
      check textArea.cursorPos.y == 2
      let buff = textArea.draw()
      check buff.cell(0, 0).bg == ColorBlue
      check buff.cell(1, 0).bg == ColorBlue
      check buff.cell(0, 1).bg == ColorBlue
      check buff.cell(1, 1).bg == ColorBlue
      check buff.cell(0, 2).bg == ColorBlue
      check buff.cell(1, 2).bg == ColorRed

    test "drawing cursor at the end of a line":
      textArea.showCursor = true
      textArea.imitateKeyPresses("02!23!45")
      textArea.cursorPos = (2, 1)
      let buff = textArea.draw()
      check buff.cell(0, 0).bg == ColorBlue
      check buff.cell(1, 0).bg == ColorBlue
      check buff.cell(0, 1).bg == ColorBlue
      check buff.cell(1, 1).bg == ColorBlue
      check buff.cell(2, 1).bg == ColorRed
      check buff.cell(0, 2).bg == ColorBlue
      check buff.cell(1, 2).bg == ColorBlue

    test "drawing cursor in the last line at the middle of the text":
      textArea.showCursor = true
      textArea.imitateKeyPresses("012!345!678")
      textArea.cursorPos = (1, 2)
      let buff = textArea.draw()
      check buff.cell(0, 0).bg == ColorBlue
      check buff.cell(1, 0).bg == ColorBlue
      check buff.cell(2, 0).bg == ColorBlue
      check buff.cell(0, 1).bg == ColorBlue
      check buff.cell(1, 1).bg == ColorBlue
      check buff.cell(2, 1).bg == ColorBlue
      check buff.cell(0, 2).bg == ColorBlue
      check buff.cell(1, 2).bg == ColorRed
      check buff.cell(2, 2).bg == ColorBlue
      

    test "pressing space":
      textArea.imitateKeyPresses("0 1  2   3")
      check textArea.cursorPos.x == "0 1  2   3".len
      check textArea.text == "0 1  2   3"
      check textArea.lines[0] == "0 1  2   3"

    test "drawing tab":
      textArea.showCursor = true
      textArea.imitateKeyPresses("0\t123")
      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(1, 0).ch.toUTF8 == " "
      check buff.cell(2, 0).ch.toUTF8 == " "
      check buff.cell(3, 0).ch.toUTF8 == " "
      check buff.cell(4, 0).ch.toUTF8 == " "
      check buff.cell(5, 0).ch.toUTF8 == "1"
      check buff.cell(6, 0).ch.toUTF8 == "2"
      check buff.cell(7, 0).ch.toUTF8 == "3"

      #cursor
      check buff.cell(8, 0).bg == ColorRed
  
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

    test "selecting forward in the second row":
      textArea.imitateKeyPresses("012!345")
      textArea.cursorPos.x = 0

      check textArea.selectRegionStart == (-1, -1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.selectRegionStart.y == 1
      check textArea.cursorPos.x == 1
      check textArea.cursorPos.y == 1

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.selectRegionStart.y == 1
      check textArea.cursorPos.x == 2
      check textArea.cursorPos.y == 1

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.selectRegionStart.y == 1
      check textArea.cursorPos.x == 3
      check textArea.cursorPos.y == 1

    test "selecting in a multiline text":
      textArea.imitateKeyPresses("012!345!678")
      textArea.cursorPos.x = 0

      check textArea.cursorPos.y == 2
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 1
      check textArea.cursorPos.y == 2

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 2
      check textArea.cursorPos.y == 2

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart.x == 0
      check textArea.cursorPos.x == 3
      check textArea.cursorPos.y == 2

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

    test "selected range are highlighted in a multiline text":
      textArea.imitateKeyPresses("0123!4567!8901")
      textArea.cursorPos.x = 0
      check textArea.cursorPos.y == 2
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight, keyModifier: TKeyModifier(shift : true)))

      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      let defaultColor = buff.cell(0, 0).bg

      check buff.cell(0, 2).ch.toUTF8 == "8"
      check buff.cell(0, 2).bg == defaultColor
      check buff.cell(1, 2).ch.toUTF8 == "9"
      check buff.cell(1, 2).bg != defaultColor
      check buff.cell(2, 2).ch.toUTF8 == "0"
      check buff.cell(2, 2).bg != defaultColor
      check buff.cell(3, 2).ch.toUTF8 == "1"
      check buff.cell(3, 2).bg == defaultColor

      check buff.cell(0, 1).ch.toUTF8 == "4"
      check buff.cell(0, 1).bg == defaultColor
      check buff.cell(1, 1).ch.toUTF8 == "5"
      check buff.cell(1, 1).bg == defaultColor
      check buff.cell(2, 1).ch.toUTF8 == "6"
      check buff.cell(2, 1).bg == defaultColor
      check buff.cell(3, 1).ch.toUTF8 == "7"
      check buff.cell(4, 1).bg == defaultColor

      check buff.cell(0, 0).ch.toUTF8 == "0"
      check buff.cell(0, 0).bg == defaultColor
      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(1, 0).bg == defaultColor
      check buff.cell(2, 0).ch.toUTF8 == "2"
      check buff.cell(2, 0).bg == defaultColor
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(3, 0).bg == defaultColor

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

    test "Clicking on empty textarea":
      textArea.text = ""
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 1, localMouseY: 1, local: true))
      check textArea.cursorPos.x == 0
      check textArea.cursorPos.y == 0

    test "Clicking on one-line textarea":
      textArea.text = "asd"
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 1, localMouseY: 1, local: true))
      check textArea.cursorPos.x == 1
      check textArea.cursorPos.y == 0
      
    test "Changing cursor position with mouse in multiple rows text":
      textArea.imitateKeyPresses("01!23!45")
      
      check textArea.cursorPos.x == 2
      check textArea.cursorPos.y == 2
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 1, localMouseY: 0, local: true))
      check textArea.cursorPos.x == 1
      check textArea.cursorPos.y == 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 1, localMouseY: 1, local: true))
      check textArea.cursorPos.x == 1
      check textArea.cursorPos.y == 1
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 1, localMouseY: 2, local: true))
      check textArea.cursorPos.x == 1
      check textArea.cursorPos.y == 2
      # clicking after the end of the text
      textArea.handleEvent(PEvent(kind: TEventKind.eventMouseButtonDown, localMouseX: 5, localMouseY: 2, local: true))
      check textArea.cursorPos.x == 2
      check textArea.cursorPos.y == 2

    test "Pressing Home in the second row":
      textArea.imitateKeyPresses("01234!56789")
      
      check textArea.cursorPos == (5, 1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome))
      check textArea.cursorPos == (0, 1)

    test "Pressing End in the second row":
      textArea.imitateKeyPresses("01234!56789")
      
      check textArea.cursorPos == (5, 1)
      textArea.cursorPos.x = 0
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd))
      check textArea.cursorPos == (5, 1)

    test "Moving cursor up":
      textArea.imitateKeyPresses("012!345!678")
      textArea.cursorPos = (1, 2)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check textArea.cursorPos == (1, 1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check textArea.cursorPos == (1, 0)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check textArea.cursorPos == (1, 0)

    test "Moving cursor down":
      textArea.imitateKeyPresses("012!345!678")
      textArea.cursorPos = (1, 0)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check textArea.cursorPos == (1, 1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check textArea.cursorPos == (1, 2)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check textArea.cursorPos == (1, 2)

    test "shift+down":
      textArea.imitateKeyPresses("012!345!678!901")
      textArea.cursorPos = (1, 0)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == (1, 0)
      check textArea.cursorPos == (1, 1)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == (1, 0)
      check textArea.cursorPos == (1, 2)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check textArea.selectRegionStart == (-1, -1)
      check textArea.cursorPos == (1, 3)


    test "shift+up":
      textArea.imitateKeyPresses("012!345!678!901")
      textArea.cursorPos = (1, 3)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == (1, 3)
      check textArea.cursorPos == (1, 2)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp, keyModifier: TKeyModifier(shift : true)))
      check textArea.selectRegionStart == (1, 3)
      check textArea.cursorPos == (1, 1)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check textArea.selectRegionStart == (-1, -1)
      check textArea.cursorPos == (1, 0)

    test "moving cursor up to a shorter line than we are in":
      textArea.imitateKeyPresses("01!3456")
      textArea.cursorPos = (3, 1)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowUp))
      check textArea.cursorPos == (2, 0)

    test "moving cursor down to a shorter line than we are in":
      textArea.imitateKeyPresses("0134!56")
      textArea.cursorPos = (3, 0)

      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown))
      check textArea.cursorPos == (2, 1)

    test "multiline selection drawing":
      textArea.imitateKeyPresses("0123!45")
      textArea.cursorPos = (2, 0)
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowDown, keyModifier: TKeyModifier(shift : true)))

      let buff = textArea.draw()
      check buff.cell(0, 0).ch.toUTF8 == "0"
      let defaultColor = buff.cell(0, 0).bg

      check buff.cell(1, 0).ch.toUTF8 == "1"
      check buff.cell(1, 0).bg == defaultColor

      check buff.cell(2, 0).ch.toUTF8 == "2"
      check buff.cell(2, 0).bg != defaultColor
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(3, 0).bg != defaultColor
      check buff.cell(3, 0).ch.toUTF8 == "3"
      check buff.cell(3, 0).bg != defaultColor

      check buff.cell(0, 1).ch.toUTF8 == "4"
      check buff.cell(0, 1).bg != defaultColor
      check buff.cell(1, 1).ch.toUTF8 == "5"
      check buff.cell(1, 1).bg != defaultColor

    test "selecting words by double click on the middle word":
      textArea.imitateKeyPresses("0á2 4á6 8á0")
      textArea.handleEvent(newDoubleClickEvent(5, 0))
      check textArea.cursorPos == (7, 0)
      check textArea.selectRegionStart == (4, 0)

    test "selecting words by double click on the first word":
      textArea.imitateKeyPresses("0á2 4á6 8á0")
      textArea.handleEvent(newDoubleClickEvent(1, 0))
      check textArea.cursorPos == (3, 0)
      check textArea.selectRegionStart == (0, 0)

    test "selecting words by double click on the last word":
      textArea.imitateKeyPresses("0á2 4á6 8á0")
      textArea.handleEvent(newDoubleClickEvent(9, 0))
      check textArea.cursorPos == (11, 0)
      check textArea.selectRegionStart == (8, 0)
      
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

    test "clicking clear any selection":
      textArea.imitateKeyPresses("0á2 4á6 8á0")
      textArea.cursorPos = (3, 0)
      textArea.selectRegionStart = (0, 0)
      textArea.handleEvent(newLocalMouseDownEvent(9, 0))
      check textArea.selectRegionStart == (-1, -1)

    test "double clicking after the last word":
      textArea.imitateKeyPresses("0á2")
      textArea.handleEvent(newDoubleClickEvent(5, 7))
      check textArea.cursorPos == (3, 0)
      check textArea.selectRegionStart == (0, 0)

    test "Type, step left, delete, type":
      textArea.imitateKeyPresses("a")
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      textArea.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      textArea.imitateKeyPresses("a")

    test "type on selected text":
      discard

    test "delete on selected text":
      discard

    test "backspace on selected text":
      discard

    test "enter on selected text":
      discard

    test "space on selected text":
      discard