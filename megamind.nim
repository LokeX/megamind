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
  Locks = array[10,bool]
  Clue = enum none,match,present,notPresent
  CluesRow = array[10,Clue]
  Clues = array[nrOfBoardRows,CluesRow]
  Update = tuple[codeRow,clues,board,colors:bool]
  Game = tuple[nrOfColumns,nrOfColors,selectedColor,rowCursorPos,rowCount:int]
  GameState = enum setup,won,lost,playing

const
  minColumns = 4
  minColors = 4
  (cbx,cby,cah) = (100,100,50)
  cbb = cby+(colors.high*cah)
  by = cby+((colors.high-nrOfBoardRows)*cah)
  bx = cbx+(cah*2)

const colorBar = block:
  var bar:ColorBar
  let height = cah*colors.high
  for i in 0..colors.high:
    bar[i] = (0,height-(cah*(i+1)),cah,cah)
  bar

let bg = ("bg", readImage("bgblue.png"))
var
  game:Game
  update:Update
  clues:Clues
  codeRow:BoardRow
  board:Board
  locks:Locks
  gameState:GameState

proc initSetup =
  var
    newClues:Clues
    newBoard:Board
  clues = newClues
  board = newBoard
  update.board = true
  update.clues = true

proc initGame =
  game.nrOfColors = colors.high
  game.nrOfColumns = minColumns
  game.selectedColor = 1
  game.rowCount = 0
  game.rowCursorPos = 0

proc gameOver:bool = gameState in [won,lost]

proc gameWon:bool = codeRow == board[game.rowCount]

proc generateCodeRow:BoardRow = 
  for i in 0..<game.nrOfColumns:
    result[i] = (rand(1000*(game.nrOfColors-1)) div 1000)+1

func cluesRowFromCounts(clueCounts:openArray[int]):CluesRow =
  var cluesRowIdx = 0
  for clueCountsIdx,clueCount in clueCounts:
    for count in 1..clueCount: 
      result[cluesRowIdx] = Clue(clueCountsIdx+1)
      inc cluesRowIdx

template countUserColorClues =
  let codeRowUserColorCount = codeRow.count(userColor)
  if codeRowUserColorCount > 0: 
    let 
      userColorCount = min(codeRowUserColorCount,board[game.rowCount].count(userColor))
      nrOfMatches = zip(codeRow,userRow).countIt(it[0] == userColor and it[1] == userColor)
    matchCount += nrOfMatches
    presentCount += userColorCount - nrOfMatches
  else: notPresentCount += 1

proc clueCounts(userRow:BoardRow):array[3,int] =
  var 
    checkedColors:seq[int]
    matchCount,presentCount,notPresentCount:int
  for userColor in userRow[0..<game.nrOfColumns]:
    if userColor notin checkedColors:
      countUserColorClues
      checkedColors.add userColor
  [matchCount,presentCount,notPresentCount]

proc generateCluesRow(userRow:BoardRow):CluesRow = userRow.clueCounts.cluesRowFromCounts

proc paintCursor(color:ColorRGBA):Image =
  let ctx = newContext(newImage(cah,cah))
  ctx.fillStyle = color
  ctx.fillRoundedRect((10,10,cah-20,cah-20).toRect,25)
  ctx.image

proc paintRowCursor:Image = paintCursor(colors[game.selectedColor])

proc paintCodeImage:Image =
  let 
    width = game.nrOfColumns*cah
    ctx = newContext(newImage(width,cah))
  for x,colorIdx in codeRow:
    ctx.fillStyle = colors[colorIdx]
    # ctx.fillStyle = if gameOver: colors[colorIdx] else:rgba(0,0,0,255) 
    ctx.fillRect (x*cah,0,cah,cah).toRect
  ctx.image
 
proc paintBoard:Image =
  let 
    (width,height) = (game.nrOfColumns*cah,nrOfBoardRows*cah)
    ctx = newContext(newImage(width,height))
  for y,row in board:
    for x,colorIdx in row:
      ctx.fillStyle = colors[0]
      ctx.fillRect (x*cah,height-((y+1)*cah),cah,cah).toRect
      ctx.fillStyle = colors[colorIdx]
      ctx.fillRect ((x*cah)+2,height-((y+1)*cah)+2,cah-4,cah-4).toRect
      if y == game.rowCount and locks[x]:
        ctx.fillStyle = rgba(0,0,0,150)
        ctx.fillRoundedRect(((x*cah)+10,10+height-((y+1)*cah),cah-20,cah-20).toRect,50)
  ctx.image

template clueFillStyleColor:ColorRGBA =
  case clue
  of match: rgba(0,255,0,255)
  of none: colors[0]
  of present: rgba(255,255,0,255)
  of notPresent: rgba(255,0,0,255)

proc paintClues:Image =
  let 
    (width,height) = (game.nrOfColumns*(cah div 2),nrOfBoardRows*cah)
    ctx = newContext(newImage(width,height))
  for y,cluesRow in clues:
    for x,clue in cluesRow[0..<game.nrOfColumns]:
      ctx.fillStyle = colors[0]
      ctx.fillRect (x*(cah div 2),height-((y+1)*cah),cah div 2,cah).toRect
      ctx.fillStyle = clueFillStyleColor
      ctx.fillRoundedRect((x*(cah div 2)+2,height-((y+1)*cah)+2,(cah div 2)-4,cah-4).toRect,50)
  ctx.image

proc paintColorBar:Image =
  let ctx = newContext(newImage(cah,cah*colors.len))
  for i in 1..game.nrOfColors:
    ctx.fillStyle = colors[i]
    ctx.fillRect(colorBar[i-1].toRect)
  ctx.image

proc drawImage(b:var Boxy,update:var bool,x,y:float,name:string,image:proc():Image) =
  if update:
    removeImage(name)
    addImage (name,image())
    update = false
  b.drawImage(name,vec2(x,y))

func keyResult(subst:int,formular:(int,int,int)):int =
  let (min,max,step) = formular
  if subst+step < min: max elif subst+step > max: min else: subst+step

template switchOn(s1,s2:untyped,f1,f2:(int,int,int)) =
  if update.colors: s1 = keyResult(s1,f1) else: s2 = keyResult(s2,f2) 

template setArrowImageUpdates =
  update.colors = k.button in [KeyDown,KeyUp]
  update.board = not update.colors
  update.clues = update.board

template arrowPressed =
  setArrowImageUpdates
  let step = if k.button in [KeyDown,KeyLeft]: -1 else: 1
  if gameState == setup: switchOn(game.nrOfColors,game.nrOfColumns,
    (minColors,colors.high,step),(minColumns,board[0].len,step))
  elif gameState == playing: switchOn(game.selectedColor,game.rowCursorPos,
    (1,game.nrOfColors,step),(0,game.nrOfColumns-1,step))

template startNewGame =
  gameState = playing
  update.codeRow = true
  update.colors = true
  codeRow = generateCodeRow()

proc notRepeatRow:bool =
  game.rowCount == 0 or board[game.rowCount] != board[game.rowCount-1]

proc rowFilled:bool =
  board[game.rowCount].countIt(it != 0) == game.nrOfColumns

template newRow = 
  if rowFilled() and notRepeatRow():
    clues[game.rowCount] = board[game.rowCount].generateCluesRow
    inc game.rowCount
    if game.rowCount > 0:
      for pos in 0..<game.nrOfColumns:
        if locks[pos]: board[game.rowCount][pos] = board[game.rowCount-1][pos]
    game.rowCursorPos = 0
    update.clues = true

template startGameSetup =
  gameState = setup
  initGame()
  initSetup()

template enterKeyPressed =
  update.board = true
  if gameOver():
    startGameSetup
  elif gameState == setup:
    startNewGame
  elif gameWon():
    gameState = won
  elif game.rowCount < nrOfBoardRows-1:
    newRow
  else: gameState = lost

template spreadColors =
  let 
    nrOfColumns = board[game.rowCount][game.rowCursorPos..<game.nrOfColumns].count(0)
    nrOfColors = game.nrOfColors-game.selectedColor+1
    colorRepeat = 
      if nrOfColors >= nrOfColumns: 1 else: 
        (nrOfColumns div nrOfColors)+
        (if nrOfColumns mod nrOfColors > 0: 1 else: 0)
  var count = 0
  for pos in game.rowCursorPos..<game.nrOfColumns:
    if board[game.rowCount][pos] == 0:
      board[game.rowCount][pos] = game.selectedColor
      inc count
    if count == colorRepeat:
      inc game.selectedColor
      count = 0
  if game.selectedColor >= game.nrOfColors: game.selectedColor = 1
  update.board = true

template fillColor =
  let inputColor = board[game.rowCount][game.rowCursorPos]
  for pos in game.rowCursorPos..<game.nrOfColumns:
    if board[game.rowCount][pos] == inputColor:
      board[game.rowCount][pos] = game.selectedColor
  update.board = true

template spaceKeyPressed =
  let sameColor = board[game.rowCount][game.rowCursorPos] == game.selectedColor
  locks[game.rowCursorPos] = not locks[game.rowCursorPos] and sameColor
  board[game.rowCount][game.rowCursorPos] = game.selectedColor
  update.board = true

template insertKeyPressed =
  if game.rowCount > 0:
    board[game.rowCount][game.rowCursorPos] = board[game.rowCount-1][game.rowCursorPos]
  update.board = true

template deleteKeyPressed =
  board[game.rowCount][game.rowCursorPos] = 0
  locks[game.rowCursorPos] = false
  update.colors = true

template tabKeyPressed =
  if board[game.rowCount][game.rowCursorPos] > 0:
    game.selectedColor = board[game.rowCount][game.rowCursorPos]
  elif game.rowCount > 0:
    game.selectedColor = board[game.rowCount-1][game.rowCursorPos]
  update.colors = true

template copyLastLine =
  if game.rowCount > 0:
    for pos in 0..<game.nrOfColumns:
      if board[game.rowCount][pos] == 0:
        board[game.rowCount][pos] = board[game.rowCount-1][pos]
  update.board = true

template eraseLine =
  for pos in 0..<game.nrOfColumns:
    if not locks[pos]:
      board[game.rowCount][pos] = 0
  update.board = true

template deleteLine =
  for pos in 0..<game.nrOfColumns:
    board[game.rowCount][pos] = 0
    locks[pos] = false
  update.board = true

template removeLocks =
  for pos in 0..<game.nrOfColumns:
    locks[pos] = false
  update.board = true

proc keyboard(k:KeyEvent) = 
  echo k.button
  case k.button
  of KeyEnter: enterKeyPressed
  of KeyDown,KeyUp,KeyLeft,KeyRight: arrowPressed
  elif not gameOver():
    case k.button
    of KeyS: spreadColors
    of KeyF: fillColor
    of KeyL: copyLastLine
    of KeyE: eraseLine
    of KeyD: deleteLine
    of KeyR: removeLocks
    of KeyTab: tabKeyPressed
    of KeyInsert: insertKeyPressed
    of KeyDelete: deleteKeyPressed
    of KeySpace: spaceKeyPressed
    else: discard

proc draw(b:var Boxy) =
  var rowCursorUpdated = update.colors
  b.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))
  b.drawImage(update.colors,cbx.toFloat,cby.toFloat,"colorBar",paintColorBar)
  b.drawImage(update.board,bx,by,"board",paintBoard)
  b.drawImage(update.clues,(bx+(game.nrOfColumns*(cah+1))).toFloat,by,"clues",paintClues)
  if gameState == playing: 
    b.drawImage("colorCursor",vec2(cbx.toFloat,(cbb-(game.selectedColor*cah)).toFloat))
    b.drawImage(rowCursorUpdated,(bx+(game.rowCursorPos*cah)).toFloat,
      (cbb-((game.rowCount+2)*cah)).toFloat,"rowCursor",paintRowCursor)
    b.drawImage(update.codeRow,bx,cby.toFloat,"code",paintCodeImage)

template initUpdates =
  update.board = true
  update.clues = true
  update.codeRow = true
  update.colors = true

template initMegamind =
  addImage(bg)
  addImage ("colorCursor",paintCursor(rgba(255,255,255,255)))
  addImage ("rowCursor",paintRowCursor())
  addCall(newCall("megamind",keyboard,nil,draw,nil))
  randomize()
  initGame()
  initUpdates

initMegamind
codeRow = generateCodeRow()
window.visible = true
while not window.closeRequested:
  sleep(30)
  pollEvents()
  #for call in calls.filterIt(it.cycle != nil): call.cycle()
