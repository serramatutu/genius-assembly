@echo off

cd src\

mkdir bin
del /Q bin\*.*

if not exist rsrc.rc goto over1
\masm32\bin\rc /v rsrc.rc
move rsrc.res bin\
\masm32\bin\cvtres /machine:ix86 bin\rsrc.res
move *. bin\
:over1

\masm32\bin\ml /c /coff %1.asm
if errorlevel 1 goto errasm

move %1.obj bin\

cd bin\

if not exist rsrc.obj goto nores

\masm32\bin\Link /SUBSYSTEM:WINDOWS /OPT:NOREF %1.obj rsrc.obj
if errorlevel 1 goto errlink

dir %1.*
cd ..\

goto TheEnd

:nores
\masm32\bin\Link /SUBSYSTEM:WINDOWS /OPT:NOREF %1.obj
if errorlevel 1 goto errlink
dir %1.*
goto TheEnd

:errlink
echo _
echo Link error
goto TheEnd

:errasm
echo _
echo Assembly Error
goto TheEnd

:TheEnd

cd bin\
cls
main.exe
cd ..\..\

pause
