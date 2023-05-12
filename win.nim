import boxy, opengl, windy
import std/sequtils
import std/os
export boxy
export windy
export os
import times

type
  FileName   = tuple[name,path:string]
  ImageName* = tuple[name:string,image:Image]
  Area* = tuple[x,y,w,h:int]
  NamedImage = object of RootObj
    img*:ImageName
  NamedArea  = object of RootObj
    name*:string
  ImageHandle* = object of NamedImage
    area*:Area
  AreaHandle*  = ref object of NamedArea
    area*:Area
  MouseHandle* = object 
    name*      :string
    x1,y1,x2,y2:int
  KeyState* = tuple[down,pressed,released,toggle:bool]
  Event     = object of RootObj
    keyState*: KeyState
    button*  :Button
  MouseEvent* = object of Event
    pos* :tuple[x,y:int]
  SpecialKeys = tuple[ctrl,shift,alt:bool]
  KeyEvent*   = object of Event
    rune*:Rune
    pressed*:SpecialKeys
  KeyCall   = proc(keyboard:KeyEvent)
  MouseCall = proc(mouse:MouseEvent)
  DrawCall  = proc(boxy:var Boxy)
  CycleCall = proc()
  TimerCall* = object
    call*:proc()
    lastTime*:float
    secs*:float
  Call      = object
    reciever*:string
    keyboard*:KeyCall
    mouse*   :MouseCall
    draw*    :DrawCall
    cycle*   :CycleCall
    timer*   :TimerCall

let 
  window* = newWindow(
    "",
    ivec2(800,600),
    WindowStyle.DecoratedResizable, 
    visible = false
  )
  scr = getScreens()[0]
  scrWidth* = (int32)scr.right
  scrHeight* = (int32)scr.bottom
  winWidth* = scrWidth-(scrWidth div 50)
  winHeight* = scrHeight-(scrHeight div 10)
  # winWidth* = scrWidth-(scrWidth div 20)
  # winHeight* = scrHeight-(scrHeight div 8)
  boxyScale*: float = scrWidth/1920
#  boxyScale*: float = 1
echo "Scale: ",boxyScale

window.size = ivec2(winWidth,winHeight)
# window.pos = ivec2((scrWidth-winWidth) div 2,(scrHeight-winHeight) div 3)
window.pos = ivec2((scrWidth-winWidth) div 2,(scrHeight-winHeight) div 3)
#window.icon = readImage("barman.png")
window.runeInputEnabled = true
makeContextCurrent(window)
loadExtensions()

var
  calls*:seq[Call]
  mouseHandles*:seq[MouseHandle]
  specialKeys:SpecialKeys
  bxy = newBoxy()

bxy.scale(boxyScale)

proc windowWidth*(): int = (int)(scrWidth-(scrWidth div 20))

proc windowHeight*(): int = (int)(scrHeight-(scrHeight div 8))

proc winSize*(): IVec2 =
  ivec2(winWidth,winHeight)

proc echoMouseHandles*() =
  for mouse in mouseHandles:
    echo mouse.name

proc addCall*(call:Call) = calls.add(call)

proc newCall*(r:string, k:KeyCall, m:MouseCall, d:DrawCall, c:CycleCall,t:TimerCall): Call =
  Call(reciever:r,keyboard:k,mouse:m,draw:d,cycle:c,timer:t)

func mouseClicked(button:Button): bool = 
  button in [
    MouseLeft,MouseRight,MouseMiddle,
    DoubleClick,TripleClick,QuadrupleClick
  ]

func mouseClicked*(k:KeyState): bool = 
  k.down or k.pressed or k.released

func mousePos(pos:Ivec2): tuple[x,y:int] =
  (cast[int](pos[0]),cast[int](pos[1]))

proc keyState(b:Button): KeyState =
  (window.buttonDown[b], window.buttonDown[b],
  window.buttonReleased[b], window.buttonToggle[b])

func keyState(): KeyState = (false,false,false,false)

proc newMouseMoveEvent(): MouseEvent =
  MouseEvent(pos:mousePos(window.mousePos),keyState:keyState())

proc newMouseKeyEvent(b:Button): MouseEvent = 
  MouseEvent(
    pos:mousePos(window.mousePos),
    keyState:keyState(b),
    button:b
  )

proc specKeys(b:Button):SpecialKeys =
  case b
  of KeyLeftShift,KeyRightShift: specialKeys.shift = b.keyState.down
  of KeyLeftControl,KeyRightControl: specialKeys.ctrl = b.keyState.down
  of KeyLeftAlt,KeyRightAlt: specialKeys.alt = b.keyState.down
  else:discard
  specialKeys

proc newKeyEvent(b:Button,r:Rune): KeyEvent = 
  KeyEvent(
    pressed:specKeys(b),
    rune:r,
    keyState:keyState(b),
    button:b
  )

proc newMouseEvent(button:Button): MouseEvent =
    if mouseClicked(button): 
      newMouseKeyEvent(button) 
    else: 
      newMouseMoveEvent()

func fileNames*(paths: seq[string]): seq[FileName] =
  for path in paths: 
    result.add (splitFile(path).name,path)

proc mouseOn*(h:MouseHandle): bool =
  let
    (mx,my) = mousePos(window.mousePos)
  h.x1 <= mx and h.y1 <= my and mx <= h.x2 and my <= h.y2

proc mouseOn*(): string =
  for i in countdown(mouseHandles.len-1,0):
    if mouseOn(mouseHandles[i]):
      return mouseHandles[i].name
  return "None"

proc mouseOn*(imgName:ImageName): bool = mouseOn() == imgName.name

proc mouseOn*(ih:ImageHandle): bool = mouseOn() == ih.img.name

proc mouseOn*(ah:AreaHandle): bool = mouseOn() == ah.name

proc newMouseHandle*(hn:string,x,y,w,h:int): MouseHandle =
  MouseHandle(
    name:hn,
    x1:(x.toFloat*boxyScale).toInt,
    y1:(y.toFloat*boxyScale).toInt,
    x2:((x+w).toFloat*boxyScale).toInt,
    y2:((y+h).toFloat*boxyScale).toInt
  )

proc newMouseHandle*(ah:AreaHandle): MouseHandle =
  let
    (x,y,w,h) = ah.area
  newMouseHandle(ah.name,x,y,w,h)

proc newMouseHandle*(ih:ImageHandle): MouseHandle =  
  let
    (x,y,w,h) = ih.area
  newMouseHandle(ih.img.name,x,y,w,h)

proc addMouseHandle*(mh:MouseHandle) =
  mouseHandles.add(mh)

proc removeMouseHandle*(name:string) =
  let index = mouseHandles.mapIt(it.name).find(name)
  if index > -1: mouseHandles.delete(index)

proc newImageHandle*(img:ImageName,x,y:int): ImageHandle =
  ImageHandle(
    img:(img.name,img.image),
    area:(x,y,img.image.width,img.image.height)
  )

func toRect*(x,y,w,h:int): Rect =
  rect(vec2(x.toFloat,y.toFloat),vec2(w.toFloat,h.toFloat))

func toRect*(area:Area): Rect =
  let
    (x,y,w,h) = area
  rect(vec2(x.toFloat,y.toFloat),vec2(w.toFloat,h.toFloat))

func toRect*(h:MouseHandle): Rect =
  rect(vec2(h.x1.toFloat,h.y1.toFloat),vec2((h.x2-h.x1).toFloat,(h.y2-h.y1).toFloat))

proc newAreaHandle*(name:string,x,y,w,h:int): AreaHandle =
  AreaHandle(name:name,area:(x,y,w,h))
 
proc newAreaHandle*(ah:tuple[name:string,area:Area]): AreaHandle =
  AreaHandle(name:ah.name,area:ah.area)

proc newAreaHandle*(x,y:int,ni:NamedImage): AreaHandle =
  newAreaHandle(ni.img.name,x,y,ni.img.image.width,ni.img.image.height)

proc loadImages(files:seq[FileName]): seq[ImageName] =
  for file in files:
    result.add (file.name,readImage(file.path))

proc loadImages*(s:string): seq[ImageName] =
  loadImages(toSeq(walkFiles(s)).fileNames())

proc addImage*(ih:ImageName) =
  bxy.addImage(ih.name,ih.image)

proc addImage*(ih:ImageHandle) =
  addImage(ih.img)

proc addImages*(ihs:seq[ImageName]) =
  for ih in ihs:
    bxy.addImage(ih.name,ih.image)

proc removeImage*(key:string) =
  bxy.removeImage(key)

proc callBack(button:Button) =
  for call in calls:
    if mouseClicked(button):
      if call.mouse != nil: 
        call.mouse(newMouseEvent(button))
    else:
      if call.keyboard != nil: 
        call.keyboard(newKeyEvent(button,"¤".toRunes[0]))

window.onButtonRelease = callBack

window.onButtonPress = proc (button:Button) =
  if button == KeyF12:
    window.closeRequested = true
  else: button.callBack

window.onFrame = proc() =
  bxy.beginFrame(window.size)
  for call in calls:
    if call.draw != nil: call.draw(bxy)
  bxy.endFrame()
  window.swapBuffers()

window.onRune = proc(rune:Rune) =
  var button:Button
  for call in calls:
    if call.keyboard != nil: 
      call.keyboard(newKeyEvent(button,rune))

window.onMouseMove = proc () =
  for call in calls:
    if call.mouse != nil: 
      call.mouse(newMouseMoveEvent())
