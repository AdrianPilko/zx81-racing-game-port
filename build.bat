REM clean up before calling assembler 
del racing.p
del racing.lst
del racing.sym

call zxasm racing

REM call racing.p will auto run emulator EightyOne if installed
call racing.p