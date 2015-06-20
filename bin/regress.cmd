setlocal

set BIN=%~dp0
if "%BIN:~-1%"=="\" set BIN=%BIN:~0,-1%

for %%i in (%BIN%) do set PARASOL_HOME=%%~dpi
if "%PARASOL_HOME:~-1%"=="\" set PARASOL_HOME=%PARASOL_HOME:~0,-1%

%BIN%\pc %PARASOL_HOME%\test\drivers\etsTests.p --compileFromSource %1 %2 %3 %PARASOL_HOME%\test/scripts/parasol_tests.ets >x.out
notepad x.out

endlocal