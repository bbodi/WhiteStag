import pixel
import drawbuffer
import rect
import color
import font
import event
import utfstring
import renderer/genericEngine
import renderer/sdlengine

var gEngine*: ref TEngine

proc initSdlEngine*(w, h: int, fontSize: int) =
  gEngine = sdlengine.init(w, h, fontSize)