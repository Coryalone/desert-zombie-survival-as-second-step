@echo off
cd /d "%~dp0"
call dart tool\prepare.dart
if errorlevel 1 goto failed
call flutter pub get
if errorlevel 1 goto failed
call flutter analyze
if errorlevel 1 goto failed
call flutter test
if errorlevel 1 goto failed
call flutter build apk --release
if errorlevel 1 goto failed
echo APK: %CD%\build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0
:failed
echo Build failed. See the error above.
pause
exit /b 1
