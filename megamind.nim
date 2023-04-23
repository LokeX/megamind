import win
import os
import random
import sequtils

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
  Clue = enum none,match,present,notPresent
  CluesRow = array[10,Clue]
  CluesRows = array[nrOfBoardRows,CluesRow]

const
  minColumns = 4
  minColors = 4
  (cbx,cby,cah) = (100,100,50)
  cbb = cby+(colors.high*cah)
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
  selectedColor = 1
  rowCursor = 0
  rowCount = 0

proc generateCodeRow:BoardRow = 
  for i in 0..<nrOfBoardColumns:
    result[i] = (rand(1000*(nrOfColors-1)) div 1000)+1

func cluesRowFromCounts(clueCounts:openArray[int]):CluesRow =
  var cluesRowIdx = 0
  for clueCountsIdx,clueCount in clueCounts:
    for count in 1..clueCount: 
      result[cluesRowIdx] = Clue(clueCountsIdx+1)
      inc cluesRowIdx

proc clueCounts(userRow:BoardRow):array[3,int] =
  var 
    checkedColors:seq[int]
    matchCount,presentCount,notPresentCount:int
  for userColor in userRow:
    if userColor notin checkedColors:
      checkedColors.add userColor
      let codeRowCount = codeRow.count(userColor)
      if codeRowCount > 0: 
        let 
          colorCount = min(codeRowCount,board[rowCount].count(userColor))
          nrOfMatches = toSeq(0..nrOfBoardColumns-1)
            .countIt(codeRow[it] == userColor and userRow[it] == userColor)
        matchCount += nrOfMatches
        presentCount += colorCount - nrOfMatches
      else: notPresentCount += 1
  [matchCount,presentCount,notPresentCount]

proc generateCluesRow(userRow:BoardRow):CluesRow = userRow.clueCounts.cluesRowFromCounts

proc paintCursor(color:ColorRGBA):Image =
  let ctx = newContext(newImage(cah,cah))
  ctx.fillStyle = color
  ctx.fillRoundedRect((10,10,cah-20,cah-20).toRect,25)
  ctx.image

proc paintRowCursor:Image = paintCursor(colors[selectedColor])

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

proc drawImage(b:var Boxy,update:var bool,x,y:float,name:string,img:proc():Image) =
  if update:
    removeImage(name)
    addImage (name,img())
    update = false
  b.drawImage(name,vec2(x,y))

func keyResult(subst:int,formular:(int,int,int)):int =
  let (min,max,step) = formular
  if subst+step < min: max elif subst+step > max: min else: subst+step

template switchOn(s1,s2:untyped,first:bool,f1,f2:(int,int,int)) =
  if first: s1 = keyResult(s1,f1) else: s2 = keyResult(s2,f2) 

proc arrowInput(button:Button) =
  let step = if button in [KeyDown,KeyLeft]: -1 else: 1
  colorsUpdated = button in [KeyDown,KeyUp]
  boardUpdated = not colorsUpdated
  if gameOver: switchOn(nrOfColors,nrOfBoardColumns,colorsUpdated,
    (minColors,colors.high,step),(minColumns,board[0].len,step))
  else: switchOn(selectedColor,rowCursor,colorsUpdated,
    (1,nrOfColors,step),(0,nrOfBoardColumns-1,step))

proc handleInput(button:Button) =
  case button
  of KeyEnter: gameOver = not gameOver
  of KeyDown,KeyUp,KeyLeft,KeyRight: arrowInput(button)
  elif not gameOver:
    case button
    of KeySpace: board[rowCount][rowCursor] = selectedColor
    else: discard
 
proc keyboard(k:KeyEvent) =
  if k.button == ButtonUnknown:
    echo "Rune: ",k.rune
  elif k.button in [KeyDown,KeyUp,KeyRight,KeyLeft,KeyEnter,KeySpace]:
    handleInput(k.button)
    boardUpdated = boardUpdated or k.button == KeySpace
    codeRowUpdated = boardUpdated or k.button == KeyEnter
  echo k.button

proc draw(b:var Boxy) =
  var rowCursorUpdated = colorsUpdated
  b.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))
  b.drawImage(colorsUpdated,cbx.toFloat,cby.toFloat,"colorBar",paintColorBar)
  b.drawImage(boardUpdated,bx,by,"board",paintBoard)
  if not gameOver: 
    b.drawImage("colorCursor",vec2(cbx.toFloat,(cbb-(selectedColor*cah)).toFloat))
    b.drawImage(rowCursorUpdated,(bx+(rowCursor*cah)).toFloat,
      (cbb-((rowCount+2)*cah)).toFloat,"rowCursor",paintRowCursor)
  b.drawImage(codeRowUpdated,bx,cby+25,"code",paintCodeImage)

codeRow = generateCodeRow()
addImage(bg)
addImage ("colorCursor",paintCursor(rgba(255,255,255,255)))
addImage ("rowCursor",paintRowCursor())
addCall(newCall("megamind",keyboard,nil,draw,nil))
window.visible = true
randomize()
while not window.closeRequested:
  sleep(30)
  pollEvents()
  #for call in calls.filterIt(it.cycle != nil): call.cycle()
