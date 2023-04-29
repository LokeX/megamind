import win
import os
import random
import sequtils
import strutils
import megasound

const
  colors = [
    rgba(0,0,0,255),
    rgba(25,25,225,255),rgba(138,43,226,255),rgba(165,42,42,255),rgba(95,158,160,255),
    rgba(127,255,0,255),rgba(210,105,30,255),rgba(100,149,237,255),rgba(220,20,60,255),
    rgba(0,255,255,255),rgba(0,0,139,255),rgba(0,139,139,255),rgba(200,200,0,255),
    rgba(0,150,0,255),rgba(139,0,139,255),rgba(255,140,100,255),rgba(255,20,147,255),
  ]
  nrOfBoardRows = 14
  maxColumns = 10

type 
  ColorBar = array[colors.len,Area]
  BoardRow = array[maxColumns,int]
  Board = array[nrOfBoardRows,BoardRow]
  Locks = array[maxColumns,bool]
  Clue = enum none,match,present,notPresent
  CluesRow = array[maxColumns,Clue]
  Clues = array[nrOfBoardRows,CluesRow]
  Update = tuple[codeRow,clues,board,colors,helpTxt,spread:bool]
  Game = tuple[nrOfColumns,nrOfColors,selectedColor,rowCursorPos,rowCount:int]
  GameState = enum setup,won,lost,playing

const
  minColumns = 4
  minColors = 4
  (cbx,cby,cah) = (100,100,50)
  cbb = cby+(colors.high*cah)
  by = cby+((colors.high-nrOfBoardRows)*cah)
  bx = cbx+(cah*2)
  (cbxf,cbyf) = (cbx.toFloat,cby.toFloat)

const colorBar = block:
  var bar:ColorBar
  let height = cah*colors.high
  for i in 0..colors.high:
    bar[i] = (0,height-(cah*(i+1)),cah,cah)
  bar

proc paintHelpText(filename:string):Image

let 
  bg = ("bg", readImage("bgblue.png"))
  setupTxt = paintHelpText("setup")
  playTxt = paintHelpText("play")
  wonTxt = paintHelpText("won")
  lostTxt = paintHelpText("lost")

var
  game:Game
  update:Update = (true,true,true,true,true,true)
  clues:Clues
  codeRow:BoardRow
  board:Board
  locks:Locks
  gameState:GameState
  userSpread:int

template initSetup =
  var
    newClues:Clues
    newBoard:Board
  clues = newClues
  board = newBoard
  update.board = true
  update.clues = true
  update.helpTxt = true

proc initGame =
  game.nrOfColors = colors.high
  game.nrOfColumns = minColumns
  game.selectedColor = 1
  game.rowCount = 0
  game.rowCursorPos = 0

proc gameOver:bool = gameState in [won,lost]

template gameWon:bool = codeRow == board[game.rowCount]

template generateCodeRow = 
  for i in 0..<game.nrOfColumns:
    codeRow[i] = (rand(1000*(game.nrOfColors-1)) div 1000)+1

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
    ctx.fillStyle = rgba(0,0,0,255)
    ctx.fillRect ((x*cah),0,cah,cah).toRect
    ctx.fillStyle = if gameOver(): colors[colorIdx] else:rgba(50,50,50,255) 
    ctx.fillRect ((x*cah)+2,2,cah-4,cah-4).toRect
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

proc newFont(typeface: Typeface, size: float32, color: Color): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color

proc currentSpreadColorCount:int
proc paintSpread:Image =
  let 
    width = game.nrOfColumns*(cah div 2)
    typeface = readTypeface("fonts\\Roboto-Regular_1.ttf")
    font = newFont(typeface,20,color(1,1,1,1))
    text = "S = " & $currentSpreadColorCount()
  result = newImage(width,50)
  result.fill(rgba(0, 0, 0, 255))
  result.fillText(font.typeset(text),translate(vec2(10,10)))

proc paintColorBar:Image =
  let ctx = newContext(newImage(cah,cah*colors.len))
  for i in 1..game.nrOfColors:
    ctx.fillStyle = colors[i]
    ctx.fillRect(colorBar[i-1].toRect)
  ctx.image

template helpText:seq[Span] =
  var spans:seq[Span]
  for line in lines("txt\\"&fileName&".txt"):
    if line.toLower.startsWith("header:"):
      spans.add newSpan(line[7..line.high]&"\n",headerFont)
    elif line.startsWith("<"):
      spans.add newSpan(line,keyFont)
    elif line.startsWith("|"):
      let t = line.split("|")
      spans.add newSpan(t[^2],keyFont)
      spans.add newSpan(t[^1]&"\n",font)
    else: spans.add newSpan(line&"\n",font)
  spans

proc paintHelpText(filename:string):Image =
  let 
    typeface = readTypeface("fonts\\Roboto-Regular_1.ttf")
    font = newFont(typeface, 20, color(1, 1, 1, 1))
    keyFont = newFont(typeface, 20, color(0, 1, 0, 1))
    headerFont = newFont(typeface, 24, color(1, 1, 0, 1))
    text = helpText
  result = newImage(700, 800)
  result.fill(rgba(0, 0, 0, 255))
  result.fillText(typeset(text,vec2(700,780)),translate(vec2(20,20)))

proc paintHelpText:Image = 
  case gameState
  of setup: setupTxt
  of playing: playTxt
  of lost: lostTxt
  of won: wonTxt

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
  update.helpTxt = true
  generateCodeRow

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

proc wonOrLost(state:GameState,sound:string) =
  clues[game.rowCount] = board[game.rowCount].generateCluesRow
  gameState = state
  update.clues = true
  update.codeRow = true
  update.helpTxt = true
  playSound(sound)

template enterKeyPressed =
  update.board = true
  playSound("Blop-Mark_DiAngelo")
  if gameOver():
    startGameSetup
  elif gameState == setup:
    startNewGame
  elif gameWon():
    wonOrLost(won,"applause-2")
  elif game.rowCount < nrOfBoardRows-1:
    newRow
  else: wonOrLost(lost,"sad-trombone")

proc colorSpan(startColor:int):int =
  startColor-game.selectedColor+1

proc availableColumns:int =
  board[game.rowCount][game.rowCursorPos..<game.nrOfColumns].count(0)

proc availableColors:int = colorSpan(game.nrOfColors)

template maxSpread:int = min(availableColors(),availableColumns())

template colorRepeat():int =
  let 
    nrOfColumns = availableColumns()
    nrOfColors = availableColors()
  if userSpread > 0:
    nrOfColumns div userSpread
  elif nrOfColors >= nrOfColumns: 1 else: 
    (nrOfColumns div nrOfColors)+
    (if nrOfColumns mod nrOfColors > 0: 1 else: 0)

proc currentSpreadColorCount:int =
  if userSpread > 0: userSpread else: maxSpread
 
template spreadColors =
  let 
    repeat = colorRepeat
    maxColors = currentSpreadColorCount()
    selectedColor = game.selectedColor
  var count = 0
  for pos in game.rowCursorPos..<game.nrOfColumns:
    if board[game.rowCount][pos] == 0:
      board[game.rowCount][pos] = game.selectedColor
      inc count
    if count == repeat and colorSpan(selectedColor) < maxColors:
      inc game.selectedColor
      count = 0
  if count > 0: inc game.selectedColor
  if game.selectedColor > game.nrOfColors: game.selectedColor = 1
  update.spread = true
  update.board = true
  userSpread = 0

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
  game.selectedColor = board[game.rowCount][game.rowCursorPos]
  update.board = true

template deleteKeyPressed =
  board[game.rowCount][game.rowCursorPos] = 0
  locks[game.rowCursorPos] = false
  update.board = true

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

template combinationReveal =
  gameState = lost
  update.helpTxt = true
  update.codeRow = true
  playSound("sad-trombone")

template test =
  board[game.rowCount] = codeRow
  update.board = true

template handleUserSpreadInput =
  try:
    let digit = k.rune.toUTF8.parseInt
    if digit in 0..9 and digit <= maxSpread: userSpread = digit
  except: 
    if k.button != KeyS: userSpread = 0
  update.spread = true

proc keyboard(k:KeyEvent) = 
  echo k.button
  echo k.rune
  echo "userSpread: ",userSpread
  if gameState == playing: handleUserSpreadInput
  case k.button
  of KeyEnter: enterKeyPressed
  of KeyDown,KeyUp,KeyLeft,KeyRight: arrowPressed
  elif gameState == playing:
    case k.button
    of KeyS: spreadColors
    of KeyF: fillColor
    of KeyL: copyLastLine
    of KeyE: eraseLine
    of KeyD: deleteLine
    of KeyR: removeLocks
    of KeyN: startGameSetup
    of KeyC: combinationReveal
    of KeyT: test
    of KeyTab: tabKeyPressed
    of KeyInsert: insertKeyPressed
    of KeyDelete: deleteKeyPressed
    of KeySpace: spaceKeyPressed
    else: discard

template drawImages(b:var Boxy) =
  b.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))
  b.drawImage(update.colors,cbxf,cbyf,"colorBar",paintColorBar)
  b.drawImage(update.board,bx,by,"board",paintBoard)
  b.drawImage(update.clues,cluesX,by,"clues",paintClues)
  if gameState == playing: 
    b.drawImage("colorCursor",vec2(cbxf,colorY))
    b.drawImage(rowCursorUpdated,rowX,rowY,"rowCursor",paintRowCursor)
  if gameState != setup:
    b.drawImage(update.codeRow,bx,cbyf,"code",paintCodeImage)
    b.drawImage(update.spread,cluesX,cby.toFloat,"spread",paintSpread)
  b.drawImage(update.helpTxt,bx+900,by-100,"helpTxt",paintHelpText)

proc draw(b:var Boxy) =
  var rowCursorUpdated = update.colors
  let 
    rowX = (bx+(game.rowCursorPos*cah)).toFloat
    rowY = (cbb-((game.rowCount+2)*cah)).toFloat
    cluesX = (bx+(game.nrOfColumns*(cah+1))).toFloat
    colorY = (cbb-(game.selectedColor*cah)).toFloat
  b.drawImages

template initMegamind =
  addImage(bg)
  addImage ("colorCursor",paintCursor(rgba(255,255,255,255)))
  addImage ("rowCursor",paintRowCursor())
  addCall(newCall("megamind",keyboard,nil,draw,nil))
  randomize()
  initGame()

initMegamind
setVolume(0.5)
window.visible = true
while not window.closeRequested:
  sleep(30)
  pollEvents()
  #for call in calls.filterIt(it.cycle != nil): call.cycle()
