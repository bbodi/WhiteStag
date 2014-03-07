import unicode

import view
import drawbuffer
import color
import strutils
import rect

type
  TWindowFrame* = tuple 
    title: string
    hasBorder: bool

proc drawTitle(self: TWindowFrame, view: PView, buff: var TDrawBuffer) =
  let frameW = view.w
  let titleW = self.title.runeLen
  let titleX = frameW div 2 - titleW div 2
  let styles = if view.isFocused: {styleBold} else: {styleNormal}
  buff.writeText(titleX, 0, self.title, fg = TitleColor.color(view.isFocused), 
    bg = FrameColor.color(view.isFocused), styles = styles)

proc drawHorizontalBorder(self: TWindowFrame, x, y, w: int, view: PView, buff: var TDrawBuffer) = 
  let borderStr = w.repeatStr("─")
  buff.writeText(x, y, borderStr, BorderColor.color(view.isFocused), FrameColor.color(view.isFocused), styles={styleNormal})
    

proc drawVerticalBorder(self: TWindowFrame, x, y, h: int, view: PView, buff: var TDrawBuffer) = 
  for i in 0..h-1:
    buff.writeText(x, y+i, "│", BorderColor.color(view.isFocused), FrameColor.color(view.isFocused))

proc drawCorners(self: TWindowFrame, view: PView, buff: var TDrawBuffer) =
  let fgcolor = BorderColor.color(view.isFocused)
  let bgcolor = FrameColor.color(view.isFocused)
  buff.writeText(0, 0, "┌", fgcolor, bgcolor)
  buff.writeText(view.w-1, 0, "┐", fgcolor, bgcolor)
  buff.writeText(view.w-1, view.h-1, "┘", fgcolor, bgcolor)
  buff.writeText(0, view.h-1, "└", fgcolor, bgcolor)

proc drawBorder(self: TWindowFrame, view: PView, buff: var TDrawBuffer) =
  self.drawHorizontalBorder(1, 0, view.w-2, view, buff)
  self.drawHorizontalBorder(1, view.h-1, view.w-2, view, buff)
  self.drawVerticalBorder(0, 1, view.h-2, view, buff)
  self.drawVerticalBorder(view.w-1, 1, view.h-2, view, buff)
  self.drawCorners(view, buff)
  self.drawTitle(view, buff)

proc draw*(self: TWindowFrame, view: PView, buff: var TDrawBuffer) =
  let w = view.w
  let h = view.h
  buff.setCells(0, 0, w, h, bg = FrameColor.color(view.isFocused))
  if self.hasBorder:
    self.drawBorder(view, buff)