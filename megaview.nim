import win

let 
  batch = (100,50,1600,850)

func areaShadows(area:Area,offset:int): (Area,Area) =
  ((area.x+area.w,area.y+offset,offset,area.h),
  (area.x+offset,area.y+area.h,area.w-offset,offset))

proc drawAreaShadow(b:var Boxy,area:Area,offset:int,color:Color) =
  let (shadowRight,shadowBottom) = area.areaShadows(offset)
  b.drawRect(shadowRight.toRect,color)
  b.drawRect(shadowBottom.toRect,color)

proc drawBatch(b:var Boxy,area:Area,color:Color) =
  b.drawRect(area.toRect,color)
  b.drawAreaShadow(area,3,color(255,255,255,100))

proc keyboard (k:KeyEvent) =
  if k.button == ButtonUnknown:
    echo "Rune: ",k.rune
  else:
    echo k.button

proc mouse (m:MouseEvent) =
  if mouseClicked(m.keyState):
    echo "ninonav says: hello world"

proc draw (b:var Boxy) =
  b.drawBatch(batch,color(1,1,1))

proc initMegaView*() =
  addCall(newCall("meganav",keyboard,mouse,draw,nil))
