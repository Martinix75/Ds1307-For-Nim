import std/[times, strutils,os]
from strformat import fmt
import serial

let 
  syncTimeVer = "0.1.1"
  #usb = newSerialPort("/dev/ttyACM0") #per ora creiamo la connessine fissa (non si puo scegliere.

proc scrivi(s: string) =
  let usb = newSerialPort("/dev/ttyACM0") #per ora creiamo la connessine fissa (non si puo scegliere.
  var str = newString(1024)
  usb.open(19200, Parity.None, 8, StopBits.One, readTimeout=10)#setta i parametri per la comunicazione seriale usb.
  discard usb.write(s)
  sleep(100)
  #let ppp =  (usb.read(str)) #deve essereci non so perchè forse aspetta una risposta (anche se non ce).
  usb.close()


echo("---------------------------")
echo(fmt"   syncTime Ver: {syncTimeVer}    ")
echo("---------------------------")
echo()
stdout.write("Do you want to synchronize your watch with that of your PC? (y/n): ")
let reponse = stdin.readline().toLowerAscii()
if reponse == "y":
  let 
    time = getClockStr()
    data = getDateStr()
    spdata = data.split("-")
    dywe = getDayOfWeek(parseInt(spdata[2]), Month(parseInt(spdata[1])) ,parseInt(spdata[0])).ord()
    dato: string = "#" & time & "#" & data & "#" & $dywe & "#"
  echo(fmt"String Obtained --> {dato}")
  scrivi(dato)
  
elif reponse == "n":
  echo("Bye!")
else:
  echo("Incorrect Command!!!!")
