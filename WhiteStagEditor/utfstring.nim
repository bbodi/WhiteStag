import unicode

type
  PUTFString* = ref UTFString
  UTFString* = object
    chars: seq[TRune]

const
  NewLineRune* = TRune(0x0A)
  TabRune* = TRune(0x0009)

proc initFromString(self: PUTFString, str: string) =
  self.chars = @[]
  var pos = 0
  var ch: TRune
  var prevRune: TRune
  while pos < str.len:
    fastRuneAt(str, pos, ch , true)
    if prevRune == TRune(0x0D) and ch == TRune(0x0A):
      self.chars[self.chars.len-1] = NewLineRune
    else:
      self.chars.add(ch)
    prevRune = ch


proc newString*(str: string): PUTFString =
  result = new(UTFString)
  result.initFromString(str)

proc utf*(str: string): PUTFString =
  result = newString(str)

proc newString*(str: PUTFString): PUTFString =
  result = new(UTFString)
  result.chars = str.chars

proc charFromRune(rune: TRune): string =
  if rune == NewLineRune:
    result = "\n"
  else:
    result = rune.toUTF8

proc strFromRunes(self: ref UTFString): string =
  result = ""
  for ch in self.chars:
    result &= charFromRune(ch)  

proc runeAt*(self: ref UTFString, i: int): TRune = self.chars[i]

proc at*(self: ref UTFString, i: int): string = 
  charFromRune(self.chars[i])

proc len*(self: ref UTFString): int = self.chars.len

proc set*(self: ref UTFString, i: int, ch: TRune) =
  self.chars[i] = ch

proc set*(self: ref UTFString, i: int, ch: string) =
  self.set(i, ch.runeAt(0))

proc set*(self: ref UTFString, str: string) =
  self.initFromString(str)

proc `==`*(self: ref UTFString, str: string): bool = 
  if str == nil and cast[pointer](self) == nil:
    return true
  return self.strFromRunes() == str

proc `==`*(self: ref UTFString, other: ref UTFString): bool = 
  if cast[pointer](other) == nil and cast[pointer](self) == nil:
    return true
  return self.chars == other.chars


proc append*(self: ref UTFString, other: ref UTFString) =
  self.chars.add(other.chars)
    
proc substring*(self: ref UTFString, fromIndex: int, toIndex : int = -1): ref UTFString =
  var toIndexMod = toIndex
  if toIndex == -1 or toIndex > self.len:
    toIndexMod = self.len
  if toIndexMod <= fromIndex:
    return utf""
  result = new UTFString
  result.chars = self.chars[fromIndex .. <toIndexMod]

proc `&`*(str: string, utfstr: ref UTFString): string =
  return str & utfstr.strFromRunes()

proc `&`*(lhs: ref UTFString, str: string):ref UTFString =
  lhs.append(newString(str))
  return lhs

proc `&=`*(self: var string, utfstr: ref UTFString) =
  self &= utfstr.strFromRunes()

proc insert*(self: ref UTFString, ch: TRune, index: int) =
  self.chars.insert(ch, index)

proc append*(self: ref UTFString, ch: TRune) =
  self.chars.add(ch)

proc removeChar*(self: ref UTFString, index: int) =
  self.chars.delete(index)

proc remove*(self: ref UTFString, fromIndex: int, toIndex : int = -1) =
  var toIndexMod = toIndex
  if toIndex == -1:
    toIndexMod = self.len
  if toIndexMod <= fromIndex:
    return
  for i in fromIndex .. <toIndexMod:
    self.chars.delete(fromIndex)

proc `$`*(self: ref UTFString): string =
  self.strFromRunes()

when isMainModule:
  import unittest

  suite "UTFString testsuite":
    setup:
      discard

    test "UTF character handling":
      let str = newString("éáőúűóü")
      check str.len == 7
      check str.chars.len == 7

    test "modifying character":
      var str = newString("éáőúűóü")
      str.set(1, "X")
      check str == "éXőúűóü"

    test "equality":
      check newString("test") == "test"
      check newString("éáőúűóü") == "éáőúűóü"
      check newString("é á\nő\tú") == "é á\nő\tú"
      var n: PUTFString
      check n.isNil

    test "spaces":
      var str = newString("é á ő")
      check str.len == 5
      check str.runeAt(1).isWhiteSpace
      check str.runeAt(3).isWhiteSpace
      check str.at(1) == " "
      check str.at(3) == " "

    test "newlines":
      var str = newString("é\ná\nő")
      check str.len == 5
      check str.runeAt(1).isWhiteSpace
      check str.runeAt(3).isWhiteSpace
      check str.at(1) == "\n"
      check str.at(3) == "\n"

    test "tabs":
      var str = newString("é\tá\tő")
      check str.len == 5
      check str.runeAt(1).isWhiteSpace
      check str.runeAt(3).isWhiteSpace
      check str.at(1) == "\t"
      check str.at(3) == "\t"

    test "adding it to string":
      check (("asd" & newString("éáő")) == "asdéáő")
      var str = "asd"
      str &= newString("éáő")
      check str == "asdéáő"

    test "inserting":
      var str = newString("éáő")
      str.insert("X".runeAt(0), 1)
      check str == "éXáő"

    test "removeChar":
      var str = newString("éáő")
      str.removeChar(1)
      check str == "éő"

    test "copy":
      var str = newString("éáő")
      let str2 = newString(str)
      str.removeChar(1)
      check str == "éő"
      check str2 == "éáő"

    test "append utf":
      var str = newString("éáő")
      let str2 = newString("őúű")
      str.append(str2)
      check str.len == 6
      check str == "éáőőúű"
      check str2 == "őúű"

    test "remove":
      proc createThenRemove(text: string, fromIndex: int, toIndex: int = -1): ref UTFString =
        result = newString(text)
        result.remove(fromIndex, toIndex)
      check createThenRemove("éáőúűóü", 1) == "é"
      check createThenRemove("éáőúűóü", 2) == "éá"
      check createThenRemove("éáőúűóü", 0) == ""
      check createThenRemove("éáőúűóü", 6) == "éáőúűó"
      check createThenRemove("éáőúűóü", 7) == "éáőúűóü"

      check createThenRemove("éáőúűóü", 3, 3) == "éáőúűóü"
      check createThenRemove("éáőúűóü", 3, 4) == "éáőűóü"
      check createThenRemove("éáőúűóü", 3, 7) == "éáő" 
      check createThenRemove("éáőúűóü", 7, 3) == "éáőúűóü"
      check createThenRemove("0123456789", 2, 6) == "016789"

    test "substring":
      var str = newString("éáő abcd def")
      check str.substring(0) == str
      check str.substring(4) == "abcd def"
      check str.substring(12) == ""
      check str.substring(0, 100) == "éáő abcd def"
      check newString("1").substring(0, 30) == "1"