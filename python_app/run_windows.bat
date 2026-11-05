@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" py -3 -m venv .venv
call ".venv\Scripts\activate.bat"
python -m pip install --upgrade pip
pip install -r requirements.txt
if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo تم إنشاء ملف .env. عدّل كلمة مرور PostgreSQL ثم أعد تشغيل هذا الملف.
  notepad ".env"
  pause
  exit /b 0
)
python main.py
pause
