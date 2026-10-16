# ==========================================
# Configuration
# ==========================================


#Répertoires de travail

$RepApp = Get-Location
$RepOutput = "$RepApp\Output"
$Fichier = "$RepOutput\contacts_20261016_172533.json"

$Data = @()
$Data = Get-Content -Raw -Path $Fichier | ConvertFrom-Json
write-Host "Nombre de contacts dans le fichier JSON : $($Data.Count)" -ForegroundColor Green
Pause