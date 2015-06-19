setlocal

set BIN=%~dp0
if "%BIN:~-1%"=="\" set BIN=%BIN:~0,-1%

for %%i in (%BIN%) do set PARASOL_HOME=%%~dpi
if "%PARASOL_HOME:~-1%"=="\" set PARASOL_HOME=%PARASOL_HOME:~0,-1%

%BIN%\pc %PARASOL_HOME%\compiler/main.p %2 %3 %4 %5 %6 %7 %8 %9 %PARASOL_HOME%\test/src/%1.p

endlocal