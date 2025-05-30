import picostdlib
import picostdlib/pico/[time]
import picostdlib/hardware/[gpio, i2c]
from std/strformat import fmt
import ds1307
import display1602
import picousb

type 
  Days = enum
    Lun=0, Mar , Mer, Gio, Ven, Sab, Dom
  
#test ds1307 + dislapy 
let timerVer = "0.3.1"
DefaultLedPin.init()
DefaultLedPin.setDir(Out)
stdioInitAll()
let 
  sda = 2.Gpio
  scl = 3.Gpio
  blk = i2c1
  datax = "2025-05-27"
  timex = "1:11:11"

discard init(blk, 100_000)
sda.setFunction(I2C); sda.pullUp()
scl.setFunction(I2C); scl.pullUp()
sleepMs(1500)
var ds = initDs1307(blk)
var lcd = newDisplay(i2c=i2c1, lcdAdd=0x27.uint8, numLines=2, numColum=16)
var usb = PicoUsb()
lcd.centerString("Nim2040 WATCH")
lcd.moveto(0,1)
lcd.centerString(fmt "Ver: {timerVer}")

sleepMs(1500)
if ds.isEnable() == false:
  ds.setTimeStr(timex)
  ds.setDateStr(datax, 2)
  ds.setValues()
  ds.setEnable(true)
while true:
  if usb.isReady(): 
    DefaultLedPin.put(High)
    sleepMs(250)
    DefaultLedPin.put(Low)
    sleepMs(250)
    let dataUsb = usb.readLine()
    ds.setTimeData(dataUsb, true)
  lcd.clear()
  lcd.centerString(fmt"{ds.getTime()}")
  lcd.moveto(0,1)
  let dname = Days(ds.getDay())
  lcd.centerString(fmt"{dname} {ds.getDate(showDay=false, extYe=true)}")
  sleepMs(500)
