copy debug\parasol.pxi.save debug\parasol.pxi
if errorlevel 1 goto :fail
del debug\parasol.pxi.save
if errorlevel 1 goto :fail
echo SUCCESS
exit 0
:fail
echo FAILED
exit 1
