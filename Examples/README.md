To fill in the "Clock.nim" file which is the real program, bookstores are required:
- 1 display1602.nim
- 2 ds1307.nim
- 3 picousb

that you can find on my Github website (Martinix_75).

If you want to synchronize the clock with time on your computer, use (and compile):
- syncTime.nim

Here you will also find the "Clock.uf2" file which is pre -filled and functional, only to be installed on your RP2040.

It will be necessary to have:
- DS1307
- RP2040
- Display type 1604 (HD44780+connected via PCF8574 on I2C)
