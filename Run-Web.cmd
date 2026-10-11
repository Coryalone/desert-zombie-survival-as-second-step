@echo off
cd /d "%~dp0"
call dart tool\prepare.dart
if errorlevel 1 goto failed
call flutter pub get
if errorlevel 1 goto failed
call flutter run -d chrome
if errorlevel 1 goto failed
exit /b 0
:failed
echo Launch failed. See the error above.
pause
exit /b 1
