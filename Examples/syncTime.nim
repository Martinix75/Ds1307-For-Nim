import std/[times, strutils]
from strformat import fmt
import serial

let 
  syncTimeVer = "0.1.0"
  #usb = newSerialPort("/dev/ttyACM0") #per ora creiamo la connessine fissa (non si puo scegliere.

proc scrivi(s: string) =
  let usb = newSerialPort("/dev/ttyACM0") #per ora creiamo la connessine fissa (non si puo scegliere.
  var str = newString(1024)
  usb.open(19200, Parity.None, 8, StopBits.One, readTimeout=1000)#setta i parametri per la comunicazione seriale usb.
  discard usb.write(s)
  let ppp =  (usb.read(str)) #deve essereci non so perchè forse aspetta una risposta (anche se non ce).
  usb.close()


echo("---------------------------")
echo(fmt"   syncTime Ver: {syncTimeVer}    ")
echo("---------------------------")
echo()
stdout.write("Vuoi Sincronizzare il dispositivo al Pc Ora? (s/n): ")
let reponse = stdin.readline().toLowerAscii()
if reponse == "s":
  let 
    time = getClockStr()
    data = getDateStr()
    spdata = data.split("-")
    dywe = getDayOfWeek(parseInt(spdata[2]), Month(parseInt(spdata[1])) ,parseInt(spdata[0])).ord()
    dato: string = "#" & time & "#" & data & "#" & $dywe & "#"
  echo(fmt"Stringa ottenuta --> {dato}")
  scrivi(dato)
  
elif reponse == "n":
  echo("Bye!")
else:
  echo("Comando errato!!!!")
