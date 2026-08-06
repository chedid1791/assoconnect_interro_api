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

# Nombre d'éléments par page
$ItemsPerPage = 100

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
# Fonction log
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

    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
}

# ==========================================
# Fonction récupération des groupes avancés sans les Associations Régionales, locales et DT
# ==========================================

function Get-GroupesAvances {

    param(
        [string]$baseUrl,
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

    write-Log "Indexation des groupes avancés ARD_DT terminée. Nombre de groupes : $($IndexARD_DT.Count)" -Level INFO

    $Url = "$baseUrl/organizations/$($config.Organisation)/groups"

    $Type = "CHAPTER_STATIC"
    $AllResults = @()
    $Page = 1
    $HasMoreData = $true
    $Nb_Associations_parcourues = 0

    $Urlcomplete = $Url
    try {
            $Response = Invoke-RestMethod `
                -Uri $Urlcomplete `
                -Method GET `
                -Headers $Headers

            If ($Response.'hydra:totalItems') {
                $TotalItem = $response.'hydra:totalItems'
                write-Log "Nombre total d'éléments : $TotalItem" -Level INFO
            }
    }
    catch {
        Write-Log "Erreur lors de l'appel à l'API : $($_.Exception.Message)" -Level ERROR
        Exit 1
    }

    while ($HasMoreData) {
        $Urlcomplete = "$Url"+"?page=$Page&itemsPerPage=$ItemsPerPage"
        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan
        try {
            $Response = Invoke-RestMethod `
                -Uri $Urlcomplete `
                -Method GET `
                -Headers $Headers
 
            Foreach($Association in $Response.'hydra:member') {
                If ($Association.type -eq $Type){
                    If($association.'id' -notin $IndexARD_DT.Keys) {
                        $urlAssocloc = "$baseUrl/organizations/$($Association.'id')/address"
                        Try {
                            $ResponseAssocloc = Invoke-RestMethod `
                                -Uri $urlAssocloc `
                                -Method GET `
                                -Headers $Headers
                            $Departement = $ResponseAssocloc.'administrativeArea2'
                            $Région = $ResponseAssocloc.'administrativeArea1'
                        }
                        Catch {
                            Write-Log "Erreur lors de l'appel à l'API pour l'adresse de l'association $($Association.'id') : $($_.Exception.Message)" -Level ERROR
                            Exit 1
                        }
                        $AssociationLocale = [PSCustomObject]@{
                        Id = $Association.'id'
                        Nom = $Association.'name'
                        Departement = $Departement
                        Region = $Région
                        Type = $Association.'type'
                    }
                    $AllResults += $AssociationLocale

                    } else {
                        write-log "Le groupe avancé avec l'ID $($Association.'id') est exclu car il est présent dans la liste ARD_DT." -Level WARNING
                        # write-log "Le groupe avancé $($Association.'name') est exclu." -level
                    }
                }
            }
            $Nb_Associations_parcourues = $Nb_Associations_parcourues + $Response.'hydra:member'.Count

            if ($Nb_Associations_parcourues -eq $TotalItem) {
                    $HasMoreData = $false
                }
                else {
                    $Page++
                }
        }
        catch {
            Write-Log "Erreur lors de l'appel à l'API : $($_.Exception.Message)" -Level ERROR
            Exit 1
        }
    }
    Return $AllResults
}
# ==========================================
# Fin de déclaration des fonctions
# ==========================================


# ==========================================
# Main script
# ==========================================
write-Log "Début du script" -Level INFO

if (Test-Path "$RepOutput\Groups_avances.csv") {
    $Dossier = Split-Path "$RepOutput\Groups_avances.csv"
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\Groups_avances.csv")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\Groups_avances.csv")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\Groups_avances.csv" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\Groups_avances.csv' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\Groups_avances.csv' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

if (Test-Path "$RepOutput\Groups_avances.json") {
    $Dossier = Split-Path "$RepOutput\Groups_avances.json"
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\Groups_avances.json")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\Groups_avances.json")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\Groups_avances.json" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\Groups_avances.json' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\Groups_avances.json' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

$Results = Get-GroupesAvances -baseUrl $BaseUrl -Endpoint "groups" -ItemsPerPage 100

# ==========================================
# Export csv
# ==========================================

$Results | Export-Csv -Path "$RepOutput\Groups_avances.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ";"

# ==========================================
# Export JSON
# ==========================================

$Results | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\Groups_avances.json" -Encoding UTF8

Write-Log "Fin du script"


