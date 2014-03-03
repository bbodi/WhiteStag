import color
import option
import unicode
import rect

type
  PCell = ref TCell
  TCell = tuple
    fg, bg: TColor
    ch: TRune

  TDrawBuffer* = object
    w*, h*: int
    cells: seq[PCell]

const NilCel*: TCell = (fg: ColorNone, bg: ColorNone, ch: TRune(0))

proc createDrawBuffer*(w, h: int): TDrawBuffer =
  doAssert(w >= 0 and h >= 0, $w & ", " & $h)
  var cells: seq[PCell]
  newSeq(cells, w*h)
  result = TDrawBuffer(w: w, h: h, cells: cells)

proc createDrawBuffer*(rect: TRegion): TDrawBuffer =
  result = createDrawBuffer(rect.w, rect.h)

proc outOfRange*(self: TDrawBuffer, x, y :int): bool =
  x >= self.w or y >= self.h or y < 0 or x < 0

proc clearCell*(self: var TDrawBuffer, x, y :int) = 
  if self.outOfRange(x, y):
    return
  let i = y * self.w + x
  self.cells[i] = nil

proc setCell*(self: var TDrawBuffer, x, y :int, 
  fg: TColor = ColorNone,
  bg: TColor = ColorNone,
  ch: string = nil) = 
  if self.outOfRange(x, y):
    return
  let i = y * self.w + x
  var cell = self.cells[i]
  if self.cells[i] == nil:
    cell = TCell.new
    self.cells[i] = cell

  if fg != ColorNone:
    cell.fg = fg
  if bg != ColorNone:
    cell.bg = bg
  if ch != nil:
    cell.ch = runeAt(ch, 0)

proc setCells*(self: var TDrawBuffer, x, y, w, h :int, 
  fg: TColor = ColorNone,
  bg: TColor = ColorNone,
  ch: string = nil) = 
  for iy in 0..h-1:
    for ix in 0..w-1:
      self.setCell(x+ix, y+iy, fg, bg, ch)

proc clearCells*(self: var TDrawBuffer, x, y, w, h :int) = 
  for iy in 0..h-1:
    for ix in 0..w-1:
      self.clearCell(x+ix, y+iy)

proc writeText*(self: var TDrawBuffer, x, y: int, text: string, 
  fg: TColor = ColorNone, bg: TColor = ColorNone) = 
  var i = 0
  for ch in runes(text):
    self.setCell(x+i, y, fg, bg, "" & $ch)
    inc i

proc cell*(self: TDrawBuffer, x, y: int): TCell = 
  let i = y * self.w + x
  return if self.cells[i] == nil: NilCel else: self.cells[i][]

proc clip*(self: var TDrawBuffer, fromX, fromY, dstW, dstH: int) = 
  var newCells: seq[PCell]
  newSeq(newCells, dstW*dstH)

  let toY = fromY + dstH  

  var dstIndex = 0
  for srcY in fromY..toY-1:
    var srcIndex = srcY * self.w + fromX
    for srcX in 0..dstW-1:
      newCells[dstIndex] = self.cells[srcIndex]
      inc srcIndex
      inc dstIndex
  self.w = dstW
  self.h = dstH
  self.cells = newCells


when isMainModule:
  import unittest

  suite "TDrawBuffer Test Suite":
    setup:
      var buff = createDrawBuffer(10, 10)

    proc checkNilCellCount(buff: TDrawBuffer, expected: int) = 
      var nilCount = 0
      for i in 0..10*10-1:
        if buff.cells[i] == nil:
          inc(nilCount)
      check expected == nilCount

    test "createDrawBuffer with negative sizes throw exception!":
      var ok = false
      try:
        discard createDrawBuffer(-1, 10)
      except:
        ok = true
      check ok

    test "createDrawBuffer with negative sizes throw exception!":
      var ok = false
      try:
        discard createDrawBuffer(10, -1)
      except:
        ok = true
      check ok

    test "setCell fg":
      buff.setCell(5, 5, fg = ColorRed)
      let cell = buff.cells[5*10+5]
      check cell[] == (ColorRed, ColorNone, TRune(0))
      checkNilCellCount(buff, 10*10-1)
      

    test "setCell bg":
      buff.setCell(5, 5, bg = ColorRed)
      let cell = buff.cells[5*10+5]
      check cell[] == (ColorNone, ColorRed, TRune(0))
      checkNilCellCount(buff, 10*10-1)

    test "setCell ch":
      buff.setCell(5, 5, ch = "a")
      let cell = buff.cells[5*10+5]
      check cell[] == (ColorNone, ColorNone, runeAt("a", 0))
      checkNilCellCount(buff, 10*10-1)

    test "setCells fg":
      buff.setCells(5, 5, 3, 3, fg = ColorRed)
      for y in 5..7:
        for x in 5..7:
          let cell = buff.cells[y*10+x]
          check cell[] == (ColorRed, ColorNone, TRune(0))
      checkNilCellCount(buff, 10*10-3*3)
      

    test "setCells bg":
      buff.setCells(5, 5, 3, 3, bg = ColorRed)
      for y in 5..7:
        for x in 5..7:
          let cell = buff.cells[y*10+x]
          check cell[] == (ColorNone, ColorRed, TRune(0))
      checkNilCellCount(buff, 10*10-3*3)

    test "setCells ch":
      buff.setCells(5, 5, 3, 3, ch = "a")
      for y in 5..7:
        for x in 5..7:
          let cell = buff.cells[y*10+x]
          check cell[] == (ColorNone, ColorNone, runeAt("a", 0))
      checkNilCellCount(buff, 10*10-3*3)

    test "writeText":
      buff.writeText(3, 3, "test", fg = ColorRed, bg = ColorBlue)
      for i, ch in "test":
        let cell = buff.cells[3*10+3+i]
        check cell[] == (ColorRed, ColorBlue, runeAt("test", i))

    test "index operator":
      buff.setCell(3, 3, fg = ColorRed, bg = ColorBlue, ch = "a")
      var cell = buff.cell(3, 3)
      check cell.fg == ColorRed
      check cell.bg == ColorBlue
      check cell.ch == runeAt("a", 0)
      cell.ch = runeAt("b", 0)
      check buff.cell(3, 3).ch == runeAt("a", 0)

    test "index operator for a nil cell":
      var cell = buff.cell(3, 3)
      check cell.fg == ColorNone
      check cell.bg == ColorNone
      check cell.ch == TRune(0)

    test "modifying cell":
      buff.setCell(5, 5, ch = "ó")
      check (buff.cell(5, 5) == (ColorNone, ColorNone, runeAt("ó", 0)))
      buff.setCell(5, 5, ch = "b")
      check (buff.cell(5, 5) == (ColorNone, ColorNone, runeAt("b", 0)))

    test "clipping":
      check buff.w == 10
      check buff.h == 10
      buff.setCell(5, 5, ch = "a")
      check buff.cell(0, 0).ch == TRune(0)
      buff.clip(5, 5, 5, 3)
      check buff.cell(0, 0).ch == "a".runeAt(0)
      check buff.w == 5
      check buff.h == 3