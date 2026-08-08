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

$Endpoint = "contacts"
$ListeContacts= "$Endpoint.csv"
$ListeGroupesAvances= "groups_avances.csv"

# Nombre d'éléments par page
$ItemsPerPage = 100

# ==========================================
# Fonction log
# ==========================================

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARNING","ERROR","DEBUG","SUCCESS")]
        [string]$Level = "INFO",

        [string]$LogFile = "$RepLog\$Endpoint$(Get-Date -Format 'yyyy-MM-dd').log"
    )

    # Création du dossier Logs s'il n'existe pas
    $LogFolder = Split-Path $LogFile
    if (!(Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder | Out-Null
    }

    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Line = "[{0}] [{1}] {2}" -f $Date, $Level, $Message

    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
}


#==========================================
# Charger les paramètres
#==========================================
If (test-Path $RepParam\$ParamFile) {
    $Config = Import-LocalizedData -BaseDirectory $RepParam -FileName $ParamFile
    $BaseUrl = $config.ApiUrl
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
    "X-AUTH-TOKEN" = $config.Token
}

# ==========================================
# Les fonctions
# ==========================================

# ==========================================
# Fonction récupération des contacts
# ==========================================

function Get-contacts {

    param(
        [string]$BaseUrl,
        [string]$Endpoint, 
        [int]$ItemsPerPage
    )

    $AllResults = @()
    $Page = 1
    $HasMoreData = $true
    $ItemsTotaux = 0

    #Chargement de la liste des Associations locales et idexation
    If (test-Path $RepOutput\$ListegroupesAvances) {
        $L_contacts = Import-Csv -Path "$RepOutput\$ListegroupesAvances" -Delimiter ";"
        write-Log "Le fichier '$RepOutput\$ListegroupesAvances' est chargé." -Level SUCCESS
    } else {
        Write-Log "Le fichier '$RepOutput\$ListegroupesAvances' est introuvable." -Level ERROR
        Exit 1
    }
    $IndexGroupeAvances = @{}

    foreach ($Ligne in $L_contacts) {
        $IndexGroupeAvances[$Ligne.Id] = $Ligne
    }
    write-Log "Indexation des groupes avancés terminée. Nombre de groupes : $($IndexGroupeAvances.Count)" -Level INFO

    $Url = "$BaseUrl/organizations/$($config.Organisation)/$Endpoint"

    while ($HasMoreData) {

        $Url = "$BaseUrl/organizations/$($config.Organisation)/$Endpoint"+"?page=$Page&itemsPerPage=$ItemsPerPage"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan

        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

            If ($Response.'hydra:totalItems') {
                $TotalItem = $response.'hydra:totalItems'
                write-Log "Nombre de contacts dans la base assoconnect : $TotalItem" -Level INFO
                write-host "Nombre de contacts dans la base assoconnect : $TotalItem"
            }
        }
        catch {
            Write-Log "Erreur lors de la lecture de la page $Page : $($_.Exception.Message)" -Level ERROR
            exit 1
        }
        Foreach ($Contact in $Response.'hydra:member') {

            $GroupeAvance = @()

            $Affiliation = $Contact.relations | Where-Object {
                $_.type -eq "AFFILIATION"
            } | Select-Object
            
            Foreach ($Relation in $Affiliation) {
                $id_GroupeAvance = ($Relation.organization -split '/')[-1]
                # Write-Host $id_GroupeAvance
                If ($id_GroupeAvance -in $IndexGroupeAvances.Keys) {
                    $Association = $IndexGroupeAvances[$id_GroupeAvance].Nom
                    Write-Host "$id_GroupeAvance , $Association"
                }
            }
        }


    $HasMoreData = $False
    }
}
# ==========================================
# Fin de déclaration des fonctions
# ==========================================


# ==========================================
# Main script
# ==========================================
write-Log "Début du script" -Level INFO

if (Test-Path "$RepOutput\$Endpoint.csv") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$Endpoint.csv")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$Endpoint.csv")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$Endpoint.csv" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\$Endpoint.csv' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\$Endpoint.csv' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

if (Test-Path "$RepOutput\$Endpoint.json") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$Endpoint.json")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$Endpoint.json")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$Endpoint.json" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\$Endpoint.json' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\$Endpoint.json' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

$Results = Get-contacts -baseUrl $BaseUrl -Endpoint "contacts" -ItemsPerPage 100
exit 0
# ==========================================
# Export csv
# ==========================================

$Results | Export-Csv -Path "$RepOutput\$Endpoint.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ";"

# ==========================================
# Export JSON
# ==========================================

$Results | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\$Endpoint.json" -Encoding UTF8

Write-Log "Fin du script" -Level INFO