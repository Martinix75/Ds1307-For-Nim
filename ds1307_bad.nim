import picostdlib
import picostdlib/pico/[stdio]
import picostdlib/hardware/[i2c]
import std/[strformat]

let ds1307Ver = "0.4.0" #miglioramenti se possibile

type
  Ds1307* = object #creazione oggetto (nello stack).
    ds1307addr: I2cAddress #adess device 0x68.
    blokk: ptr I2cInst #blok device (i2c0 or i2c1).
    #seconds: uint8 #1..59.
    #minutes: uint8 #1..59.
    #hours: uint8 #1..12 or 00..23.
    #day: uint8 #1..7.
    #date: uint8 #1..31.
    #month: uint8 #1..12.
    #year: uint8 #00..99.
    rawArrayRead: array[10, byte] #contiene i byte grezzi (BCD) ricevuti.
    #rawArrayWrite: array[8, byte] #contiene i byte grezzi (BCD) rda scrivere.
    
  HFormat* = enum #enumerazione formato ore ver0.4.0
    H12, H24
  
  CazzodiNome* = enum # indica se siamo in AM (mattina) o PM (pomeriggio.) ver0.4.0.
    AM, PM
    
# ----- Prototype Procedures ---------
proc initDs1307*(blok: ptr I2cInst; addrDc: uint8 = 0x68): Ds1307
proc isEnable*(self: Ds1307): bool
proc getFormat*(self: Ds1307): HFormat
proc getTime*(self: Ds1307): string
proc getDate*(self: Ds1307): string
proc getSeconds*(self: Ds1307): uint8
proc getMinutes*(self: Ds1307): uint8
proc getHours*(self:Ds1307): uint8
proc getPmAm*(self: Ds1307): CazzodiNome
proc getDay*(self: Ds1307): uint8
proc getMonthDay*(self: Ds1307): uint8
proc getMonth*(self: Ds1307): uint8
proc getYear*(self: Ds1307): uint8

proc setFormat*(self: var Ds1307; format: HFormat=H24)
proc setEnable*(self: var Ds1307; enable: bool=true)
proc setTime*(self: var Ds1307; hours:uint8=0; minutes:uint8=0; seconds: uint8=0; amPm:CazzodiNome=AM)
proc setDate*(self: var Ds1307; weekDay:uint8=1; monthDay:uint8=1; month:uint8=1; year: uint8=75)
# ++++++++++++++++++++++++++++++++++++
#proc readRegisters(self: Ds1307) {.inline.}
proc readRegisters(self: Ds1307; register:uint8; numRegRead: uint8)  {.inline.}
proc writeRegisters(self: Ds1307; register: uint8; numRegWrite: uint8)  {.inline.}
proc bcdToUint8(self: Ds1307; data: uint8): uint8 {.inline.}
proc uint8ToBCD(self: Ds1307; data: uint8): uint8
proc writeData(self: var Ds1307)
# ----- END Prototype Procedures -----

# ----- Public Procedures ------------
proc initDs1307*(blok: ptr I2cInst; addrDc: uint8=0x68): Ds1307 =
  result = Ds1307(blokk: blok, ds1307addr: addrDc.I2cAddress)
  result.readRegisters(0x00, 7)
  result.rawArrayRead[0] = 0x00 #assegno il valore 0x00 al primo elemento (per essere sicurissimo).
  if (result.rawArrayRead[0] and 0x80) == 0x80:
    echo("Abilito!!")
    result.setEnable(true)

proc isEnable*(self: Ds1307): bool = #ritorna true = enable (conta) fale = disable (non conta).
  if self.rawArrayRead[0] shr 7 == 0:
    result = true
  elif self.rawArrayRead[0] shr 7 == 1:
    result = false

# ----- Get Values in Register ---------
proc getFormat*(self: Ds1307): HFormat =
  self.readRegisters(0x02, 1)
  #echo("cazzo leggo reg3: ",self.rawArrayRead[2])
  if (self.rawArrayRead[2] and 0x40) == 64: #bisogna leggere sul [2] valore ??
    result = H12
  elif (self.rawArrayRead[2] and 0x40) == 0:
    result = H24

proc getTime*(self: Ds1307): string =
  #echo("Prendo il SOLO il tempo...")
  self.readRegisters(0x00, 3)
  var 
    hours:uint8
    amPm: CazzodiNome
  let
    seconds = self.bcdToUint8(self.rawArrayRead[0] and 0x7F) #maschero il bit 7 per precauzione run device.
    minutes = self.bcdToUint8(self.rawArrayRead[1])
  #[if self.getFormat() == H24:
    hours = self.bcdToUint8(self.rawArrayRead[2] and 0x3F) #maschero il bit 6 rileva se 0..23 o 0..12ampm (BUG1).
  elif self.getFormat() == H12:
    hours = self.bcdToUint8(self.rawArrayRead[2] and 0x1F) #maschero il bit 6 rileva se 0..23 o 0..12ampm (BUG1).]#
  #[if ((self.rawArrayRead[2] and 0x20) shr 5) == 0:
    amPm = AM
  elif ((self.rawArrayRead[2] and 0x20) shr 5) == 1:
    amPm = PM]#
  if (self.rawArrayRead[2] and 0x40) == 0x40: #modalita 12 ore
    result = fmt "{hours:02}:{minutes:02}:{seconds:02} {amPm}"
  else: #modalita 24 ore
    result = fmt "{hours:02}:{minutes:02}:{seconds:02}"

proc getDate*(self: Ds1307): string =
  #echo("Prendo il SOLO la data...")
  self.readRegisters(0x03, 4) #legge dal4 registro (0x03) e tuti i seguenti 3.
  let day = self.bcdToUint8(self.rawArrayRead[3])
  let date = self.bcdToUint8(self.rawArrayRead[4])
  let month = self.bcdToUint8(self.rawArrayRead[5])
  let year = self.bcdToUint8(self.rawArrayRead[6])
  result = fmt "{day:02}/{date:02}/{month:02}/{year:02}"

proc getSeconds*(self: Ds1307): uint8 = #ritorna i secondi (numerico) ver0.2.0.
  self.readRegisters(0x00, 1) #legge il primo registro 0x00 e solo quello (1).
  result = self.rawArrayRead[0] and 0x7F #maschero il bit di run.
  result = self.bcdToUint8(result) #torna i secondi in binario (convertiti).

proc getMinutes*(self: Ds1307): uint8 = #ritorna i minuti (numero) ver0.2.0.
  self.readRegisters(0x01 ,1) #segge il secondo registro (0x01) e solo quello.
  result = self.bcdToUint8(self.rawArrayRead[1])

proc getHours*(self:Ds1307): uint8 = #ritorna le ore (numero) ver0.2.0.
  self.readRegisters(0x02, 1)
  if self.getFormat() == H24:
    result = self.rawArrayRead[2] and 0x3F #maschero bit am/pm.
  elif self.getFormat() == H12:
    result = self.rawArrayRead[2] and 0x1F #maschero bit am/pm machera anche il bit 5 in qeusto caso non serve Ver040.
  result = self.bcdToUint8(result)

proc getPmAm*(self: Ds1307): CazzodiNome = #ritorna se AM = 0 Pm = 1 (da valutare se tenere cosi)ver0.2.0.
  self.readRegisters(0x02, 1)
  if ((self.rawArrayRead[2] and 0x20) shr 5) == 0:
    result =  AM
  elif ((self.rawArrayRead[2] and 0x20) shr 5) == 1:
    result = PM
  #result = self.bcdToUint8(result)

proc getDay*(self: Ds1307): uint8 = #ritorna il giorno della settimana (1..7) ver0.2.0.
  self.readRegisters(0x03, 1)
  result = self.rawArrayRead[3]
  result = self.bcdToUint8(result)

proc getMonthDay*(self: Ds1307): uint8 = #ritorna il giorno del mese (1..31) ver0.2.0.
  self.readRegisters(0x04, 1)
  result = self.rawArrayRead[4]
  result = self.bcdToUint8(result)

proc getMonth*(self: Ds1307): uint8 = #ritorna il numero del mese (1..12) ver0.2.0.
  self.readRegisters(0x05, 1)
  result = self.rawArrayRead[5]
  result = self.bcdToUint8(result)
  
proc getYear*(self: Ds1307): uint8 = #ritorna le ultime 2 cifre dell'anno (00.99) ver 0.2.0.
  self.readRegisters(0x06, 1)
  result = self.rawArrayRead[6]
  result = self.bcdToUint8(result)
  
# ----- END Get Values in Register ---------
# ----- Set Values in Register ---------
proc setEnable*(self: var Ds1307; enable: bool=true) =  #cambio nome Ver0.3.1
  if enable == true:
    self.rawArrayRead[0] = self.rawArrayRead[0] and 0x7F
    self.writeRegisters(0x00, 1)
  elif enable == false:
    self.rawArrayRead[0] = self.rawArrayRead[0] or 0x80
    self.writeRegisters(0x00, 1) 
  
proc setFormat*(self: var Ds1307; format: HFormat=H24) = #seleziona il formato 12/24.funge
  if format == H12:
    self.rawArrayRead[3] = self.rawArrayRead[3] or 0x40
    self.writeData()
  elif format == H24:
    self.rawArrayRead[3] = self.rawArrayRead[3] and 0x3F
    self.writeData()
  
proc setTime*(self: var Ds1307; hours:uint8=0; minutes:uint8=0; seconds: uint8=0; amPm:CazzodiNome=AM) = #setta l'orario aggiuntoamapVer0.4.0.
  self.rawArrayRead[1] = self.uint8ToBCD(seconds) and 0x7F #secondi
  self.rawArrayRead[2] = self.uint8ToBCD(minutes) #minuti
  self.rawArrayRead[3] = self.uint8ToBCD(hours) #ore
  if amPm == AM:
    self.rawArrayRead[3] = (self.rawArrayRead[3] or 0x20)
  elif amPm == PM:
    self.rawArrayRead[3] = (self.rawArrayRead[3] and 0x5F)
  self.writeData()

proc setDate*(self: var Ds1307; weekDay:uint8=1; monthDay:uint8=1; month:uint8=1; year: uint8=75) = #imposta data.
  self.rawArrayRead[4] = self.uint8ToBCD(weekDay) #giorno settimana
  self.rawArrayRead[5] = self.uint8ToBCD(monthDay) #giorno del mese
  self.rawArrayRead[6] = self.uint8ToBCD(month) #mese
  self.rawArrayRead[7] = self.uint8ToBCD(year) #anno
  self.writeData()

proc writeData(self: var Ds1307) = #scrive i dati sul dispositivo correttamente.
  #self.rawArrayRead[0] = self.uint8ToBCD(0.uint8) #vuoto =0x00
  self.rawArrayRead[1] = self.rawArrayRead[1] #sec
  self.rawArrayRead[2] = self.rawArrayRead[2] #min
  self.rawArrayRead[3] = self.rawArrayRead[3] #ore
  self.rawArrayRead[4] = self.rawArrayRead[4]
  self.rawArrayRead[5] = self.rawArrayRead[5]
  self.rawArrayRead[6] = self.rawArrayRead[6]
  self.rawArrayRead[7] = self.rawArrayRead[7]
  self.writeRegisters(0x00, 8)
  
#[proc setT(self: var Ds1307) = #solo x test
  self.rawArrayRead[0] = self.uint8ToBCD(0.uint8) #vuoto
  self.rawArrayRead[1] = self.uint8ToBCD(50.uint8) and 0x7F #secondi
  self.rawArrayRead[2] = self.uint8ToBCD(11.uint8) #minuti
  self.rawArrayRead[3] = self.uint8ToBCD(14.uint8) #ore
  self.rawArrayRead[4] = self.uint8ToBCD(2.uint8) #giorno settimana
  self.rawArrayRead[5] = self.uint8ToBCD(20.uint8) #giorno del mese
  self.rawArrayRead[6] = self.uint8ToBCD(5.uint8) #mese
  self.rawArrayRead[7] = self.uint8ToBCD(25.uint8) #anno
  
  self.writeRegisters(0x00, 8)
  echo("Registro rawWrite:")
  for i in 0..6:
    echo(self.bcdToUint8(self.rawArrayRead[i]))]#
    
# ----- END Public Procedures --------

# ----- Private Procedures ------------
proc readRegisters(self: Ds1307; register: uint8; numRegRead: uint8)  {.inline.} = #modificato Ver 0.2.0 ora quanti e quali registri.
  #echo("Vado a leggere  Registri...")
  #let qualcosa: uint8 = 0x00
  discard writeBlocking(self.blokk, self.ds1307addr, register.addr, 1, true)
  discard readBlocking(self.blokk, self.ds1307addr, self.rawArrayRead[register].addr, numRegRead, false)
  #echo("Registri --> ", self.rawArrayRead)

proc writeRegisters(self: Ds1307; register: uint8; numRegWrite: uint8)  {.inline.} = #modificato Ver 0.2.0 ora quanti e quali registri.
  echo("Scrivo ", numRegWrite, " Resistri...")
  let qualcosa: uint8 = 0x00
  #discard writeBlocking(self.blokk, self.ds1307addr, qualcosa.addr, 1, true)
  discard writeBlocking(self.blokk, self.ds1307addr, self.rawArrayRead[register].addr, numRegWrite, false)

proc bcdToUint8(self: Ds1307; data: uint8): uint8  {.inline.} = #converte il dato in bcd in uint8
  let unity: uint8 = data and 0x0F #spezza in due il dato qui parte unità.
  let decim: uint8 = ((data and 0xF0) shr 4)*10 #qui parte decine sposto 4 posizioni e x10.
  result = decim + unity

proc uint8ToBCD(self: Ds1307; data: uint8): uint8 = #conversione bcd in uint8.
  let unity: uint8 = data mod 10 #prende solo la parte delle unita.
  let decim: uint8 = data div 10 #prende la prima cifra e scarta la seconda in caso di 0 div 10 = 0).
  result = (decim shl 4) or unity #spaosta di 4 bit le decine e poi fa Or con le unità
  
# ----- END Private Procedures ------------

  
when isMainModule:
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
  var ds = initDs1307(blk)
  
  ds.setTime(10,15,30, AM)
  ds.setDate(1,5,11,25)
  ds.setFormat(H12)
  echo("RawRegInit--> ", ds.rawArrayRead)
  while true:
    echo(fmt"TIME: {ds.getHours:02}:{ds.getMinutes:02}:{ds.getSeconds:02}")
    echo(fmt"DATE: {ds.getDay} - {ds.getMonthDay}/{ds.getMonth}/{2000 + ds.getYear}")
    echo(fmt" Formato ore: {ds.getFormat}")
    echo("----------------------------------------")
    echo(fmt"With Get Time: {ds.getTime}")
    echo("----------------------------------------")
    #echo("Seconds: ", ds.getSeconds())
    #echo("Minutes: ", ds.getMinutes())
    #echo("Hours: ", ds.getHours())
    #echo("RawReg--> ", ds.rawArrayRead)
    #ds.enableDevice(true)
    sleepMs(500)
