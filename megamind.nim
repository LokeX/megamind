import win
import os
import random
import sugar

const
  colors = [
    rgba(0,0,0,255),
    rgba(0,0,255,255),rgba(138,43,226,255),rgba(165,42,42,255),rgba(95,158,160,255),
    rgba(127,255,0,255),rgba(210,105,30,255),rgba(100,149,237,255),rgba(220,20,60,255),
    rgba(0,255,255,255),rgba(0,0,139,255),rgba(0,139,139,255),rgba(184,134,11,255),
    rgba(0,100,0,255),rgba(139,0,139,255),rgba(255,140,0,255),rgba(255,20,147,255),
  ]
  nrOfBoardRows = 14

type 
  ColorBar = array[colors.len,Area]
  BoardRow = array[10,int]
  Board = array[nrOfBoardRows,BoardRow]

const
  minColumns = 4
  minColors = 4
  (cbx,cby,cah) = (100,100,50)
  colorBar = block:
    var bar:ColorBar
    let height = cah*colors.high
    for i in 0..colors.high:
      bar[i] = (0,height-(cah*(i+1)),cah,cah)
    bar
  by = cby+((colors.high-nrOfBoardRows)*cah)
  bx = cbx+(cah*2)

let bg = ("bg", readImage("bgblue.png"))
var
  codeRow:BoardRow
  codeRowUpdated = true
  board:Board
  nrOfBoardColumns = minColumns
  boardUpdated = true
  nrOfColors = colors.high
  colorsUpdated = true
  gameOver = true

proc generateCodeRow:BoardRow = 
  for i in 0..<nrOfBoardColumns:
    result[i] = (rand(1000*(nrOfColors-1)) div 1000)+1

proc paintCodeImage:Image =
  let 
    width = nrOfBoardColumns*cah
    ctx = newContext(newImage(width,cah))
  for x,colorIdx in codeRow:
    ctx.fillStyle = if gameOver: colors[colorIdx] else:rgba(0,0,0,255) 
    ctx.fillRect (x*cah,0,cah,cah).toRect
  ctx.image

proc paintBoard:Image =
  let 
    (width,height) = (nrOfBoardColumns*cah,nrOfBoardRows*cah)
    ctx = newContext(newImage(width,height))
  for y,row in board:
    for x,colorIdx in row:
      ctx.fillStyle = colors[colorIdx]
      ctx.fillRect (x*cah,height-((y+1)*cah),cah,cah).toRect
  ctx.image

proc paintColorBar:Image =
  let ctx = newContext(newImage(cah,cah*colors.len))
  for i in 1..nrOfColors:
    ctx.fillStyle = colors[i]
    ctx.fillRect(colorBar[i-1].toRect)
  ctx.image

proc drawImage(b:Boxy,update:var bool,x,y:float,name:string,img:() -> Image) =
  if update:
    removeImage(name)
    addImage (name,img())
    update = false
  b.drawImage(name,pos=vec2(x,y))

proc handleInput(button:Button) =
  case button
  of KeyDown: nrOfColors = if nrOfColors == minColors: colors.high else: nrOfColors-1
  of KeyUp: nrOfColors = if nrOfColors == colors.high: minColors else: nrOfColors+1
  of KeyLeft: nrOfBoardColumns = 
    if nrOfBoardColumns == minColumns: board[0].high else: nrOfBoardColumns-1
  of KeyRight: nrOfBoardColumns = 
    if nrOfBoardColumns == board[0].high: minColors else: nrOfBoardColumns+1
  else: discard

proc keyboard(k:KeyEvent) =
  if k.button == ButtonUnknown:
    echo "Rune: ",k.rune
  elif k.button in [KeyDown,KeyUp,KeyRight,KeyLeft]:
    handleInput(k.button)
    colorsUpdated = k.button in [KeyDown,KeyUp]
    boardUpdated = k.button in [KeyRight,KeyLeft]
    codeRowUpdated = boardUpdated
  echo k.button

proc draw(b:var Boxy) =
  b.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))
  b.drawImage(colorsUpdated,cbx.toFloat,cby.toFloat,"colorBar",paintColorBar)
  b.drawImage(boardUpdated,bx,by,"board",paintBoard)
  b.drawImage(codeRowUpdated,bx,cby+25,"code",paintCodeImage)

codeRow = generateCodeRow()
addImage(bg)
addCall(newCall("megamind",keyboard,nil,draw,nil))
window.visible = true
randomize()
while not window.closeRequested:
  sleep(30)
  pollEvents()
  #for call in calls.filterIt(it.cycle != nil): call.cycle()
