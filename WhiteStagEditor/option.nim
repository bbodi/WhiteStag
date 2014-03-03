
type
  TOption*[T] = object
    case FIsSome: bool
    of false: nil
    of true: FData: T

proc none*[T](): TOption[T] = TOption[T](FIsSome: false)
proc some*[T](value: T): TOption[T] = TOption[T](FIsSome: true, FData: value)

proc isSome*[T](self: TOption[T]): bool = self.FIsSome
proc isNone*[T](self: TOption[T]): bool = not self.FIsSome

proc expect*[T](self: TOption[T], msg: string): T = 
  if self.isNone: raise newException(EInvalidField, msg)
  result = self.FData

proc ifSome*[T](self: TOption[T], task: proc(data: T)) =
  if self.isSome:
    task(self.FData)

proc data*[T](self: TOption[T]): T = 
  return self.expect("get() was called on None")

proc set*[T](self: var TOption[T], data: T) = 
  reset(self)
  self.FIsSome = true
  self.FData = data

proc withData*[T](self: var TOption[T], task: proc(data: var T)) =
  if self.isSome:
    task(self.FData)


proc unwrapOr*[T](self: TOption[T], def: T): T = 
  if self.isNone: def else: self.FData

proc equals*[T](self: TOption[T], rhs: T): bool = 
  if self.isNone: false else: self.FData == rhs

when isMainModule:
  import unittest

  test "TOption":
    var a = none[string]()
    check a.isNone
    check (not a.isSome)
    # the unittest.expect doesn't work currently O-O It doesn't allow to discard the function call
    check "default" == a.unwrapOr("default")
    try:
      discard a.expect("must exist!")
    except EInvalidField:
      check(true)
    except:
      check(false)
      
    a = some("asd")
    check (not a.isNone)
    check (a.isSome)
    check ("asd" == a.expect("must exist!"))
    check "asd" == a.unwrapOr("default")

  test "isSome with do block":
    var testString = ""
    some("expected").ifSome() do (data: string):
      testString = data
    check "expected" == testString

  test "set":
    var opt: TOption[string]
    check opt.isNone
    opt.set("asd")
    check opt.isSome
    check "asd" == opt.data

  test "withData can modify inner value":
    var opt: TOption[seq[string]]
    var arr:seq[string] = @[]
    opt.set(arr)
    check opt.isSome
    opt.withData() do (data: var seq[string]):
      data = @[]
      data.add("asd")

    check 1 == opt.data.len
    check "asd" == opt.data[0]

  test "equals":
    check some[string]("a").equals("a")
    check false == some[string]("b").equals("a")
    check false == none[string]().equals("a")

