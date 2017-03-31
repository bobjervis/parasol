debug\parasol debug/parasol.pxi compiler/main.p --pxi=p1.pxi compiler/main.p
if errorlevel 1 goto :failed
debug\parasol p1.pxi --pxi=p2.pxi compiler/main.p
if errorlevel 1 goto :failed
debug\parasol debug/parasol.pxi src/util/bdiff.p p1.pxi p2.pxi
if errorlevel 1 goto :failed
debug\parasol p2.pxi test/drivers/etsTests.p %1 %2 %3 --testpxi=p2.pxi test/scripts/parasol_tests.ets
if errorlevel 1 goto :failed
copy debug\parasol.pxi debug\parasol.pxi.save
if errorlevel 1 goto :failed
copy p1.pxi debug\parasol.pxi
if errorlevel 1 goto :failed
echo SUCCESS
debug\parasol debug/parasol.pxi compiler/main.p --pxi=debug/x86-64lnx.pxi --target=x86-64-lnx compiler/main.p
exit /b 0
:failed
echo FAILED