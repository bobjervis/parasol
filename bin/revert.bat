setlocal

set BIN=%~dp0
if "%BIN:~-1%"=="\" set BIN=%BIN:~0,-1%

for %%i in (%BIN%) do set PARASOL_HOME=%%~dpi
if "%PARASOL_HOME:~-1%"=="\" set PARASOL_HOME=%PARASOL_HOME:~0,-1%

copy %PARASOL_HOME%\debug\parasol.pxi.save %PARASOL_HOME%\debug\parasol.pxi
if errorlevel 1 goto :fail
del %PARASOL_HOME%\debug\parasol.pxi.save
if errorlevel 1 goto :fail
echo SUCCESS
exit 0
:fail
echo FAILED
exit 1
