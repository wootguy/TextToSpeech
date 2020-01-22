@echo off
cls

echo WARNING: Existing sounds will be overwritten!
echo.

pause
echo.

echo Copying sounds...
xcopy /i/e/y/q sound ..\..\..\sound
echo.

pause