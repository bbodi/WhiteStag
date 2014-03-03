
import pixel

type
  TRegion* = object
    pX, pY, pX2, pY2: int

  TPixelRect* = tuple[x, y, w, h: TPixel]
  TPoint* = tuple[x, y : int]

proc rect*(x, y, pX2, pY2: int): TRegion = TRegion(pX: x, pY: y, pX2: pX2, pY2: pY2)

proc grow*(rect: TRegion, x, y: int): TRegion =
  rect(rect.pX, rect.pY, rect.pX2+x, rect.pY2+y)

proc move*(rect: TRegion, x, y: int): TRegion =
  rect(rect.pX+x, rect.pY+y, rect.pX2+x, rect.pY2+y)

proc `x`*(rect: TRegion): int = rect.pX
proc `y`*(rect: TRegion): int = rect.pY

proc `x2`*(rect: TRegion): int = rect.pX2
proc `y2`*(rect: TRegion): int = rect.pY2

proc `w`*(rect: TRegion): int = rect.pX2 - rect.pX
proc `h`*(rect: TRegion): int = rect.pY2 - rect.pY

proc `w=`*(rect: var TRegion, v: int) = rect.pX2 = rect.pX + v
proc `h=`*(rect: var TRegion, v: int) = rect.pY2 = rect.pY + v

proc moveTo*(rect: TRegion, x, y: int): TRegion =
  let w = rect.w
  let h = rect.h
  rect(x, y, x+w, y+h)

proc setX*(self: var TRegion, x: int) = 
  self.pX = x

proc setY*(self: var TRegion, y: int) = 
  self.pY = y

proc setX2*(self: var TRegion, x2: int) = 
  self.pX2 = x2

proc setY2*(self: var TRegion, y2: int) = 
  self.pY2 = y2

proc incrX*(self: var TRegion, delta: int) =
  self.pX += delta

proc incrX2*(self: var TRegion, delta: int) =
  self.pX2 += delta

proc incrY*(self: var TRegion, delta: int) =
  self.pY += delta

proc incrY2*(self: var TRegion, delta: int) =
  self.pY2 += delta

proc rectXYWH*(x, y, w, h: int): TRegion = rect(x, y, x+w, y+h)

proc contains*(rect: TRegion, point: TPoint): bool {.noSideEffect.} =
  let containsX = point.x >= rect.pX and point.x < rect.pX2
  let containsY = point.y >= rect.pY and point.y < rect.pY2
  result = containsX and containsY

when isMainModule:
  import unittest

  test "rect grow":
    check(rectXYWH(1, 2, 3, 4).grow(5, 6) == rectXYWH(1, 2, 8, 10))

  test "rect move":
    check(rectXYWH(1, 2, 3, 4).move(5, 6) == rectXYWH(6, 8, 3, 4))

  test "rect moveTo":
    check(rectXYWH(1, 2, 3, 4).moveTo(5, 6) == rect(5, 6, 8, 10))
    check(rectXYWH(1, 2, 3, 4).moveTo(0, 0) == rect(0, 0, 3, 4))
    check(rectXYWH(1, 2, 3, 4).moveTo(5, 6) == rectXYWH(5, 6, 3, 4))
    check(rectXYWH(1, 2, 3, 4).moveTo(0, 0) == rectXYWH(0, 0, 3, 4))

  test "rect contains":
    let r = rectXYWH(1, 2, 5, 6)
    check ((1, 2) in r)
    check ((3, 3) in r)
    check ((5, 3) in r)
    check ((3, 7) in r)
    check ((5, 7) in r)
    check ((1, 1) notin r)
    check ((7, 7) notin r)
    check ((6, 8) notin r)
    let r2 = rectXYWH(0, 0, 10, 1)
    check ((1, 1) notin r2)
    check ((1, 0) in r2)
    check ((1, 2) notin r2)
    
  