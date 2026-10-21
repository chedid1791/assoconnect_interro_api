# ==========================================
# Configuration
# ==========================================


#Répertoires de travail

$RepApp = Get-Location
$RepOutput = "$RepApp\Output"
$Fichier = "$RepOutput\contacts_20261016_172533.json"
$Data = @()


# Chargement du fichier JSON
$Data = @(Get-Content -Raw -Path $Fichier | ConvertFrom-Json)


$Data | Format-List *

# Affichage des contacts
$Data | Format-Table firstname, lastname, email, mobile -AutoSize


write-Host "Nombre de contacts dans le fichier JSON : $($Data.Count)" -ForegroundColor Green
Pause