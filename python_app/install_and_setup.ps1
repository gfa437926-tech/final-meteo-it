$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
function Step($s) { Write-Host "`n==> $s" -ForegroundColor Cyan }
function Password($n) {
  # Hex output is URL-safe and avoids quoting/connection-string escaping bugs.
  $bytes = New-Object byte[] $n
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes); return ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant() }
  finally { $rng.Dispose() }
}
function PsqlPath {
  $cmd = Get-Command psql.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($v in @('17','16','15')) {
    $p = "$env:ProgramFiles\PostgreSQL\$v\bin\psql.exe"
    if (Test-Path $p) { return $p }
  }
  return $null
}
try {
  $admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    exit
  }
  if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'winget غير متوفر. حدّث App Installer ثم أعد المحاولة.' }
  $postgresPassword = Password 36
  $appPassword = Password 36
  $psql = PsqlPath
  if ($psql) {
    $secure = Read-Host 'أدخل كلمة مرور مستخدم postgres الحالية' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $postgresPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
  }
  if (-not $psql) {
    Step 'تثبيت PostgreSQL 17'
    $override = "--mode unattended --unattendedmodeui none --superpassword $postgresPassword --serverport 5432 --prefix `"$env:ProgramFiles\PostgreSQL\17`" --datadir `"$env:ProgramFiles\PostgreSQL\17\data`""
    & winget install --id PostgreSQL.PostgreSQL.17 --exact --silent --accept-package-agreements --accept-source-agreements --override $override
    if ($LASTEXITCODE -ne 0) { throw "فشل تثبيت PostgreSQL. رمز الخروج: $LASTEXITCODE" }
    Start-Sleep -Seconds 5
    $psql = PsqlPath
  }
  if (-not $psql) { throw 'لم يتم العثور على psql بعد التثبيت.' }
  Step 'تشغيل خدمة PostgreSQL'
  $svc = Get-Service | Where-Object { $_.Name -like 'postgresql*' } | Select-Object -First 1
  if (-not $svc) { throw 'خدمة PostgreSQL غير موجودة.' }
  if ($svc.Status -ne 'Running') { Start-Service $svc.Name }
  $env:PGPASSWORD = $postgresPassword
  $ready = $false
  for ($i=0; $i -lt 25; $i++) {
    & $psql -h localhost -p 5432 -U postgres -d postgres -Atc 'SELECT 1' *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 2
  }
  if (-not $ready) { throw 'PostgreSQL لا يستجيب على localhost:5432.' }
  Step 'إنشاء مستخدم وقاعدة التطبيق'
  $roleCheck = & $psql -h localhost -p 5432 -U postgres -d postgres -Atc "SELECT 1 FROM pg_roles WHERE rolname='inventory_app'"
  if ($roleCheck -ne '1') {
    & $psql -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -c "CREATE ROLE inventory_app LOGIN PASSWORD '$appPassword'"
    if ($LASTEXITCODE -ne 0) { throw 'تعذر إنشاء مستخدم التطبيق.' }
  } else {
    & $psql -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -c "ALTER ROLE inventory_app WITH LOGIN PASSWORD '$appPassword'"
    if ($LASTEXITCODE -ne 0) { throw 'تعذر تحديث كلمة مرور مستخدم التطبيق.' }
  }
  $dbCheck = & $psql -h localhost -p 5432 -U postgres -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='meteo_inventory'"
  if ($dbCheck -ne '1') {
    & $psql -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE meteo_inventory OWNER inventory_app'
    if ($LASTEXITCODE -ne 0) { throw 'تعذر إنشاء قاعدة البيانات.' }
  }
  Step 'ضبط ملكية قاعدة البيانات وصلاحيات التطبيق'
  & $psql -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 -c 'ALTER DATABASE meteo_inventory OWNER TO inventory_app'
  if ($LASTEXITCODE -ne 0) { throw 'تعذر ضبط مالك قاعدة البيانات.' }
  & $psql -h localhost -p 5432 -U postgres -d meteo_inventory -v ON_ERROR_STOP=1 -c 'GRANT USAGE, CREATE ON SCHEMA public TO inventory_app; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO inventory_app; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO inventory_app'
  if ($LASTEXITCODE -ne 0) { throw 'تعذر ضبط صلاحيات مخطط قاعدة البيانات.' }
  Step 'تطبيق مخطط الجداول بصلاحيات مستخدم التطبيق'
  $env:PGPASSWORD = $appPassword
  & $psql -h localhost -p 5432 -U inventory_app -d meteo_inventory -v ON_ERROR_STOP=1 -f (Join-Path $AppDir 'schema_postgres.sql')
  if ($LASTEXITCODE -ne 0) { throw 'تعذر إنشاء جداول التطبيق بصلاحيات المستخدم المحدود.' }
  $env:PGPASSWORD = $postgresPassword
  Step 'إعداد اتصال Python'
  @"
INVENTORY_STORAGE=postgres
INVENTORY_DATABASE_URL=postgresql://inventory_app:$appPassword@localhost:5432/meteo_inventory
"@ | Set-Content -Path (Join-Path $AppDir '.env') -Encoding ASCII
  if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    Step 'تنزيل وتثبيت Python 3.12'
    & winget install --id Python.Python.3.12 --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'تعذر تثبيت Python 3.12 عبر winget.' }
    $env:Path += ";$env:LocalAppData\Programs\Python\Python312;$env:LocalAppData\Programs\Python\Python312\Scripts"
  }
  if (-not (Get-Command py.exe -ErrorAction SilentlyContinue)) { throw 'لم يتم العثور على Python Launcher بعد التثبيت. أعد تشغيل المثبّت.' }
  Push-Location $AppDir
  try {
    & py -3 -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'تعذر إنشاء بيئة Python.' }
    & .\.venv\Scripts\python.exe -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw 'تعذر تحديث pip.' }
    & .\.venv\Scripts\python.exe -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'تعذر تثبيت مكتبات Python.' }
    $env:INVENTORY_DATABASE_URL = "postgresql://inventory_app:$appPassword@localhost:5432/meteo_inventory"
    & .\.venv\Scripts\python.exe -c 'import psycopg,os; c=psycopg.connect(os.environ["INVENTORY_DATABASE_URL"]); c.execute("BEGIN"); c.execute("INSERT INTO assets(id,category) VALUES (%s,%s)", ("__installer_permission_check__", "test")); c.rollback(); c.close(); print("DATABASE_AND_WRITE_PERMISSIONS_OK")'
    if ($LASTEXITCODE -ne 0) { throw 'فشل اختبار اتصال التطبيق أو صلاحيات الكتابة في قاعدة البيانات.' }
  } finally { Pop-Location }
  Step 'تحويل البرنامج إلى تطبيق EXE مناسب لمعمارية هذا الجهاز'
  Push-Location $AppDir
  try {
    & .\.venv\Scripts\python.exe -m PyInstaller --noconfirm --clean --windowed --onedir --name InventoryManager --collect-all psycopg --collect-all dotenv main.py
    if ($LASTEXITCODE -ne 0) { throw 'فشل إنشاء ملف EXE. راجع سجل البناء.' }
    if (Test-Path (Join-Path $AppDir '.env')) { Copy-Item (Join-Path $AppDir '.env') (Join-Path $AppDir 'dist\InventoryManager\.env') -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $AppDir 'dist\InventoryManager\data') | Out-Null
  } finally { Pop-Location }
  Step 'إنشاء اختصار على سطح المكتب'
  $exePath = Join-Path $AppDir 'dist\InventoryManager\InventoryManager.exe'
  $desktop = [Environment]::GetFolderPath('Desktop')
  $shortcutPath = Join-Path $desktop 'نظام جرد الأصول.lnk'
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $exePath
  $shortcut.WorkingDirectory = Split-Path -Parent $exePath
  $shortcut.Description = 'نظام جرد وإدارة أصول تقنية المعلومات'
  $shortcut.Save()
  Step 'اكتمل الإعداد والبناء؛ تشغيل EXE'
  Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath)
} catch {
  Write-Host "`nفشل الإعداد: $($_.Exception.Message)" -ForegroundColor Red
  Read-Host 'اضغط Enter للإغلاق'
  exit 1
}
