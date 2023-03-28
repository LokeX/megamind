import win
import megaview
import os

let
  bg = ("bg", readImage("bgblue.png"))

proc keyboard (k:KeyEvent) =
  if k.button == ButtonUnknown:
    echo "Rune: ",k.rune
  else:
    echo k.button

proc mouse (m:MouseEvent) =
  if mouseClicked(m.keyState):
    echo "pos: ",m.pos

proc draw (b:var Boxy) =
  b.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))

proc initView() =
  addImage(bg)
  addCall(newCall("ninoview",keyboard,mouse,draw,nil))
  initMegaView()
#  initNinoText()
  window.visible = true

initView()
while not window.closeRequested:
  sleep(30)
  pollEvents()
  #for call in calls.filterIt(it.cycle != nil): call.cycle()
