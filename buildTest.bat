REM clean up before calling assembler 
del test.p
del test.lst
del test.sym

call zxasm test

REM call racing.p will auto run emulator EightyOne if installed
call test.p