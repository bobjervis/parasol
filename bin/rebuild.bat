bin\parasol debug/parasol.pxi compiler/main.p --pxi=p1.pxi compiler/main.p
if errorlevel 1 goto :failed
bin\parasol p1.pxi --pxi=p2.pxi compiler/main.p
if errorlevel 1 goto :failed
bin\parasol debug/parasol.pxi src/util/bdiff.p p1.pxi p2.pxi
if errorlevel 1 goto :failed
bin\parasol p2.pxi test/drivers/etsTests.p %1 %2 %3 --testpxi=p2.pxi test/scripts/parasol_tests.ets
if errorlevel 1 goto :failed
copy bin\x86-64-win.pxi bin\x86-64-win.pxi.save
if errorlevel 1 goto :failed
copy p1.pxi bin\x86-64-win.pxi
if errorlevel 1 goto :failed
echo SUCCESS
bin\parasol bin/x86-64-win.pxi compiler/main.p --pxi=bin/x86-64-lnx.pxi --target=x86-64-lnx compiler/main.p
exit /b 0
:failed
echo FAILED