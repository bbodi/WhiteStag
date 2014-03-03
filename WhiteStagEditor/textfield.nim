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
  PTextField* = ref TTextField
  TTextField* = object of TView
    text*: string
    cursorPos: int
    showCursor: bool
    

method writeData*(self: PTextField, stream: PStream) = 
  let copy = self.text
  stream.write(cast[int32](copy))
  
method readData*(self: PTextField, stream: PStream) = 
  let strPtr = cast[string](stream.readInt32())
  self.text = strPtr

proc handleMouse(self: PTextField, event: PEvent) =
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

proc handleKey*(self: PTextField, event: PEvent) =
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
  else:
    return
  self.modified()
  event.setProcessed()

    
method name*(self: PTextField): string = "TextField"

method handleEvent*(self: PTextField, event: PEvent) = 
  case event.kind:
  of TEventKind.eventMouseButtonDown:
    discard
  of TEventKind.eventKey:
    if self.isCurrentView:
      self.handleKey(event)
  of TEventKind.eventTick:
    self.showCursor = not self.showCursor
    self.modified()
  else:
    discard

proc drawCursor(self: PTextField) = 
  if self.showCursor:
    self.buff.setCell(self.cursorPos, 0, bg = ColorRed)
  else:
    self.buff.setCell(self.cursorPos, 0, bg = TextPanelColor.color(self.isFocused))

method draw*(self: PTextField): TDrawBuffer = 
  self.buff.setCells(0, 0, self.w, self.h, ch="", bg = TextPanelColor.color(self.isFocused))
  self.buff.writeText(0, 0, self.text, fg = TextPanelTextColor.color(self.isFocused))
  if self.isCurrentView:
    self.drawCursor()
  return self.buff

proc createTextField*(w: int): PTextField = 
  result = new(TTextField)
  result.setWidthHeight(w, 1)
  result.text = ""


when isMainModule:
  import unittest

  suite "TextField Test Suite":
    setup:
      let field: PTextField = createTextField(10)
      field.text = "tést"
      setCurrentView(field)
      
    test "inheritance":
      let view: PView = createTextField(10)
      check "TextField" == view.name
      discard view.draw()

    test "backspace":
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check field.text == "ést"
      check field.cursorPos == 0

    test "backspace 2":
      field.cursorPos = 2
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check field.text == "tst"
      check field.cursorPos == 1

    test "backspace on first char":
      field.cursorPos = 0
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyBackspace))
      check field.text == "tést"
      check field.cursorPos == 0

    test "del":
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check field.text == "tst"
      check field.cursorPos == 1

    test "del on last char":
      field.cursorPos = 3
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyDelete))
      check field.text == "tés"
      check field.cursorPos == 2

    test "left":
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check field.text == "tést"
      check field.cursorPos == 0

    test "left on first char":
      field.cursorPos = 0
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowLeft))
      check field.text == "tést"
      check field.cursorPos == 0

    test "right":
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check field.text == "tést"
      check field.cursorPos == 2

    test "right to the last char":
      field.cursorPos = 3
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check field.text == "tést"
      check field.cursorPos == 4

    test "right on last char":
      field.cursorPos = 4
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyArrowRight))
      check field.text == "tést"
      check field.cursorPos == 4

    test "home":
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyHome))
      check field.text == "tést"
      check field.cursorPos == 0

    test "end":
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyEnd))
      check field.text == "tést"
      check field.cursorPos == 4
      
    test "write at the end":
      field.text = ""
      field.cursorPos = 0
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("á", 0)))
      check field.text == "á"
      check field.cursorPos == 1

    test "write at the end 2":
      field.text = "á"
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("á", 0)))
      check field.text == "áá"
      check field.cursorPos == 2

    test "insert a char":
      field.text = "áá"
      field.cursorPos = 1
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("b", 0)))
      check field.text == "ábá"
      check field.cursorPos == 2

    test "insert at head":
      field.text = "áá"
      field.cursorPos = 0
      field.handleEvent(PEvent(kind: TEventKind.eventKey, key: TKey.KeyNormal, unicode: runeAt("b", 0)))
      check field.text == "báá"
      check field.cursorPos == 1

    type 
      TTestData = object
        str: string

    test "writeData":
      field.text = "árvíztűrő fúrógép"
      var data: TTestData
      data.str = "123"
      field.groupWriteDataTo(data)
      check(data.str  == "árvíztűrő fúrógép")

    test "readData":
      var data: TTestData
      data.str = "árvíztűrő fúrógép"
      field.groupReadDataFrom(data)
      check(field.text == "árvíztűrő fúrógép")

    test "writeReadData":
      var data: TTestData
      field.text = "árvíztűrő fúrógép"
      field.groupWriteDataTo(data)
      check(data.str  == "árvíztűrő fúrógép")
      field.text = ""
      field.groupReadDataFrom(data)
      check(field.text == "árvíztűrő fúrógép")