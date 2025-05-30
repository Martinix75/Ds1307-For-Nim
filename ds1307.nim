import picostdlib/hardware/[i2c]
#import std/[strformat]
from std/strformat import fmt
from std/strutils import parseInt, split

let ds1307Ver = "0.7.0" #sovvracarico su setTime() setDate().

type
  Ds1307* = object #creazione oggetto (nello stack).
    ds1307addr: I2cAddress #adess device 0x68.
    blokk: ptr I2cInst #blok device (i2c0 or i2c1).
    rawArrayData: array[8, byte] #contiene i byte grezzi (BCD) ricevuti.
    
  HFormat = enum #enumerazione per formato ora 24h o 12h ver0.4.0
    H12, H24
  HMode = enum #enumerazione Mattino(AM) pomeriggio(PM) ver0.4.0.
    AM, PM
    
# ----- Prototype Procedures ---------
proc initDs1307*(blok: ptr I2cInst; addrDc: uint8=0x68; autoEnable: bool=false): Ds1307 
proc isEnable*(self: Ds1307): bool
proc getFormat*(self: var Ds1307): HFormat
proc getTime*(self: var Ds1307): string
proc getDate*(self: var Ds1307; showDay: bool=true; extYe: bool=false): string
#proc getDate*(self: var Ds1307): string
proc getSeconds*(self: var Ds1307): uint8
proc getMinutes*(self: var Ds1307): uint8
proc getHours*(self:var Ds1307): uint8
proc getPmAm*(self: var Ds1307): HMode
proc getDay*(self: var Ds1307): uint8
proc getMonthDay*(self: var Ds1307): uint8
proc getMonth*(self: var Ds1307): uint8
proc getYear*(self: var Ds1307): uint8

proc setTime*(self: var Ds1307; hours:uint8=0; minutes:uint8=0; seconds: uint8=0; format: HFormat=H24; amPm:HMode=AM; dw: bool= false)
proc setTimeStr*(self: var Ds1307; time: string; dw: bool= false)
proc setDate*(self: var Ds1307; weekDay:uint8=1; monthDay:uint8=1; month:uint8=1; year: uint8=75; dw: bool= false)
proc setDateStr*(self: var Ds1307; date: string; weekDay: uint8; dw: bool=false)
proc setTimeData*(self: var Ds1307; str: string; dw: bool=false)
proc setAmPm*(self: var Ds1307; amPm:HMode=AM; dw: bool= false)
proc setFormat*(self: var Ds1307; format: HFormat=H24; dw: bool= false)
proc setEnable*(self: var Ds1307; enable: bool=true; dw: bool= false)
proc setValues*(self: var Ds1307)
# ++++++++++++++++++++++++++++++++++++
#proc readRegisters(self: Ds1307) {.inline.}
proc readRegisters(self: var Ds1307; register:uint8; numRegRead: uint8) {.inline.}
proc writeRegisters(self: Ds1307; register: uint8; numRegWrite: uint8)  {.inline.}
proc bcdToUint8(self: Ds1307; data: uint8): uint8 {.inline.}
proc uint8ToBCD(self: Ds1307; data: uint8): uint8
proc writeData(self: var Ds1307)
# ----- END Prototype Procedures -----

# ----- Public Procedures ------------
proc initDs1307*(blok: ptr I2cInst; addrDc: uint8=0x68; autoEnable: bool=false): Ds1307 =
  result = Ds1307(blokk: blok, ds1307addr: addrDc.I2cAddress)
  result.readRegisters(0x00, 7)
  if (result.rawArrayData[0] and 0x80) == 0x80 and autoEnable == true:
    echo("Abilito!!")
    result.setEnable(true)

proc isEnable*(self: Ds1307): bool = #ritorna true = enable (conta) fale = disable (non conta).
  if self.rawArrayData[1] shr 7 == 0:
    result = true
  elif self.rawArrayData[1] shr 7 == 1:
    result = false

# ----- Get Values in Register ---------
proc getFormat*(self: var Ds1307): HFormat =
  self.readRegisters(0x02, 1)
  if (self.rawArrayData[3] and 0x40) == 64: #bisogna leggere sul [2] il valore?
    result = H12
  elif (self.rawArrayData[3] and 0x40) == 0: #0 = H24  bit6 basso.
    result = H24 #ora ritorna H24 (prima anche lei H12) ver0.5.0.

proc getTime*(self: var Ds1307): string = #gettime() riscritta ver0.4.2 da la stringa del tempo
  self.readRegisters(0x00, 3)
  let
    seconds: uint8 = self.bcdToUint8(self.rawArrayData[1] and 0x7F) #maschera il 7bit (dei secondi).
    minutes: uint8 = self.bcdToUint8(self.rawArrayData[2]) #i minuti son apposto no maschere.
  var hours: uint8
  if (self.rawArrayData[3] and 0x40) == 0: # siamo in modalita H24!
    hours = self.bcdToUint8(self.rawArrayData[3] and 0x3F)
    result = fmt "{hours:02}:{minutes:02}:{seconds:02}"
  elif (self.rawArrayData[3] and 0x40) == 64: # siamo in modalita H12!
    hours = self.bcdToUint8(self.rawArrayData[3] and 0x1F)
    result = fmt "{hours:02}:{minutes:02}:{seconds:02} {self.getPmAm()}" #<-- evitare questa chiamta a procedura se possibie
    
proc getDate*(self: var Ds1307; showDay: bool=true; extYe: bool=false): string = #ver0.6.2 aggiunto se vedere il giorno o no.data20025/25ver070.
  #echo("Prendo il SOLO la data...")
  self.readRegisters(0x03, 4) #legge dal4 registro (0x03) e tuti i seguenti 3.
  let
    day = self.bcdToUint8(self.rawArrayData[4])
    date = self.bcdToUint8(self.rawArrayData[5])
    month = self.bcdToUint8(self.rawArrayData[6])
    year = if extYe == false: uint(self.bcdToUint8(self.rawArrayData[7])) else: uint(self.bcdToUint8(self.rawArrayData[7])+2000)
    #year = self.bcdToUint8(self.rawArrayData[7])
  if showDay == true:
    result = fmt "{day:02}  {date:02}/{month:02}/{year:02}"
  else:
    result = fmt "{date:02}/{month:02}/{year:02}"

proc getSeconds*(self: var Ds1307): uint8 = #ritorna i secondi (numerico) ver0.2.0.
  self.readRegisters(0x00, 1) #legge il primo registro 0x00 e solo quello (1).
  result = self.rawArrayData[1] and 0x7F #maschero il bit di run.
  result = self.bcdToUint8(result) #torna i secondi in binario (convertiti).

proc getMinutes*(self: var Ds1307): uint8 = #ritorna i minuti (numero) ver0.2.0.
  self.readRegisters(0x01 ,1) #segge il secondo registro (0x01) e solo quello.
  result = self.bcdToUint8(self.rawArrayData[2])

proc getHours*(self: var Ds1307): uint8 = #ritorna le ore (numero) ver0.2.0.
  #self.readData()
  self.readRegisters(0x02, 1)
  if self.getFormat() == H24:
    result = self.rawArrayData[3] and 0x3F #maschero bit am/pm.
  elif self.getFormat() == H12:
    result = self.rawArrayData[3] and 0x1F #maschero bit am/pm maschera anchebit5 Ver0.4.0.
  result = self.bcdToUint8(result)

proc getPmAm*(self: var Ds1307): HMode = #ritorna se AM = 0 Pm = 1 (da valutare se tenere cosi)ver0.2.0.
  self.readRegisters(0x02, 1)
  if ((self.rawArrayData[3] and 0x20) shr 5) == 0:
    result = AM #ver0.5.0. reinvertio AM <-->Pm errore in set.
  elif ((self.rawArrayData[3] and 0x20) shr 5) == 1:
    result = PM #ver0.5.0. reinvertio AM <-->Pm errore in set.

proc getDay*(self: var Ds1307): uint8 = #ritorna il giorno della settimana (1..7) ver0.2.0.
  self.readRegisters(0x03, 1)
  result = self.rawArrayData[4]
  result = self.bcdToUint8(result)

proc getMonthDay*(self: var Ds1307): uint8 = #ritorna il giorno del mese (1..31) ver0.2.0.
  self.readRegisters(0x04, 1)
  result = self.rawArrayData[5]
  result = self.bcdToUint8(result)

proc getMonth*(self: var Ds1307): uint8 = #ritorna il numero del mese (1..12) ver0.2.0.
  self.readRegisters(0x05, 1)
  result = self.rawArrayData[6]
  result = self.bcdToUint8(result)
  
proc getYear*(self: var Ds1307): uint8 = #ritorna le ultime 2 cifre dell'anno (00.99) ver 0.2.0.
  self.readRegisters(0x06, 1)
  result = self.rawArrayData[7]
  result = self.bcdToUint8(result)
  
# ----- END Get Values in Register ---------
# ----- Set Values in Register ---------
proc setTime*(self: var Ds1307; hours:uint8=0; minutes:uint8=0; seconds: uint8=0; format: HFormat=H24; amPm:HMode=AM; dw: bool= false) = #setta l'orario riscritta ver0.5.0.
  #self.setFormat(format)
  self.rawArrayData[1] = self.uint8ToBCD(seconds) and 0x7F #secondi
  self.rawArrayData[2] = self.uint8ToBCD(minutes) #minuti
  if format == H24: #se è mod 24 ore...
    self.rawArrayData[3] = self.uint8ToBCD(hours) #scrivi l'ora in BCD nell'array
    self.setFormat(format) #imposta il formato AM/PM bit6
    #self.setAmPm(amPm) #in questo caso il 5bit serve a dire se è Pm o  Am e va settato (non usato x l'ora).
  elif format == H12: #se è in modalita 12 ore...
    self.rawArrayData[3] = self.uint8ToBCD(hours)#scrivi l'ora in BCD nell'array
    self.setFormat(format)#imposta il formato AM/PM bit6
    self.setAmPm(amPm) #in questo caso il 5bit serve a dire se è Pm o  Am e va settato (non usato x l'ora).
  if dw == true:
    self.writeData()

proc setTimeStr*(self: var Ds1307; time: string; dw: bool= false) = #prende una stringa in formato time (hh:mm::ss).
  var amPm: Hmode
  let
    timeSplit = time.split(":")
    hours = uint8(parseInt(timeSplit[0]))
    minutes = uint8(parseInt(timeSplit[1]))
    seconds = uint8(parseInt(timeSplit[2]))
  self.setTime(hours, minutes, seconds, H24, AM, dw)

proc setDate*(self: var Ds1307; weekDay:uint8=1; monthDay:uint8=1; month:uint8=1; year: uint8=75; dw: bool= false) = #imposta data.
  #self.rawArrayData[0] = self.uint8ToBCD(0.uint8) #vuoto
  #self.rawArrayData[1] = self.rawArrayData[1]
  #self.rawArrayData[2] = self.rawArrayData[2]
  #self.rawArrayData[3] = self.rawArrayData[3]
  self.rawArrayData[4] = self.uint8ToBCD(weekDay) #giorno settimana
  self.rawArrayData[5] = self.uint8ToBCD(monthDay) #giorno del mese
  self.rawArrayData[6] = self.uint8ToBCD(month) #mese
  self.rawArrayData[7] = self.uint8ToBCD(year) #anno
  if dw == true:
    self.writeData()

proc setDateStr*(self: var Ds1307; date: string; weekDay: uint8; dw: bool=false) = #prende uan stringa in formato data (yyyy-mm-dd).
  let 
    dateSplit = date.split("-")
    year = uint8(parseint(dateSplit[0][2..3]))
    month = uint8(parseInt(dateSplit[1]))
    monthDay = uint8(parseInt(dateSplit[2]))
  self.setDate(weekDay, monthDay, month, year, dw)

proc setTimeData*(self: var Ds1307; str: string; dw: bool=false) = #setta tempo e data assieme (#hh:mm:ss#yyyy-MM-dd#dayweek#)var0.6.2
  let splitFields = str.split("#")
  self.setTimeStr(splitFields[1])
  self.setDateStr(splitFields[2], uint8(parseInt(splitFields[3])))
  #self.setDate(splitFields[2], splitFields[3])
  if dw == true:
    self.writeData()

proc setAmPm*(self: var Ds1307; amPm:HMode=AM; dw: bool= false) =
  if amPm == PM: #ver060. invertiti AM <-->PM.
    echo("set PMAM : PM")
    self.rawArrayData[3] = self.rawArrayData[3] or 0x20 #setta AM, a 1  bit5.
  elif amPm == AM: #ver060. invertiti AM <-->PM.
    echo("set PMAM : AM")
    self.rawArrayData[3] = self.rawArrayData[3] and 0x5F #setta PM a 0 bit5.
  if dw == true:
    self.writeData()
    
proc setFormat*(self: var Ds1307; format: HFormat=H24; dw: bool= false) = #seleziona il formato 12/24 ver040.
  if format == H12:
    self.rawArrayData[3] = self.rawArrayData[3] or 0x40 #corretto mette alto bit6.
  elif format == H24:
    self.rawArrayData[3] = self.rawArrayData[3] and 0x3F #corretto mette basso bit6.
  if dw == true:
    self.writeData()

proc setEnable*(self: var Ds1307; enable: bool=true; dw: bool= false) =  #cambio nome Ver0.3.1
  if enable == true:
    self.rawArrayData[1] = self.rawArrayData[1] and 0x7F
    #self.writeRegisters(0x00, 1)
  elif enable == false:
    self.rawArrayData[1] = self.rawArrayData[1] or 0x80
  if dw == true:
    self.writeData()
    #self.writeRegisters(0x00, 1) 

#[proc setTime*(self: var Ds1307; hours:uint8=0; minutes:uint8=0; seconds: uint8=0; amPm:HMode=AM) = #setta l'orario
  #self.rawArrayData[0] = self.uint8ToBCD(0.uint8) #vuoto
  self.rawArrayData[1] = self.uint8ToBCD(seconds) and 0x7F #secondi
  self.rawArrayData[2] = self.uint8ToBCD(minutes) #minuti
  self.rawArrayData[3] = self.uint8ToBCD(hours) #ore
  if amPm == AM:
    self.rawArrayData[3] = self.rawArrayData[3] or 0x20
  elif amPm == PM:
    self.rawArrayData[3] = self.rawArrayData[3] and 0x5F
  self.writeData()
  #self.writeRegisters(0x00, 4)]#

proc setValues*(self: var Ds1307) = #alias per la scrittura ma pubblica.
  self.writeData()

# ----- END Public Procedures --------

# ----- Private Procedures ------------
proc readRegisters(self: var Ds1307; register: uint8; numRegRead: uint8)  {.inline.} = #modificato Ver 0.2.0 ora quanti e quali registri.
  #echo("Vado a leggere  Registri...")
  discard writeBlocking(self.blokk, self.ds1307addr, register.addr, 1, true)
  discard readBlocking(self.blokk, self.ds1307addr, self.rawArrayData[register+1].addr, numRegRead, false)
  #echo("Registri --> ", self.rawArrayData)

proc writeRegisters(self: Ds1307; register: uint8; numRegWrite: uint8)  {.inline.} = #modificato Ver 0.2.0 ora quanti e quali registri.
  echo("Scrivo ", numRegWrite, " Resistri...")
  #let qualcosa: uint8 = 0x00
  #discard writeBlocking(self.blokk, self.ds1307addr, self.rawArrayData[0x00].addr, 1, true)
  discard writeBlocking(self.blokk, self.ds1307addr, self.rawArrayData[register].addr, numRegWrite, false)

proc bcdToUint8(self: Ds1307; data: uint8): uint8  {.inline.} = #converte il dato in bcd in uint8
  let unity: uint8 = data and 0x0F #spezza in due il dato qui parte unità.
  let decim: uint8 = ((data and 0xF0) shr 4)*10 #qui parte decine sposto 4 posizioni e x10.
  result = decim + unity

proc uint8ToBCD(self: Ds1307; data: uint8): uint8 = #conversione bcd in uint8.
  let unity: uint8 = data mod 10 #prende solo la parte delle unita.
  let decim: uint8 = data div 10 #prende la prima cifra e scarta la seconda in caso di 0 div 10 = 0).
  result = (decim shl 4) or unity #spaosta di 4 bit le decine e poi fa Or con le unità

proc writeData(self: var Ds1307) = #scrive i dati sul dispositivo correttamente.
  self.rawArrayData[0] = self.uint8ToBCD(0.uint8) #vuoto
  self.writeRegisters(0x00, 8)

# ----- END Private Procedures ------------

  
when isMainModule:
  import picostdlib
  import picostdlib/pico/[stdio]
  stdioInitAll()
  let 
    sda = 2.Gpio
    scl = 3.Gpio
    blk = i2c1
  
  discard init(blk, 100_000)
  sda.setFunction(I2C); sda.pullUp()
  scl.setFunction(I2C); scl.pullUp()
  
  sleepMs(1500)
  echo("Inizializzo DS1307...")
  echo(fmt"----------> Version Lib = {ds1307Ver} <----------")
  var ds = initDs1307(blk)
  ds.setTime(11,58,12, H12, AM)
  ds.setDate(1,5,11,25)
  #ds.setTime("12:14:33")
  #ds.setDate("2025-05-27", 2)
  ds.setValues()
  #ds.setFormat(H24)
  echo("Raw Reg Init --> ", ds.rawArrayData)
  while true:
    echo(fmt"TIME: {ds.getHours():02}:{ds.getMinutes():02}:{ds.getSeconds():02}")
    echo(fmt"DATE: {ds.getDay()} - {ds.getMonthDay()}/{ds.getMonth()}/{2000 + ds.getYear()}")
    echo(fmt"Format Hours: {ds.getFormat()}")
    echo("-----------------------------------------------")
    echo(fmt"With GetTime(): {ds.getTime()}")
    echo(fmt"With GetDate(): {ds.getDate()}")
    echo("-----------------------------------------------")
    echo("Raw Reg Init --> ", ds.rawArrayData)
    echo("-----------------------------------------------")
    #echo("Seconds: ", ds.getSeconds())
    #echo("Minutes: ", ds.getMinutes())
    #echo("Hours: ", ds.getHours())
    #echo("RawReg--> ", ds.rawArrayData)
    #ds.enableDevice(true)
    sleepMs(500)
