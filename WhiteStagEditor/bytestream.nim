import streams

proc newEIO(msg: string): ref EIO =
  new(result)
  result.msg = msg

type
  PByteStream* = ref TByteStream ## a stream that encapsulates a string
  TByteStream* = object of TStream
    data*: cstring
    pos: int
    len: int
    
proc ssAtEnd(s: PStream): bool = 
  var s = PByteStream(s)
  return s.pos >= s.len
    
proc ssSetPosition(s: PStream, pos: int) = 
  var s = PByteStream(s)
  s.pos = clamp(pos, 0, s.len)

proc ssGetPosition(s: PStream): int =
  var s = PByteStream(s)
  return s.pos

proc ssReadData(s: PStream, buffer: pointer, bufLen: int): int =
  var s = PByteStream(s)
  result = min(bufLen, s.len - s.pos)
  if result > 0: 
    copyMem(buffer, addr(s.data[s.pos]), result)
    inc(s.pos, result)

proc ssWriteData(s: PStream, buffer: pointer, bufLen: int) = 
  var s = PByteStream(s)
  if bufLen <= 0: 
    return
  if s.pos + bufLen > s.len:
    raise newEIO("buffer overflow! " & $(s.pos + bufLen) & " >= " & $s.len)
  copyMem(addr(s.data[s.pos]), buffer, bufLen)
  inc(s.pos, bufLen)

proc ssClose(s: PStream) =
  discard

proc newByteStream*[T](data: var T): PByteStream = 
  new(result)
  result.data = cast[cstring](addr data)
  result.len = sizeof(T)
  result.pos = 0
  result.closeImpl = ssClose
  result.atEndImpl = ssAtEnd
  result.setPositionImpl = ssSetPosition
  result.getPositionImpl = ssGetPosition
  result.readDataImpl = ssReadData
  result.writeDataImpl = ssWriteData