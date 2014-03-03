
type
  TPixel* = distinct int

proc `==`*(x: TPixel, y: TPixel): bool {.borrow.}
proc `+`*(x: TPixel, y: TPixel): TPixel {.borrow.}
proc `-`*(x: TPixel, y: TPixel): TPixel {.borrow.}

proc `*`*(x: TPixel, y: int): TPixel {.borrow.}
proc `div`*(x: TPixel, y: TPixel): int {.borrow.}

proc `<`*(x: TPixel, y: int): bool {.borrow.}

