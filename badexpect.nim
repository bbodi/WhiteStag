
type
  TOption*[T] = object
    case FIsSome: bool
    of false: nil
    of true: FData: T

  TTestObj* = object
    asd: TOption[int64]



proc expect*[T](self: TOption[T], msg: string): T = 
  if not self.FIsSome: raise newException(EInvalidField, msg)
  result = self.FData


#proc asd*[T](self: int): T = cast[T](self)

when isMainModule:
  import unittest

  test "some test":
    let opt = TOption[int](FIsSome: true, FData: 2)
    #check opt.expect("it must be exist!" & $2) == 2
    #check 3 == 3.asd[int]