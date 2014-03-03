import unicode

import pixel

type
  TKey* = enum
    KeyNormal,
    KeyModifier,
    KeyF1,
    KeyF2,
    KeyF3,
    KeyF4,
    KeyF5,
    KeyF6,
    KeyF7,
    KeyF8,
    KeyF9,
    KeyF10,
    KeyF11,
    KeyF12,
    KeyInsert,
    KeyDelete,
    KeyHome,
    KeyEnd,
    KeyPgup,
    KeyPgdn,
    KeyArrowUp,
    KeyArrowDown,
    KeyArrowLeft,
    KeyArrowRight,
    KeyTab,
    KeyEnter,
    KeyCtrl,
    KeyAlt,
    KeyBackspace,
    KeySpace,
    KeyEsc

  TKeyModifier* = object
    leftAlt*, rightAlt*, alt*: bool
    leftCtrl*, rightCtrl*, ctrl*: bool
    leftShift*, rightShift*, shift*: bool
    capsLock*, numLock*: bool

  TMouseButton* = enum
    mbtnLeft,
    mbtnMiddle,
    mbtnRight

  TEventKind* = enum
    eventNothing,
    eventResize,
    eventCommand,
    eventMouseButtonDown,
    eventMouseButtonUp,
    eventMouseMove,
    eventKey,
    eventKeyRepeat,
    eventLostFocus,
    eventGetFocus,
    eventBecomeCurrentView,
    eventNotCurrentAnymore,
    eventTick,
    eventWindowResized

  PEvent* = ref TEvent

  TEvent* = object
    case kind*: TEventKind
    of eventNothing: nil
    of eventResize: nil
    of eventCommand:
      cmd*: TCmd 
      data*: pointer
      sourceView*: pointer
    of eventMouseButtonDown, eventMouseButtonUp, eventMouseMove:
      mouseX*, mouseY*: TPixel
      mouseButton*: TMouseButton
      local*: bool
      localMouseX*, localMouseY*: int
    of eventKey, eventKeyRepeat:
      ch*: char
      unicode*: TRune
      key*: TKey
      keyModifier*: TKeyModifier
    of eventLostFocus, eventGetFocus, eventNotCurrentAnymore, eventBecomeCurrentView: 
      view*: pointer
    of eventTick: nil
    of eventWindowResized:
      newWidth*, newHeight*: TPixel


  TCmd* = distinct string

const
  cmdNothing* = TCmd("system.CmdNothing")
  cmdQuit* = TCmd("system.CmdQuit")
  cmdCancel* = TCmd("system.CmdCancel")
  cmdOk* = TCmd("system.CmdOk")
  cmdTick* = TCmd("system.CmdTick")
  cmdItemSelection* = TCmd("system.view.ItemSelected")

proc none*(self: TKeyModifier): bool = 
  not self.alt and not self.ctrl and not self.shift

proc setProcessed*(self: PEvent) = 
  reset(self[])

proc dataAsString*(self: PEvent): string = cast[string](self.data)

proc isMouseButtonEvent*(self: PEvent): bool = 
  self.kind in {TEventKind.eventMouseButtonDown, TEventKind.eventMouseButtonUp}

proc isMouseEvent*(self: PEvent): bool = 
  self.kind in {TEventKind.eventMouseButtonDown, TEventKind.eventMouseButtonUp, TEventKind.eventMouseMove}

proc pressedCtrl*(self: PEvent, key: char): bool = 
  self.keyModifier.ctrl and self.ch == key

proc pressedShiftCtrl*(self: PEvent, key: char): bool = 
  self.keyModifier.ctrl and self.keyModifier.shift and self.ch == key

proc `==`*(a, b: TCmd): bool {.borrow.}


when isMainModule:
  import unittest

  test "cmd":
    check(cmdNothing != cmdQuit)
    let cmd = cmdOk
    check(cmd == cmdOk)

  test "event.setProcessed":
    let event = PEvent(kind: TEventKind.eventMouseButtonDown)
    check(event.kind == TEventKind.eventMouseButtonDown)
    event.setProcessed()
    check(event.kind == TEventKind.eventNothing)