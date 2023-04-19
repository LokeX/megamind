import os
import strutils

const 
  earthYearInSeconds = 31557600
  planetYears = [
    ("Mercury",0.2408467),
    ("Venus",0.61519726),
    ("Earth",1.0),
    ("Mars",1.8808158),
    ("Jupiter",11.862615),
    ("Saturn",29.447498),
    ("Uranus",84.016846),
    ("Neptune",164.79132)
  ]

proc secondsInput:float = 
  try: result = paramStr(1).parseFloat except: result = earthYearInSeconds

let ageInSeconds = secondsInput()
for (planet,year) in planetYears:
  echo planet.align(7),": ",
    (ageInSeconds/(year*earthYearInSeconds)).formatFloat(ffDecimal,precision = 4)
