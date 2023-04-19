import win

const
  colors = [
    rgba(0,0,0,255),
    rgba(0,0,255,255),rgba(138,43,226,255),rgba(165,42,42,255),rgba(95,158,160,255),
    rgba(127,255,0,255),rgba(210,105,30,255),rgba(100,149,237,255),rgba(220,20,60,255),
    rgba(0,255,255,255),rgba(0,0,139,255),rgba(0,139,139,255),rgba(184,134,11,255),
    rgba(0,100,0,255),rgba(139,0,139,255),rgba(255,140,0,255),rgba(255,20,147,255),
  ]

type 
  ColorBar = tuple[area:Area,colorAreas:array[colors.len,ColorArea]]
  ColorArea = tuple[color:ColorRGBA,area:Area]

const
  minColors = 4
  (cbx,cby,cah) = (100,100,50)
  colorBar = block:
    var bar:ColorBar
    bar.area = (cbx,cby,cah,cah*colors.len)
    for i,color in colors:
      bar.colorAreas[i].area = (0,bar.area.h-(cah*(i+1)),cah,cah)
      bar.colorAreas[i].color = color
    bar

var
  nrOfColors = colors.high
  colorsUpdated = true
  
proc paintColorBar:Image =
  var ctx = newContext(newImage(colorBar.area.w,colorBar.area.h))
  for i,colorArea in colorBar.colorAreas[1..colors.high]:
    ctx.fillStyle = if i >= nrOfColors: rgba(0,0,0,0) else: colorArea.color
    ctx.fillRect(colorArea.area.toRect)
  ctx.image

proc drawColorBar(b:Boxy) =
  if colorsUpdated:
    removeImage("colorBar")
    addImage ("colorBar",paintColorBar())
    colorsUpdated = false
  b.drawImage("colorBar",pos=vec2(colorBar.area.x.toFloat,colorBar.area.y.toFloat))

proc handleColorBarInput(button:Button) =
  case button
  of KeyDown: nrOfColors = if nrOfColors == minColors: colors.high else: nrOfColors-1
  of KeyUp: nrOfColors = if nrOfColors == colors.high: minColors else: nrOfColors+1
  else: discard
  echo "handleColorBar: ",nrOfColors

proc keyboard (k:KeyEvent) =
  if k.button == ButtonUnknown:
    echo "Rune: ",k.rune
  else:
    if k.button in [KeyDown,KeyUp]:
      handleColorBarInput(k.button)
      colorsUpdated = true
    echo k.button

proc draw (b:var Boxy) =
  b.drawColorBar

proc initMegaView*() =
  addCall(newCall("meganav",keyboard,nil,draw,nil))
