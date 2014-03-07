import streams

import pixel
import option
import rect
import event
import color
import drawbuffer
import font
import sdlengine
import bytestream

var engine*: PSdlEngine

type
  TGrowMode* = enum
    gmLeftToParentsRight
    gmRightToParentsRight
    gmTopToParentsBottom
    gmBottomToParentsBottom

  TExecutingResult* = object
    cmd*: TCmd
    data*: pointer

  PView* = ref TView
  TView* = object of TObject
    nextView, prevView: TOption[PView]
    rect: TRegion
    buff*: TDrawBuffer
    growMode*: set[TGrowMode]
    owner: TOption[PView]
    pDirty: bool
    pExecuting: bool
    hasDirtyChild: bool
    pHidden: bool
    views*: seq[PView]
    pFont: TOption[TFont]
    executingResult: TExecutingResult
    useClipping*: bool
    minWidth*, minHeight*: int
    focusedView: TOption[PView]
    bottomView, topView: TOption[PView]
    
    selectable: bool

  PViewRepresentation* = ref TViewRepresentation
  TViewRepresentation* = object
    view*: PView
    buff*: TDrawBuffer

  PViewRepresentations* = ref TViewRepresentations
  TViewRepresentations* = object
    representations*: seq[TViewRepresentation]

  PItemDrawer* = ref TItemDrawer
  TItemDrawer* = object of TObject

  PIntItemDrawer* = ref TIntItemDrawer
  TIntItemDrawer* = object of TItemDrawer

  PStringItemDrawer* = ref TStringItemDrawer
  TStringItemDrawer* = object of TItemDrawer

  PCellView* = ref TCellView
  TCellView* = object of TView

  PCellViewFactory* = ref TCellViewFactory
  TCellViewFactory* = object of TObject

const
  gmGrowAsParent* = {gmRightToParentsRight, gmBottomToParentsBottom}

method createCellView*(self: PCellViewFactory, w, h: int): PCellView = quit "to override createCellView!"
method stringify*(self: PCellViewFactory, data: pointer): string = quit "to override stringify!grow"


proc groupHandleEvent(self: PView, event: PEvent)
proc broadcast*(self: PView, event: PEvent)

method setData*[T](self: PCellView, data: T) = quit "setData to override!"

proc sourceView*(self: PEvent): PView = cast[PView](self.view)

proc isFrom*(self: PEvent, view: PView): bool = cast[PView](self.data) == view

proc sourceViewEquals*(self: PEvent, view: PView): bool = 
  if self.kind == TEventKind.eventCommand:
    cast[int](self.sourceView) == cast[int](view)
  else:
    cast[int](self.view) == cast[int](view)

proc add(self: var TViewRepresentations, view: PView, buff: TDrawBuffer) =
  self.representations.add(TViewRepresentation(view: view, buff: buff))

method itemToString*(self: PItemDrawer, data: pointer): string = "itemToString to override!"

method itemToString*(self: PStringItemDrawer, data: pointer): string = cast[string](data)

method itemToString*(self: PIntItemDrawer, data: pointer): string = $cast[int](data)

const 
  TextColor*          = (first: ColorWhite, second: ColorWhite)
  TitleColor*         = (first: ColorBlack, second: ColorPurple)
  FrameColor*        = (first: ColorLightGray, second: ColorLightGray)
  BorderColor*       = (first: ColorBlack, second: ColorPurple)
  ItemFgColor*      = (first: ColorWhite, second: ColorBlue)
  ItemBgColor*     = (first: ColorBlue, second: ColorWhite)
  SelectedItemBgColor* = (first: ColorGray, second: ColorGray)
  ComboFrameColor*       = (first: ColorGreen, second: ColorRed)
  BorderActionColor*        = (first: ColorGray, second: ColorDarkGreen)
  ButtonColor*        = (first: ColorGreen, second: ColorGray, third: ColorBlue)
  PanelColor*        = (first: ColorDarkGray, second: ColorDarkGray)
  PanelTextColor*        = (first: ColorWhite, second: ColorYellow)
  BackgroundColor*        = (first: ColorGray, second: ColorGray)

  # TextArea szöveg  szine
  TextPanelColor*        = (first: ColorBlue, second: ColorBlue)
  TextPanelTextColor*        = (first: ColorWhite, second: ColorWhite)


method writeData*(self: PView, stream: PStream) = discard

method readData*(self: PView, stream: PStream) = discard

proc groupWriteDataTo*[T](self: PView, data: var T) = 
  let stream: PStream = newByteStream(data)
  if self.views != nil:
    for view in self.views:
      view.writeData(stream)
  self.writeData(stream)

proc groupReadDataFrom*[T](self: PView, data: var T) = 
  let stream: PStream = newByteStream(data)
  if self.views != nil:
    for view in self.views:
      view.readData(stream)
  self.readData(stream)

proc x*(self: PView): int = self.rect.x
proc y*(self: PView): int = self.rect.y
proc w*(self: PView): int = self.rect.w
proc h*(self: PView): int = self.rect.h


method name*(self: PView): string = "View"

proc parentsSizeChanged(self: PView, deltaW, deltaH: int)

proc groupOnChangeSize*(self: PView, deltaW, deltaH: int) =
  self.buff = createDrawBuffer(self.rect)
  if self.views != nil:
    for view in self.views:
      view.parentsSizeChanged(deltaW, deltaH)

method onChangeSize*(self: PView, deltaW, deltaH: int) =
  self.groupOnChangeSize(deltaW, deltaH)

proc parentsSizeChanged(self: PView, deltaW, deltaH: int) =
  var changeDelta: TPoint

  if gmLeftToParentsRight in self.growMode:
    let newX = min( self.rect.x2, max(0, self.rect.x + deltaW))
    self.rect.setX(newX)

  if gmRightToParentsRight in self.growMode:
    let newX2 = max(self.rect.x, self.rect.x2 + deltaW)
    if newX2 != self.rect.x2:
      changeDelta.x = deltaW
    self.rect.setX2(newX2)

  if gmTopToParentsBottom in self.growMode:
    let newY = min(self.rect.y2, max(0, self.rect.y + deltaH))
    self.rect.setY(newY)

  if gmBottomToParentsBottom in self.growMode:
    let newY2 = max(self.rect.y, self.rect.y2 + deltaH)
    if newY2 != self.rect.y2:
      changeDelta.y = deltaH
    self.rect.setY2(newY2)

  if changeDelta.x != 0 or changeDelta.y != 0:
    self.onChangeSize(changeDelta.x, changeDelta.y)

proc setWidthHeight*(self: PView, requestedWidth, requestedHeight: int) = 
  #assert(requestedWidth >= 0 and requestedHeight >= 0, $requestedWidth & ", " & $requestedHeight)
  #if w <= 0 or h <= 0:
  #echo("WARNING: Illegal argument in view.setWidthHeight - " & self.name & ": w("& $w &"), h("& $h &")")

  let w = max(self.minWidth, requestedWidth)
  let h = max(self.minHeight, requestedHeight)
  let deltaW = w - self.rect.w
  let deltaH = h - self.rect.h
  if deltaW == 0 and deltaH == 0:
    return
  self.rect.w = w
  self.rect.h = h
  self.onChangeSize(deltaW, deltaH)

proc move*(self: PView, x, y: int) = 
  self.rect = self.rect.move(x, y)

proc moveTo*(self: PView, x, y: int) = 
  self.rect = self.rect.moveTo(x, y)

proc grow*(self: PView, w, h: int) = 
  if w != 0 or h != 0:
    self.setWidthHeight(self.w + w, self.h + h)

method handleEvent*(self: PView, event: PEvent) = quit "handleEvent to override!"

method draw*(self: PView): TDrawBuffer = quit "draw to override!"

proc createExecutingResult(cmd: TCmd): TExecutingResult =
  TExecutingResult(cmd: cmd)

proc createExecutingResultWith[T](cmd: TCmd, data: T): TExecutingResult =
  result = TExecutingResult(cmd: cmd, data: cast[pointer](data))

proc getInt(self: TExecutingResult): int = 
  cast[int](self.data)

proc getString(self: TExecutingResult): string = 
  cast[string](self.data)

proc getPtr(self: TExecutingResult): pointer = 
  return self.data

proc stopExecuting*(self: PView, cmd: TCmd) =
  doAssert(self.pExecuting, "View isn't pExecuting!")
  self.pExecuting = false
  self.executingResult = createExecutingResult(cmd)

proc stopExecutingWith*[T](self: PView, cmd: TCmd, data: T = nil) =
  doAssert(self.pExecuting, "View isn't pExecuting!")
  self.pExecuting = false
  self.executingResult = createExecutingResultWith(cmd, data)

proc isExecuting*(self: PView): bool =
  return self.pExecuting

proc dirty*(self: PView): bool =
  return self.pDirty

proc settingDirtyToFalseForTestingPurposes*(self: PView) =
  self.pDirty = false

proc `font=`*(self: PView, rhs: TOption[TFont]) =
  self.pFont = rhs

proc font*(self: PView): TFont = 
  if self.pFont.isSome or self.owner.isNone:
    return self.pFont.expect("No parent, must exist a font!")
  return self.owner.expect("").font

proc isFocused*(self: PView): bool =
  self.owner.isSome and self.owner.data.focusedView.equals(self)

proc modified*(self: PView) = 
  self.pDirty = true
  var parent = self.owner
  while parent.isSome:
    parent.data.hasDirtyChild = true
    parent = parent.data.owner

proc isHidden*(self: PView): bool = 
  self.pHidden

proc groupDraw(self: PView, viewRepresentations: var TViewRepresentations) =
  if self.isHidden:
    return
  let buff = self.draw()
  viewRepresentations.add(self, buff)
  if self.views != nil:
    for child in self.views:
      child.groupDraw(viewRepresentations)
  self.pDirty = false
  self.hasDirtyChild = false

proc hide*(self: PView) = 
  self.pHidden = true
  self.modified()

proc show*(self: PView) = 
  self.pHidden = false
  self.modified()


proc calcOffset*(self: PView): tuple[x, y: TPixel] =
  var font: TFont 
  var parentOffsetX: TPixel 
  var parentOffsetY: TPixel 

  if self.owner.isNone:
    font = self.font
  else:
    let xy = self.owner.data.calcOffset()
    parentOffsetX = xy.x
    parentOffsetY = xy.y
    font = self.owner.data.font
  let selfOffsetX = font.charWidth * self.x
  let selfOffsetY = font.charHeight * self.y
  return (parentOffsetX + selfOffsetX, parentOffsetY + selfOffsetY)

proc clippingRect*(self: PView): TPixelRect = 
  if not self.useClipping and self.owner.isSome:
    return self.owner.expect("").clippingRect
  let offset = self.calcOffset
  let font = self.font
  let w = font.charWidth * self.w
  let h = font.charHeight * self.h
  return (offset.x, offset.y, w, h)

proc drawToBackBuffer(regions: TViewRepresentations)  =
  for region in regions.representations:
    let offset = region.view.calcOffset()
    let clippingArea: TPixelRect = region.view.clippingRect
    engine.drawToBackBuffer(region.buff, offset.x, offset.y, region.view.font, clippingArea)

proc makeLocal*(self: PView, x, y: TPixel): tuple[x, y: int] =
  let offset = self.calcOffset()
  let selfX = x - offset.x
  let selfY = y - offset.y
  var localX: int
  if selfX < 0:
    localX = -1
  else:
    let fontCharWidth = self.font.charWidth
    localX = selfX div fontCharWidth

  var localY: int
  if selfY < 0:
    localY = -1
  else:
    let fontCharHeight = self.font.charHeight
    localY = selfY div fontCharHeight
  return (localX, localY)

proc clickedInMe*(self: PView, event: PEvent): bool =
  let localCoords = self.makeLocal(event.MouseX, event.MouseY)
  let mx = localCoords.x
  let my = localCoords.y
  return mx < self.w and my < self.h and mx >= 0 and my >= 0

proc insertLast(self: PView, child: PView) =
  if self.topView.isSome:
    let topView = self.topView.data
    topView.nextView = some(child)
    child.prevView = some(topView)
  self.topView = some(child)

  if self.bottomView.isNone:
    self.bottomView = some(child)

proc removeFromLinkedList(self: PView, childToDelete: PView) =
  let prevView = childToDelete.prevView
  let nextView = childToDelete.nextView
  childToDelete.prevView = none[PView]()
  childToDelete.nextView = none[PView]()
  if prevView.isSome:
    prevView.data.nextView = nextView
  if nextView.isSome:
    nextView.data.prevView = prevView
  if self.bottomView.equals(childToDelete):
    self.bottomView = nextView
  if self.topView.equals(childToDelete):
    self.topView = prevView
  if self.focusedView.equals(childToDelete):
    self.focusedView = none[PView]()

proc makeLast(self: PView, child: PView) =
  if self.views.len <= 1:
    return
  if self.bottomView.equals(child):
    self.bottomView = self.bottomView.data.nextView
    if self.bottomView.isNone and self.views.len > 0:
      self.bottomView = some(self.views[0])
  self.topView = some(child)

proc makeMeLast(self: PView) =
    if self.owner.isNone:
      return
    self.owner.data.makeLast(self)
    self.owner.data.makeMeLast()

proc clearFocusedViews*(self: PView) =
  self.focusedView.ifSome do (focusedView: PView):
    focusedView.broadcast(PEvent(kind: TEventKind.eventLostFocus, view: cast[pointer](focusedView)))

  self.focusedView = none[PView]()

  self.owner.ifSome do (parentView: PView):
     parentView.clearFocusedViews()
  

proc setChildFocused(self: PView, child: PView) =
  self.clearFocusedViews()
  self.focusedView = some(child)

proc setMyParentsFocused(self: PView) =
  self.owner.ifSome do (parent: PView):
    parent.makeMeLast()
    parent.setChildFocused(self)
    parent.setMyParentsFocused()
  
# Unit testet arra az esetre, ha már egy fókuszált elemre kerül a fókusz
proc setFocused*(self: PView) =
  self.makeMeLast()
  self.setMyParentsFocused()
  self.broadcast(PEvent(kind: TEventKind.eventGetFocus, view: cast[pointer](self)))
  

proc changeSwapFocusedViewTo(self: PView, child: PView) =
  self.focusedView.ifSome do (focusedView: PView):
    focusedView.broadcast(PEvent(kind: TEventKind.eventLostFocus, view: cast[pointer](focusedView)))
  self.broadcast(PEvent(kind: TEventKind.eventGetFocus, view: cast[pointer](child)))
  self.makeLast(child)
  self.focusedView = some(child)

proc selectNext*(self: PView, backward: bool = false) =
  if self.focusedView.isNone:
    if self.views.len == 0:
      return
    if not backward:
      echo "topView"
      self.topView.expect("views.len > 0").setFocused()
    else:
      self.bottomView.expect("views.len > 0").setFocused()
    return
  let focusedView = self.focusedView.data
  if not backward and focusedView.nextView.isNone:
    echo ("roundup with " & self.bottomView.data.name)
    self.changeSwapFocusedViewTo(self.bottomView.data)
    return
  echo ("sima with " & focusedView.nextView.data.name)
  self.changeSwapFocusedViewTo(focusedView.nextView.data)

proc addView*(self: PView, child: PView, x, y: int) = 
  if self.views == nil:
    self.views = @[]
  child.moveTo(x, y)
  self.views.add(child)
  self.insertLast(child)
  child.owner = some(self)
  child.modified()

proc calcCenterPos(parent: PView, child: PView): tuple[x, y: int] =
  result.x = (parent.w div 2) - (child.w div 2)
  result.y = (parent.h div 2) - (child.h div 2)

proc addViewAtCenter*(self: PView, child: PView, yOffset: int = 0) = 
  let center = calcCenterPos(self, child)
  addView(self, child, center.x, center.y + yOffset)

proc addViewAtCenterX*(self: PView, child: PView, y: int) = 
  let center = calcCenterPos(self, child)
  addView(self, child, center.x, y)

proc removeView*(self: PView, childToDelete: PView) = 
  let currentViewWasRemoved = self.focusedView.equals(childToDelete)
  let index = self.views.find(childToDelete)
  doAssert(index != -1, "removeView: View doesnt exists in views")
  self.views.delete(index)
  let prevView = childToDelete.prevView
  self.removeFromLinkedList(childToDelete)
  if currentViewWasRemoved and prevView.isSome:
    prevView.data.setFocused()
  childToDelete.owner = none[PView]()
  self.modified()

proc groupHandleEvent(self: PView, event: PEvent) = 
  if self.isHidden:
    return
  if self.views != nil:
    let childList = self.views
    for i in countDown(childList.high, childList.low):
      let child = childList[i]
      child.groupHandleEvent(event)
      if event.kind == TEventKind.eventNothing:
        break
  if event.isMouseEvent:
    if self.clickedInMe(event):
      if event.kind == TEventKind.eventMouseButtonDown:
        self.setFocused()
        self.modified()
      let localCoords = self.makeLocal(event.mouseX, event.mouseY)
      event.localMouseX = localCoords.x
      event.localMouseY = localCoords.y
      event.local = true
  self.handleEvent(event)
  if event.kind == TEventKind.eventMouseButtonDown:
    if event.local:
      event.setProcessed()


proc broadcast*(self: PView, event: PEvent) =
  if self.owner.isNone:
    self.groupHandleEvent(event)
  else:
    self.owner.data.broadcast(event)

proc broadcastCommand*[T](self: PView, cmd: TCmd, data: T) =
  var event = PEvent(kind: TEventKind.eventCommand, cmd: cmd, data: cast[pointer](data), sourceView: cast[pointer](self))
  self.broadcast(event)

proc execute*(self: PView): TExecutingResult =
  self.setFocused()
  self.Modified()
  self.pExecuting = true
  while self.pExecuting:
    if self.dirty or self.hasDirtyChild:
      var regions = TViewRepresentations(representations: @[])
      self.groupDraw(regions)
      drawToBackBuffer(regions)
      engine.swapBackBuffer()
      
    var event = engine.pollEvent()
    self.groupHandleEvent(event)
    
  return self.executingResult

proc getRootView(self: PView): PView =
  var parent = self
  while true:
    if parent.owner.isNone:
      return parent
    parent = parent.owner.data

proc executeView*(self, view: PView, x, y: int): TExecutingResult =
  doAssert(self != view, "self.xecuteView(self)")
  let savedFocusedView = self.focusedView
  self.addView(view, x, y)
  view.setFocused()
  view.pExecuting = true
  let root = self.getRootView()
  while view.pExecuting:
    if root.dirty or root.hasDirtyChild:
      var regions = TViewRepresentations(representations: @[])
      root.groupDraw(regions)
      drawToBackBuffer(regions)
      engine.swapBackBuffer()
    var event = engine.pollEvent()
    view.groupHandleEvent(event)
  self.removeView(view)
  savedFocusedView.ifSome do (savedView: PView):
    savedView.setFocused()
    
  return view.executingResult

proc executeViewAtCenter*(self, view: PView): TExecutingResult =
  let center = calcCenterPos(self, view)
  result = executeView(self, view, center.x, center.y)

type 
  PTestView* = ref TTestView
  TTestView* = object of TView
    name: string
    events*: seq[PEvent]
    recordingEvents*: bool

method writeData(self: PTestView, stream: PStringStream) = discard
method readData(self: PTestView, stream: PStringStream) = discard

method name(self: PTestView): string = "PTestView(" & self.name & ")"

method handleEvent(self: PTestView, event: PEvent) =
  if not self.recordingEvents:
    return
  self.events.add(event)

method draw*(self: PTestView): TDrawBuffer = discard

proc startRecordingEvents*(self: PTestView) = self.recordingEvents = true
proc stopRecordingEvents*(self: PTestView) = self.recordingEvents = false

when isMainModule:
  import unittest

  suite "View Test Suite":
    setup:
      var testv0 = PTestView(name: "testv0", events : @[], recordingEvents : false)
      var testv1 = PTestView(name: "testv1", events : @[], recordingEvents : false)
      var testv2 = PTestView(name: "testv2", events : @[], recordingEvents : false)
      var testv3 = PTestView(name: "testv3", events : @[], recordingEvents : false)
      var v0: PView = testv0
      var v1: PView = testv1
      var v2: PView = testv2
      var v3: PView = testv3

    test "test Ref Equality":
      check v0 != v1
      let v00 = v0
      check v0 == v00

    test "addView make the child dirty":
      check false == v1.dirty
      check false == v0.hasDirtyChild
      v0.addView(v1, 0, 0)
      check v1.dirty
      check v0.hasDirtyChild

      check false == v2.dirty
      check false == v1.hasDirtyChild
      v1.addView(v2, 0, 0)
      check v2.dirty
      check v1.hasDirtyChild

    test "addView sets the child's next and prev Views":
      check v1.prevView.isNone
      check v1.nextView.isNone
      v0.addView(v1, 0, 0)
      check v1.prevView.isNone
      check v1.nextView.isNone
      v0.addView(v2, 0, 0)
      check v1.prevView.isNone
      check v1.nextView.equals(v2)
      check v2.prevView.equals(v1)
      check v2.nextView.isNone

      v0.addView(v3, 0, 0)
      check v1.prevView.isNone
      check v1.nextView.equals(v2)
      check v2.prevView.equals(v1)
      check v2.nextView.equals(v3)
      check v3.prevView.equals(v2)
      check v3.nextView.isNone
      

    test "setWidthHeight changes the Buffer size as well":
      v0.setWidthHeight(10, 20)
      check v0.x == 0
      check v0.y == 0
      check v0.buff.w == 10
      check v0.buff.h == 20

    test "addView sets the child offsets":
      v0.addView(v1, 1, 1)
      check v1.x == 1
      check v1.y == 1
      v0.removeView(v1)
      v0.addView(v1, 1, 1)
      check v1.x == 1
      check v1.y == 1
      

    test "removeView":
      v0.addView(v1, 0, 0)
      v0.addView(v2, 0, 0)
      v0.addView(v3, 0, 0)
      check v0.views.len == 3
      check v0.bottomView.equals(v1)
      check v0.topView.equals(v3)
      v0.removeView(v3)
      check v0.views.len == 2
      check v0.topView.equals(v2)
      check v0.bottomView.equals(v1)
      check v3.owner.isNone
      check v0.dirty

      v0.settingDirtyToFalseForTestingPurposes
      v0.removeView(v2)
      check v0.views.len == 1
      check v0.topView.equals(v1)
      check v0.bottomView.equals(v1)
      check v2.owner.isNone
      check v0.dirty

      v0.settingDirtyToFalseForTestingPurposes
      v0.removeView(v1)
      check v0.views.len == 0
      check v0.topView.isNone
      check v0.bottomView.isNone
      check v1.owner.isNone
      check v0.dirty

    test "removeView sets the child's next and prev Views":
      v0.addView(v1, 0, 0)
      v0.addView(v2, 0, 0)
      v0.addView(v3, 0, 0)
      v0.removeView(v2)
      check v1.prevView.isNone
      check v1.nextView.equals(v3)
      check v2.prevView.isNone
      check v2.nextView.isNone
      check v3.prevView.equals(v1)
      check v3.nextView.isNone

      v0.removeView(v1)
      check v1.prevView.isNone
      check v1.nextView.isNone
      check v3.prevView.isNone
      check v3.nextView.isNone

    test "removing last view":
      v0.addView(v1, 0, 0)
      check(1 == v0.views.len)
      v0.removeView(v1)
      check v0.topView.isNone
      check v0.bottomView.isNone
      check v0.views.len == 0
      check v0.focusedView.isNone

    test "removing Focused view":
      v0.addView(v1, 0, 0)
      check(1 == v0.views.len)
      v1.setFocused()
      check v0.focusedView.equals(v1)
      v0.removeView(v1)
      check v0.topView.isNone
      check v0.bottomView.isNone
      check v0.views.len == 0
      check v0.focusedView.isNone

    test "makeLast":
      v0.addView(v1, 0, 0)
      v0.addView(v2, 0, 0)
      check(2 == v0.views.len)
      check(v1 == v0.views[0])
      check(v2 == v0.views[1])
      check v0.bottomView.equals(v1)
      check v0.topView.equals(v2)
      v0.makeLast(v1)
      check(2 == v0.views.len)
      check(v1 == v0.views[0])
      check(v2 == v0.views[1])
      check v0.topView.equals(v1)
      check v0.bottomView.equals(v2)

    test "makeMeLast":
      v0.addView(v1, 0, 0)
      v0.addView(v2, 0, 0)
      v1.addView(v3, 0, 0) 
      # 0 -> 1, 2
      #      1 -> 3
      check( 2 == v0.views.len)
      check(v1 == v0.views[0]) 
      check(v2 == v0.views[1])

      check( 1 == v1.views.len)
      check(v3 == v1.views[0])
      check v0.bottomView.equals(v1)
      check v0.topView.equals(v2)
      check v1.bottomView.equals(v3)
      check v1.topView.equals(v3)
      v1.makeMeLast()
      check( 2 == v0.views.len)
      check(v1 == v0.views[0]) 
      check(v2 == v0.views[1])

      check( 1 == v1.views.len)
      check(v3 == v1.views[0])
      check v0.bottomView.equals(v2)
      check v0.topView.equals(v1)
      check v1.bottomView.equals(v3)
      check v1.topView.equals(v3)

      v3.makeMeLast()
      check( 2 == v0.views.len)
      check(v1 == v0.views[0]) 
      check(v2 == v0.views[1])

      check( 1 == v1.views.len)
      check(v3 == v1.views[0])
      check v0.bottomView.equals(v2)
      check v0.topView.equals(v1)
      check v1.bottomView.equals(v3)
      check v1.topView.equals(v3)

    test "setCurrentView":
      v0.addView(v1, 0, 0)
      v0.addView(v2, 0, 0)
      v1.setFocused()
      check v1.isFocused
      check v2.isFocused == false
      
      v2.setFocused()
      check v1.isFocused == false
      check v2.isFocused

    test "setCurrentView2":
      v0.addView(v1, 0, 0)
      v0.addView(v2, 0, 0)
      v1.addView(v3, 0, 0) # ennél a sornál a v1 lesz a v0 utolsó eleme, mivel a szulo is makeLastol
      # 0 -> 1, 2
      #      1 -> 3
      check( 2 == v0.views.len)
      check(v1 == v0.views[0]) 
      check(v2 == v0.views[1])

      check( 1 == v1.views.len)
      check(v3 == v1.views[0])

      v1.setFocused()
      check( 2 == v0.views.len)
      check(v1 == v0.views[0]) 
      check(v2 == v0.views[1])

      check( 1 == v1.views.len)
      check(v3 == v1.views[0])
      check v0.bottomView.equals(v2)
      check v0.topView.equals(v1)
      check v1.bottomView.equals(v3)
      check v1.topView.equals(v3)


      v3.setFocused()
      check( 2 == v0.views.len)
      check(v1 == v0.views[0]) 
      check(v2 == v0.views[1])

      check( 1 == v1.views.len)
      check(v3 == v1.views[0])
      check v0.bottomView.equals(v2)
      check v0.topView.equals(v1)
      check v1.bottomView.equals(v3)
      check v1.topView.equals(v3)

    test "setFocused make all the hierarchy focused":
      v0.addView(v1, 0, 0)
      v1.addView(v2, 0, 0)
      
      v2.setFocused()
      check(v2.isFocused)
      check(v1.isFocused)

    test "show":
      v0.pHidden = true
      check(v0.pDirty == false)
      v0.show()
      check(v0.isHidden() == false)
      check(v0.dirty)

    test "hide":
      check(v0.pDirty == false)
      check(v0.isHidden == false)
      v0.hide()
      check(v0.isHidden)
      check(v0.dirty)

    test "calcOffset":
      v0.addView(v1, 20, 22)
      v1.addView(v2, 30, 33)
      
      v0.move(10, 11)

      v0.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
      v1.font = some(TFont(charWidth: TPixel(2), charHeight: TPixel(2)))
      
      let offsets = v2.calcOffset()
      check TPixel(((2*30 + 20*1 + 10))) == offsets.x
      check TPixel(((2*33 + 22*1 + 11))) == offsets.y

    test "makeLocal":
      v0.addView(v1, 20, 22)
      v1.addView(v2, 30, 33)
      
      v0.move(10, 11)
      v0.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(1)))
      v1.font = some(TFont(charWidth: TPixel(2), charHeight: TPixel(2)))
      
      let local = v2.makeLocal(TPixel(100), TPixel(200))
      check (((100 - (2*30 + 20*1 + 10)) div 2) == local.x)
      check (((200 - (2*33 + 22*1 + 11)) div 2) == local.y)


    test "pExecuting with int result":
      v0.pExecuting = true
      v0.stopExecutingWith(cmdOk, 12)
      check v0.executingResult.cmd == cmdOk
      check v0.executingResult.getInt() == 12

    test "pExecuting with string result":
      v0.pExecuting = true
      v0.stopExecutingWith(cmdOk, "12")
      check v0.executingResult.cmd == cmdOk
      check v0.executingResult.getString() == "12"

    test "pExecuting with ref result":
      v0.pExecuting = true
      let intRef = new(int)
      intRef[] = 12
      v0.stopExecutingWith(cmdOk, intRef)
      intRef[] = 13
      check v0.executingResult.cmd == cmdOk
      check cast[ref int](v0.executingResult.getPtr())[] == 13

    test "recursive clippingSize query":
      v0.font = some(TFont(charWidth: TPixel(1), charHeight: TPixel(2)))
      v0.useClipping = true
      v0.setWidthHeight(100, 200)

      v0.addView(v1, 0, 0)
      v1.addView(v2, 0, 0)
      v2.useClipping = true
      v2.setWidthHeight(10, 20)

      check v2.clippingRect.x == TPixel(0)
      check v2.clippingRect.y == TPixel(0)
      check v2.clippingRect.w == TPixel(10)
      check v2.clippingRect.h == TPixel(2*20)

      check v1.clippingRect.x == TPixel(0)
      check v1.clippingRect.y == TPixel(0)
      check v1.clippingRect.w == TPixel(100)
      check v1.clippingRect.h == TPixel(2*200)

      check v0.clippingRect.x == TPixel(0)
      check v0.clippingRect.y == TPixel(0)
      check v0.clippingRect.w == TPixel(100)
      check v0.clippingRect.h == TPixel(2*200)

    test "becoming current view generates an event":
      testv1.startRecordingEvents()
      testv1.setFocused()
      check(testv1.events.len == 1)
      check(testv1.events[0].kind == TEventKind.eventGetFocus)
      check(testv1.events[0].sourceViewEquals(testv1))

    test "becoming current view broadcasts an event":
      v0.addView(v1, 0, 0)
      v1.addView(v2, 0, 0)
      v2.addView(v3, 0, 0)

      v3.clearFocusedViews()

      testv0.startRecordingEvents()
      testv1.startRecordingEvents()
      testv2.startRecordingEvents()
      testv3.startRecordingEvents()

      v3.setFocused()
      let viewThatGotFocus = testv3

      proc checkViewsGotTheRightEvents(testView: PTestView) =
        check(testView.events.len == 1)
        let event = testView.events[0]
        check(event.kind == TEventKind.eventGetFocus)
        check(event.sourceViewEquals(viewThatGotFocus))

      checkViewsGotTheRightEvents(testv3)
      checkViewsGotTheRightEvents(testv2)
      checkViewsGotTheRightEvents(testv1)
      checkViewsGotTheRightEvents(testv0)

    test "losting 'Current state' generates an event":
      v0.addView(testv1, 0, 0)
      testv1.setFocused()
      testv1.startRecordingEvents()
      testv1.clearFocusedViews()
      check(testv1.events.len == 1)
      check(testv1.events[0].kind == TEventKind.eventLostFocus)
      check(testv1.events[0].sourceViewEquals(testv1))

    test "losting 'Current state' broadcasts an event":
      v0.addView(v1, 0, 0)
      v1.addView(v2, 0, 0)
      v2.addView(v3, 0, 0)

      v3.setFocused()
      testv0.startRecordingEvents()
      testv1.startRecordingEvents()
      testv2.startRecordingEvents()
      testv3.startRecordingEvents()
      v3.clearFocusedViews()
      let viewThatLostCurrentState = testv3

      proc checkViewsGotTheRightEvents(testView: PTestView) =
        check(testView.events.len == 3)
        let viewsThatLostTheirFocus = [v3, v2, v1]
        for i, event in testView.events[0..2]:
          check(event.kind == TEventKind.eventLostFocus)
          check(event.sourceViewEquals(viewsThatLostTheirFocus[i]))
        #let event = testView.events[0]
        #check(event.kind == TEventKind.eventLostFocus)
        #check(event.sourceViewEquals(viewThatLostCurrentState))
          

      checkViewsGotTheRightEvents(testv3)
      checkViewsGotTheRightEvents(testv2)
      checkViewsGotTheRightEvents(testv1)
      checkViewsGotTheRightEvents(testv0)
      
    test "gmLeftToParentsRight":
      v0.setWidthHeight(10, 10)
      v1.setWidthHeight(3, 3)
      v0.addView(v1, 5, 5)
      check v1.x == 5
      check v1.y == 5
      check v1.w == 3
      check v1.h == 3
      v1.growMode = {gmLeftToParentsRight}
      v0.setWidthHeight(12, 12)
      check v1.x == 7
      check v1.y == 5
      check v1.w == 1
      check v1.h == 3

    test "gmRightToParentsRight":
      v0.setWidthHeight(10, 10)
      v1.setWidthHeight(3, 3)
      v0.addView(v1, 5, 5)
      check v1.x == 5
      check v1.y == 5
      check v1.w == 3
      check v1.h == 3
      v1.growMode = {gmRightToParentsRight}
      v0.setWidthHeight(12, 12)
      check v1.x == 5
      check v1.y == 5
      check v1.w == 5
      check v1.h == 3

    test "gmTopToParentsBottom":
      v0.setWidthHeight(10, 10)
      v1.setWidthHeight(3, 3)
      v0.addView(v1, 5, 5)
      check v1.x == 5
      check v1.y == 5
      check v1.w == 3
      check v1.h == 3
      v1.growMode = {gmTopToParentsBottom}
      v0.setWidthHeight(12, 12)
      check v1.x == 5
      check v1.y == 7
      check v1.w == 3
      check v1.h == 1

    test "gmBottomToParentsBottom":
      v0.setWidthHeight(10, 10)
      v1.setWidthHeight(3, 3)
      v0.addView(v1, 5, 5)
      check v1.x == 5
      check v1.y == 5
      check v1.w == 3
      check v1.h == 3
      v1.growMode = {gmBottomToParentsBottom}
      v0.setWidthHeight(12, 12)
      check v1.x == 5
      check v1.y == 5
      check v1.w == 3
      check v1.h == 5

    test "Views cannot be smaller than (0, 0)":
      v0.setWidthHeight(1, 1)
      v0.grow(-2, -2)
      check v0.w == 0
      check v0.h == 0
      
    test "parentsSizeChanged":
      v1.setWidthHeight(1, 2)
      v1.growMode = gmGrowAsParent
      v1.parentsSizeChanged(-2, -3)
      check v1.w == 0
      check v1.h == 0

    test "minimal Size with grow":
      v0.setWidthHeight(3, 4)
      v0.minWidth = 2
      v0.minHeight = 2
      v0.grow(-1, -1)
      check v0.w == 2
      check v0.h == 3

      v0.grow(-1, -1)
      check v0.w == 2
      check v0.h == 2

      v0.grow(-1, -1)
      check v0.w == 2
      check v0.h == 2

    test "minimal Size with setWidthHeight":
      v0.minWidth = 2
      v0.minHeight = 2
      v0.setWidthHeight(0, 1)
      check v0.w == 2
      check v0.h == 2

    test "selectNext":
      let win = PTestView()
      win.addView(testv0, 0, 0)
      win.addView(testv1, 0, 0)
      win.addView(testv2, 0, 0)

      proc checkViewOrder(bottom, top: PView) =
        check testv0.prevView.isNone
        check testv0.nextView.data == testv1
        check testv1.prevView.data == testv0
        check testv1.nextView.data == testv2
        check testv2.prevView.data == testv1
        check testv2.nextView.isNone

        check win.bottomView.data == bottom
        check win.topView.data == top

      win.clearFocusedViews()

      checkViewOrder(testv0, testv2)
      check win.focusedView.isNone

      win.selectNext()
      check testv2.isFocused
      checkViewOrder(testv0, testv2)

      win.selectNext()
      check testv0.isFocused
      checkViewOrder(testv1, testv0)

      win.selectNext()
      check testv1.isFocused
      checkViewOrder(testv2, testv1)

      win.selectNext()
      check testv2.isFocused
      checkViewOrder(testv0, testv2)

    # TODO: jó sorrendben rajzolódnak ki
    # TODO: jó sorrendben kezelik le az eseményeket