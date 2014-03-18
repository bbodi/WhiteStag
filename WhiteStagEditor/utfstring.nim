import unicode

type
  UTFString* = object
    chars: seq[TRune]

const
  NewLineRune = TRune(0x0A)
  TabRune* = TRune(0x0009)

proc initFromString(self: var UTFString, str: string) =
  self.chars = @[]
  var pos = 0
  var ch: TRune
  var prevRune: TRune
  while pos < str.len:
    fastRuneAt(str, pos, ch , true)
    if prevRune == TRune(0x0D) and ch == TRune(0x0A):
      self.chars[high(self.chars)] = TRune(NewLineRune)
    else:
      self.chars.add(ch)
    prevRune = ch


proc initString*(str: string): UTFString =
  result.initFromString(str)  

proc charFromRune(rune: TRune): string =
  if rune == TRune(NewLineRune):
    result = "\n"
  else:
    result = rune.toUTF8

proc strFromRunes(self: UTFString): string =
  result = ""
  for ch in self.chars:
    result &= charFromRune(ch)  

proc runeAt*(self: UTFString, i: int): TRune = self.chars[i]

proc at*(self: UTFString, i: int): string = 
  charFromRune(self.chars[i])

proc len*(self: UTFString): int = self.chars.len

proc set*(self: var UTFString, i: int, ch: TRune) =
  self.chars[i] = ch

proc set*(self: var UTFString, i: int, ch: string) =
  self.set(i, ch.runeAt(0))

proc set*(self: var UTFString, str: string) =
  self.initFromString(str)

proc `==`*(self: UTFString, str: string): bool = 
  self.strFromRunes() == str

proc `&`*(str: string, utfstr: UTFString): string =
  return str & utfstr.strFromRunes()

proc `&=`*(self: var string, utfstr: UTFString) =
  self &= utfstr.strFromRunes()

proc insert*(self: var UTFString, ch: TRune, index: int) =
  self.chars.insert(ch, index)

proc append*(self: var UTFString, ch: TRune) =
  self.chars.add(ch)

proc remove*(self: var UTFString, index: int) =
  self.chars.delete(index)

proc `$`*(self: UTFString): string =
  self.strFromRunes()

when isMainModule:
  import unittest

  suite "UTFString testsuite":
    setup:
      discard

    test "UTF character handling":
      let str = initString("éáőúűóü")
      check str.len == 7
      check str.chars.len == 7

    test "modifying character":
      var str = initString("éáőúűóü")
      str.set(1, "X")
      check str == "éXőúűóü"

    test "equality":
      check initString("test") == "test"
      check initString("éáőúűóü") == "éáőúűóü"
      check initString("é á\nő\tú") == "é á\nő\tú"

    test "spaces":
      var str = initString("é á ő")
      check str.len == 5
      check str.runeAt(1).isWhiteSpace
      check str.runeAt(3).isWhiteSpace
      check str.at(1) == " "
      check str.at(3) == " "

    test "newlines":
      var str = initString("é\ná\nő")
      check str.len == 5
      check str.runeAt(1).isWhiteSpace
      check str.runeAt(3).isWhiteSpace
      check str.at(1) == "\n"
      check str.at(3) == "\n"

    test "tabs":
      var str = initString("é\tá\tő")
      check str.len == 5
      check str.runeAt(1).isWhiteSpace
      check str.runeAt(3).isWhiteSpace
      check str.at(1) == "\t"
      check str.at(3) == "\t"

    test "adding it to string":
      check (("asd" & initString("éáő")) == "asdéáő")
      var str = "asd"
      str &= initString("éáő")
      check str == "asdéáő"

    test "inserting":
      var str = initString("éáő")
      str.insert("X".runeAt(0), 1)
      check str == "éXáő"

    test "remove":
      var str = initString("éáő")
      str.remove(1)
      check str == "éő"