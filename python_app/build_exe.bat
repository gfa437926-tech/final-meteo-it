@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo Run install_and_setup.bat first.
  pause
  exit /b 1
)
".venv\Scripts\python.exe" -m pip install --upgrade pyinstaller
if errorlevel 1 goto failed
".venv\Scripts\python.exe" -m PyInstaller --noconfirm --clean --windowed --onedir --name InventoryManager --collect-all psycopg --collect-all dotenv main.py
if errorlevel 1 goto failed
if exist ".env" copy /Y ".env" "dist\InventoryManager\.env" >nul
if not exist "dist\InventoryManager\data" mkdir "dist\InventoryManager\data"
echo.
echo Build completed:
echo %CD%\dist\InventoryManager\InventoryManager.exe
echo This build matches the Windows architecture of this computer.
pause
exit /b 0
:failed
echo.
echo Build failed. Review the error above.
pause
exit /b 1
