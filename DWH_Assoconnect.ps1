# ==========================================
# Configuration
# ==========================================

#Répertoires de travail
$RepApp = Get-Location
$RepParam = "$RepApp\Parametres"
$RepOutput = "$RepApp\Output"
$RepInput = "$RepApp\Input"
$RepLog = "$RepApp\Logs"

# Source des paramètres
$ParamFile = "Params.psd1"
$ListeARD_DT = "ARD_DT.csv"

Write-Log "Début du script"

#==========================================
# Charger les paramètres
#==========================================
If (test-Path $RepParam\$ParamFile) {
    $Config = Import-LocalizedData -BaseDirectory $RepParam -FileName $ParamFile
    Write-Log "Le fichier de paramètres '$RepParam\$ParamFile' est chargé." -Level SUCCESS
} else {
    # Write-Host "Le fichier de paramètres '$ParamFile' est introuvable." -ForegroundColor yellow
    Write-Log "Le fichier de paramètres '$RepParam\$ParamFile' est introuvable." -Level ERROR
    Exit 1
}   
#==========================================

# ==========================================
# En-têtes HTTP
# ==========================================

$Headers = @{
    "Accept"       = "application/ld+json"
    "X-AUTH-TOKEN" = $ApiToken
}

# ==========================================
# Les fonctions
# ==========================================

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARNING","ERROR","DEBUG","SUCCESS")]
        [string]$Level = "INFO",

        [string]$LogFile = "$RepLog\$(Get-Date -Format 'yyyy-MM-dd').log"
    )

    # Création du dossier Logs s'il n'existe pas
    $LogFolder = Split-Path $LogFile
    if (!(Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder | Out-Null
    }

    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Line = "[{0}] [{1}] {2}" -f $Date, $Level, $Message

    Add-Content -Path $LogFile -Value $Line
}

# ==========================================
# Fonction récupération des groupes avancés sans les Associations Régionales, locales et DT
# ==========================================
function Get-GroupesAvances {

    param(
        [string]$Endpoint, 
        [int]$ItemsPerPage
    )
If (test-Path $RepInput\$ListeARD_DT) {
    $ARD_DT = Import-Csv -Path "$RepInput\ARD_DT.csv" -Delimiter ";" 
    write-Log "Le fichier '$RepInput\$ListeARD_DT' est chargé." -Level SUCCESS
} else {
    Write-Log "Le fichier '$RepInput\$ListeARD_DT' est introuvable." -Level ERROR
    Exit 1
}
$IndexARD_DT = @{}

foreach ($Ligne in $ARD_DT) {
    $IndexARD_DT[$Ligne.Groups_avances_Id] = $Ligne
}

write-Log "Indexation des groupes avancés terminée. Nombre de groupes : $($IndexARD_DT.Count)" -Level INFO
}

# ==========================================
# Main script
# ==========================================

$Results = Get-GroupesAvances -Endpoint "groups" -ItemsPerPage 100
$Results

Write-Log "Fin du script"

