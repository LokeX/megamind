import win
import os
import random
import sequtils
import strutils
import megasound
import sugar
import times

const
  cfgFileName = "megamind.cfg"
  colors = [
    rgba(0,0,0,255),
    rgba(10,50,80,255),rgba(138,100,180,255),rgba(125,80,80,255),rgba(95,120,100,255),
    rgba(127,255,0,255),rgba(210,105,30,255),rgba(100,149,237,255),rgba(220,20,60,255),
    rgba(0,255,255,255),rgba(0,0,139,255),rgba(0,139,139,255),rgba(200,200,0,255),
    rgba(0,150,0,255),rgba(170,0,220,255),rgba(255,140,100,255),rgba(255,20,147,255),
  ]
  nrOfBoardRows = 14
  maxColumns = 10
  minColumns = 4
  minColors = 4

type 
  ColorBar = array[colors.len,Area]
  BoardRow = array[maxColumns,int]
  Board = array[nrOfBoardRows,BoardRow]
  Locks = array[maxColumns,bool]
  Clue = enum none,match,present,notPresent
  CluesRow = array[maxColumns,Clue]
  Clues = array[nrOfBoardRows,CluesRow]
  Update = tuple[codeRow,clues,board,colors,helpTxt,status,setup:bool]
  Game = tuple[nrOfColumns,nrOfColors,selectedColor,rowCursorPos,rowCount,seconds:int]
  GameState = enum setup,won,lost,playing
  SavedGame = tuple[board:Board,clues:Clues,game:Game]

const 
  (cbx,cby,cah) = (100,100,50)
  cbb = cby+(colors.high*cah)
  by = cby+((colors.high-nrOfBoardRows)*cah)
  bx = cbx+(cah*2)
  (cbxf,cbyf) = (cbx.toFloat,cby.toFloat)
  colorBar = block:
    var bar:ColorBar
    let height = cah*colors.high
    for i in 0..colors.high:
      bar[i] = (0,height-(cah*(i+1)),cah,cah)
    bar

proc paintHelpText(filename:string):Image
proc newFont(typeface: Typeface, size: float32, color: Color): Font

let 
  typeface = readTypeface("fonts\\Roboto-Regular_1.ttf")
  bg = ("bg", readImage("bgblue.png"))
  font = newFont(typeface, 20, color(1, 1, 1, 1))
  keyFont = newFont(typeface, 20, color(0, 1, 0, 1))
  headerFont = newFont(typeface, 24, color(1, 1, 0, 1))
  setupTxt = paintHelpText("setup")
  playTxt = paintHelpText("play")
  wonTxt = paintHelpText("won")
  lostTxt = paintHelpText("lost")

var
  game:Game = (minColumns,colors.high,1,0,0,0)
  update:Update = (true,true,true,true,true,true,true)
  clues:Clues
  codeRow:BoardRow
  board:Board
  locks:Locks
  gameState:GameState
  savedGame:SavedGame
  userSpread:int
  hasSavedGame:bool

proc gameOver:bool = gameState in [won,lost]

template gameWon:bool = codeRow == board[game.rowCount]

proc updateImages(b:openArray[string]) =
  for a,c in update.fieldPairs:
    when c is bool:
      if a in b: c = true

func cluesRowFromCounts(clueCounts:openArray[int]):CluesRow =
  var cluesRowIdx = 0
  for clueCountsIdx,clueCount in clueCounts:
    for _ in 1..clueCount: 
      result[cluesRowIdx] = Clue(clueCountsIdx+1)
      inc cluesRowIdx

template countUserColorClues =
  let codeRowUserColorCount = codeRow.count(userColor)
  if codeRowUserColorCount > 0: 
    let 
      userColorCount = min(
        codeRowUserColorCount,
        board[game.rowCount].count(userColor)
      )
      nrOfMatches = zip(codeRow,userRow)
        .countIt(it[0] == userColor and it[1] == userColor)
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

proc generateCluesRow(userRow:BoardRow):CluesRow = 
  userRow.clueCounts.cluesRowFromCounts

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
    # ctx.fillStyle = colors[colorIdx]
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
      ctx.fillRoundedRect(((x*cah)+2,height-((y+1)*cah)+2,cah-4,cah-4).toRect,5)
      if y == game.rowCount and locks[x]:
        ctx.fillStyle = rgba(0,0,0,150)
        ctx.fillRoundedRect(
          ((x*cah)+10,10+height-((y+1)*cah),cah-20,cah-20).toRect,50)
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
      ctx.fillRoundedRect(
        (x*(cah div 2)+2,height-((y+1)*cah)+2,(cah div 2)-4,cah-4).toRect,50)
  ctx.image

proc newFont(typeface: Typeface, size: float32, color: Color): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color

proc paintSetup:Image =
  let text = "Columns: " & $game.nrOfColumns & ", Colors: " & $game.nrOfColors
  result = newImage(300,cah)
  result.fill(rgba(0, 0, 0, 255))
  result.fillText(font.typeset(text),translate(vec2(20,12)))

template msFormat(ms:int):string =
  if ms < 10: "0"&ms.intToStr else: ms.intToStr

template toMs(seconds:int):string =
  msFormat((seconds div 60) mod 60)&":"&msFormat(seconds mod 60)

proc currentSpreadColorCount:int
proc paintStatus:Image =
  let 
    width = game.nrOfColumns*(cah div 2)
    text = 
      "T = "&game.seconds.toMs&
      "\nS = " & $currentSpreadColorCount()&
      "\nR = " & $(game.rowCount+1)
    xMargin = 8.0
  result = newImage(width,95)
  result.fill(rgba(0, 0, 0, 255))
  result.fillText(font.typeset(text),translate(vec2(xMargin,13)))

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
    elif line.startsWith("|"):
      let t = line.split("|")
      spans.add newSpan(t[^2],keyFont)
      spans.add newSpan(t[^1]&"\n",font)
    else: spans.add newSpan(line&"\n",font)
  spans

proc paintHelpText(filename:string):Image =
  result = newImage(700, 800)
  result.fill(rgba(0, 0, 0, 255))
  result.fillText(typeset(helpText,vec2(700,780)),translate(vec2(20,10)))

proc paintHelpText:Image = 
  case gameState
  of setup: setupTxt
  of playing: playTxt
  of lost: lostTxt
  of won: wonTxt

proc drawImage(b:var Boxy,update:var bool,x,y:float,name:string,image:() -> Image) =
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

template arrowPressed =
  update.colors = k.button in [KeyDown,KeyUp]
  update.board = not update.colors
  update.clues = update.board
  update.setup = true
  let step = if k.button in [KeyDown,KeyLeft]: -1 else: 1
  if gameState == setup: switchOn(game.nrOfColors,game.nrOfColumns,
    (minColors,colors.high,step),(minColumns,board[0].len,step))
  elif gameState == playing: switchOn(game.selectedColor,game.rowCursorPos,
    (1,game.nrOfColors,step),(0,game.nrOfColumns-1,step))

func calcSpreadEntries(nrOfColumns,nrOfColors:int):seq[int] =
  countup(1,nrOfColors,nrOfColumns).toSeq

template calcDefaultSpreadEntries:seq[int] =
  calcSpreadEntries(game.nrOfColumns,game.nrOfColors)

template spreadColorEntries(entries:seq[int]):seq[seq[int]] = 
  collect:
    for i in 0..entries.high: 
      toSeq(entries[i]..<(if i < entries.high: entries[i+1] else: game.nrOfColors+1))
 
template codeProposal:BoardRow =
  var 
    code:BoardRow
    columns = 0..<game.nrOfColumns
  while code[columns].count(0) > 0:
    code[rand(columns)] = (rand(1000*(game.nrOfColors-1)) div 1000)+1
  code

template generateCodeRow = 
  let colorEntries = calcDefaultSpreadEntries.spreadColorEntries
  while not colorEntries.allIt it.anyIt it in codeRow: 
    codeRow = codeProposal

template init[T](t:var T) = t = default typeof T

template startNewGame =
  init codeRow; init locks
  generateCodeRow
  game.selectedColor = 1
  game.rowCount = 0
  game.rowCursorPos = 0
  game.seconds = 0
  updateImages ["status","codeRow","colors","helpTxt"]
  hasSavedGame = false
  gameState = playing
  playSound("Blop-Mark_DiAngelo")

template repeatRow:bool = 
  game.rowCount > 0 and board.countIt(it == board[game.rowCount]) > 1

template rowFilled:bool = board[game.rowCount].countIt(it != 0) == game.nrOfColumns

template newRow = 
  if rowFilled and not repeatRow:
    clues[game.rowCount] = board[game.rowCount].generateCluesRow
    inc game.rowCount
    for pos in 0..<game.nrOfColumns:
      if locks[pos]: board[game.rowCount][pos] = board[game.rowCount-1][pos]
    game.rowCursorPos = 0
    updateImages ["clues","status"]
    playSound("Blop-Mark_DiAngelo")

proc wonOrLost(state:GameState,sound:string) =
  clues[game.rowCount] = board[game.rowCount].generateCluesRow
  gameState = state
  updateImages ["clues","codeRow","helpTxt"]
  playSound(sound)

template startGameSetup =
  init clues; init board
  updateImages ["board","clues","helpTxt","setup"]
  gameState = setup
  playSound("Blop-Mark_DiAngelo")

template inGameSetup =
  if gameState == setup and hasSavedGame:
    (board,clues,game) = savedGame
    update = (true,true,true,true,true,true,true)
    gameState = playing
    hasSavedGame = false
  elif gameState == playing:
    savedGame = (board,clues,game)
    startGameSetup
    hasSavedGame = true

template enterKeyPressed =
  update.board = true
  if gameOver():
    startGameSetup
  elif gameState == setup:
    startNewGame
  elif gameWon():
    wonOrLost(won,"applause-2")
  elif game.rowCount < nrOfBoardRows-1:
    newRow
  else: wonOrLost(lost,"sad-trombone")

proc availableColumns:int =
  board[game.rowCount][game.rowCursorPos..<game.nrOfColumns].count(0)

proc availableColors:int = game.nrOfColors-game.selectedColor+1

proc maxSpread:int = min(availableColors(),availableColumns())

proc colorRepeat:int =
  let 
    nrOfColumns = availableColumns()
    nrOfColors = if userSpread > 0: userSpread else: availableColors()
  if nrOfColors >= nrOfColumns: 1 else:
    let repeat = nrOfColumns div nrOfColors
    if nrOfColumns mod ((nrOfColors-1)*(repeat+1)) == 1: repeat+1 else: repeat
 
proc currentSpreadColorCount:int =
  if userSpread > 0: userSpread else: maxSpread()

template spreadColors =
  let 
    repeat = colorRepeat()
    maxColors = currentSpreadColorCount()
    startColor = game.selectedColor
  var count = 0
  for pos in game.rowCursorPos..<game.nrOfColumns:
    if board[game.rowCount][pos] == 0:
      board[game.rowCount][pos] = game.selectedColor
      inc count
    if count == repeat and game.selectedColor-startColor+1 < maxColors:
      inc game.selectedColor
      count = 0
  if count > 0: inc game.selectedColor
  if game.selectedColor > game.nrOfColors: game.selectedColor = 1
  updateImages ["status","board","colors"]
  userSpread = 0

template fillColor =
  let inputColor = board[game.rowCount][game.rowCursorPos]
  for pos in game.rowCursorPos..<game.nrOfColumns:
    if board[game.rowCount][pos] == inputColor and not locks[pos]:
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
  update.colors = true

template deleteKeyPressed =
  board[game.rowCount][game.rowCursorPos] = 0
  locks[game.rowCursorPos] = false
  update.board = true

template backSpaceKeyPressed =
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
    if not locks[pos]: board[game.rowCount][pos] = 0
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
  if k.pressed.ctrl:
    gameState = lost
    updateImages ["helpTxt","codeRow"]
    playSound("sad-trombone")

template handleUserSpreadInput =
  if k.button == ButtonUnknown and gameState == playing: 
    try:
      let digit = k.rune.toUTF8.parseInt
      if digit in 0..9 and digit <= maxSpread(): userSpread = digit
    except: 
      if k.button != KeyS: userSpread = 0
    update.status = true

template tabKeyPressed =
  let replaceColor = board[game.rowCount][game.rowCursorPos]
  for i in 0..<game.nrOfColumns:
    if board[game.rowCount][i] == replaceColor and not locks[i]:
      board[game.rowCount][i] = game.selectedColor
  update.board = true

template pageUpDown =
  let 
    spreadEntries = calcDefaultSpreadEntries()
    pageUp = k.button == KeyPageUp or k.button == KeyUp
    indexes = spreadEntries.filterIt(
      if pageUp: it > game.selectedColor else: it < game.selectedColor)
  game.selectedColor = 
    if indexes.len > 0: 
      if pageUp: indexes.min else: indexes.max 
    elif pageUp: 1 else: spreadEntries[^1]
  update.colors = true

proc inputColor(pos:int):int =
  # update.board = true
  if board[game.rowCount][pos] == 0 and game.rowCount > 0:
    board[game.rowCount-1][pos]
  else:
    board[game.rowCount][pos]

proc rowPositions(button:Button):seq[int] =
  if button in [KeyLeft,KeyHome]: 
    toSeq 0..<game.rowCursorPos
  else: 
    toSeq game.rowCursorPos+1..<game.nrOfColumns

proc moveRowCursor(button:Button,positions:openArray[int]) =
  if positions.len > 0:
      game.rowCursorPos = if button in [KeyLeft,KeyHome]: positions.max else: positions.min

proc moveToColorBlockPositions(button:Button) =
  let 
    row = board[game.rowCount]
    positions = button.rowPositions.filterIt it == 0 or row[it-1] != row[it]
  moveRowCursor(button,positions)

proc moveToColor(button:Button,color:int) =
  let positions = button.rowPositions.filterIt(inputColor(it) == color)
  moveRowCursor(button,positions)

proc homeEndKeyPressed(button:Button) =
  let 
    row = board[game.rowCount]
    positions = button.rowPositions.filterIt it == 0 or (row[it] == 0 and row[it-1] != 0)
  moveRowCursor(button,positions)
  update.colors = true

template handleArrowPressed =
  if k.pressed.ctrl or k.pressed.shift or k.pressed.alt:
    case k.button:
      of KeyLeft,KeyRight:
        if k.pressed.shift: moveToColor k.button,inputColor(game.rowCursorPos) 
        if k.pressed.alt: moveToColor k.button,game.selectedColor
        if k.pressed.ctrl: k.button.moveToColorBlockPositions
      of KeyUp,KeyDown:
        if k.pressed.ctrl: pageUpDown
      else: discard
  else: arrowPressed

proc deleteColor(color:int) =
  for pos in 0..<game.nrOfColumns:
    if not locks[pos] and board[game.rowCount][pos] == color:
      board[game.rowCount][pos] = 0
  update.board = true

template handleDeleteKey =
  if k.pressed.ctrl: 
    deleteColor(game.selectedColor) 
  elif k.pressed.shift:
    deleteColor(inputColor(game.rowCursorPos))
  else: deleteKeyPressed

template gotAllPresentColors:bool =
  clues.mapIt(it.countIt it == present or it == match).sum == game.nrOfColumns

template spreadAllColors =
  if game.rowCount == 0 and board[game.rowCount].countIt(it != 0) == 0:
    userSpread = 0
    game.rowCursorPos = 0
    game.selectedColor = 1
    spreadColors
    enterKeyPressed
    while game.selectedColor != 1 and not gotAllPresentColors:
      spreadColors
      enterKeyPressed
    game.selectedColor = 1

template ctrlHomePressed =
  if game.rowCursorPos > 0:
    for pos in 0..game.rowCursorPos-1:
      if board[game.rowCount][pos] == 0:
        game.rowCursorPos = pos
        break

template handleHomeKeyPressed =
  if k.pressed.ctrl: ctrlHomePressed else: homeEndKeyPressed(k.button)

template invertLocks =
  for pos in 0..<game.nrOfColumns: 
    locks[pos] = board[game.rowCount][pos] > 0 and not locks[pos]
  update.board = true

template handleGameToolKeys =
  case k.button:
    of KeyS: spreadColors
    of KeyF: fillColor
    of KeyL: copyLastLine
    of KeyE: eraseLine
    of KeyD: deleteLine
    of KeyR: removeLocks
    of KeyC: combinationReveal
    of KeyA: spreadAllColors
    of KeyI: invertLocks
    of KeyPageUp,KeyPageDown: pageUpDown
    of KeyEscape: startGameSetup
    of KeyTab: tabKeyPressed
    of KeyHome: handleHomeKeyPressed
    of KeyEnd: homeEndKeyPressed(k.button)
    of KeyBackspace: backSpaceKeyPressed
    of KeyInsert: insertKeyPressed
    of KeyDelete: handleDeleteKey
    of KeySpace: spaceKeyPressed
    else: discard

proc keyboard(k:KeyEvent) = 
  # echo k.button
  # echo k.pressed
  # echo k.keyState
  # echo k.rune
  handleUserSpreadInput
  if k.keyState.down:
    case k.button:
      of KeyEnter: enterKeyPressed
      of KeyDown,KeyUp,KeyLeft,KeyRight: handleArrowPressed
      of KeyQ: window.closeRequested = k.pressed.ctrl
      of KeyEscape: inGameSetup
      elif gameState == playing: handleGameToolKeys
      else:discard

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
    b.drawImage(update.status,cluesX,cbyf,"spread",paintStatus)
  else:
    b.drawImage(update.setup,bx,cbyf,"setup",paintSetup)
  b.drawImage(update.helpTxt,bx+900,by-100,"helpTxt",paintHelpText)

proc draw(b:var Boxy) =
  var rowCursorUpdated = update.colors
  let 
    rowX = (bx+(game.rowCursorPos*cah)).toFloat
    rowY = (cbb-((game.rowCount+2)*cah)).toFloat
    cluesX = (bx+(game.nrOfColumns*(cah+1))).toFloat
    colorY = (cbb-(game.selectedColor*cah)).toFloat
  b.drawImages

template writeCfgFile(path:string) =
  let settings = [
    ("nrOfColumns",game.nrOfColumns),
    ("nrOfColors",game.nrOfColors)
  ]
  writeFile(path,settings.mapIt(it[0]&" = " & $it[1]).join "\n")

template setFieldValue(settingName:string,settingValue:int) =
  for fieldName,fieldValue in game.fieldPairs: 
    if fieldName.toLower.contains(settingName.toLower):
      fieldValue = settingValue

template parseAndSet(cfgLine:string) =
  let setting = cfgLine.split({'=',' '}).filterIt(it.len > 0)
  try: setFieldValue(setting[0],setting[1].parseInt) except: discard

template readCfgFile(path:string) =
  if fileExists(path):
    for cfgLine in readFile(path).splitLines: 
      parseAndSet cfgLine

proc timer =
  if gameState == playing and game.seconds < 3600:
    game.seconds += 1
    update.status = true

template timerCall:TimerCall =
  TimerCall(call:timer,lastTime:cpuTime(),secs:1)

proc quitMegamind =
  closeSound()
  writeCfgFile cfgFileName

template initMegamind =
  addImage bg
  addImage ("colorCursor",paintCursor rgba(255,255,255,255))
  addImage ("rowCursor",paintRowCursor())
  addCall newCall("megamind",keyboard,nil,draw,nil,timerCall)
  randomize()
  readCfgFile cfgFileName
  setVolume 0.5
  window.title = "Megamind v1.0"
  window.visible = true
  window.onCloseRequest = quitMegamind

initMegamind
while not window.closeRequested:
  sleep 30
  pollEvents()
  runCyclesAndtimers()
