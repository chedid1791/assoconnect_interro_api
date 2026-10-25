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
#$ListeARD_DT = "ARD_DT.csv"
$ListeARD = "ARD.csv"
$ListeDT = "DT.csv"


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
# Fonction récupération des groupes avancés sans les Associations Régionales, locales et DT
# ==========================================

function Get-GroupesAvances {

    param(
        [string]$baseUrl,
        [string]$Endpoint, 
        [int]$ItemsPerPage
    )
    If (test-Path $RepInput\$ListeDT) {
        $DT = Import-Csv -Path "$RepInput\DT.csv" -Delimiter ";"
        write-Log "Le fichier '$RepInput\$ListeDT' est chargé." -Level SUCCESS
    } else {
        Write-Log "Le fichier '$RepInput\$ListeDT' est introuvable." -Level ERROR
        Exit 1
    }
    $IndexDT = @{}

    foreach ($Ligne in $DT) {
        $IndexDT[$Ligne.Groups_avances_Id] = $Ligne
    }

    write-Log "Indexation des groupes avancés DT terminée. Nombre de groupes : $($IndexDT.Count)" -Level INFO

If (test-Path $RepInput\$ListeARD) {
        $ARD = Import-Csv -Path "$RepInput\ARD.csv" -Delimiter ";"
        write-Log "Le fichier '$RepInput\$ListeARD' est chargé." -Level SUCCESS
    } else {
        Write-Log "Le fichier '$RepInput\$ListeARD' est introuvable." -Level ERROR
        Exit 1
    }
    $IndexARD = @{}

    foreach ($Ligne in $ARD) {
        $IndexARD[$Ligne.Groups_avances_Id] = $Ligne
    }

    write-Log "Indexation des groupes avancés ARD terminée. Nombre de groupes : $($IndexARD.Count)" -Level INFO

    $Url = "$baseUrl/organizations/$($config.Organisation)/groups"

    $Type = "CHAPTER_STATIC"
    $AllResults = @()
    $Page = 1
    $HasMoreData = $true
    $Nb_Associations_parcourues = 0

    $Urlcomplete = $Url
    try {
        #$Response = Invoke-RestMethod -Uri $Urlcomplete -Method GET -Headers $Headers
         $Response = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing
         $Datas = [System.Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray()) | ConvertFrom-Json
    }
    catch {
        Write-Log "Erreur lors de l'appel à l'API : $($_.Exception.Message)" -Level ERROR
        Exit 1
    }
    If ($Datas.'hydra:totalItems') {
        $TotalItem = $Datas.'hydra:totalItems'
        #write-Log "Nombre total d'éléments : $TotalItem" -Level INFO
    }

    while ($HasMoreData) {
        $Urlcomplete = "$Url"+"?page=$Page&itemsPerPage=$ItemsPerPage"
        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan
        
        try {
            #$Response = Invoke-RestMethod -Uri $Urlcomplete -Method GET -Headers $Headers
            $Response = Invoke-WebRequest -Uri $Urlcomplete -Headers $Headers -UseBasicParsing
            $Datas = [System.Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray()) | ConvertFrom-Json
        }
        catch {
            Write-Log "Erreur lors de l'appel à l'API : $($_.Exception.Message)" -Level ERROR
            Exit 1
        }

        Foreach($Association in $Datas.'hydra:member') {
            If ($Association.type -eq $Type){
                If($association.'id' -notin $IndexDT.Keys) {
                    $urlAssocloc = "$baseUrl/organizations/$($Association.'id')/address"
                    Try {
                        $ResponseAssocloc = Invoke-WebRequest -Uri $urlAssocloc -Headers $Headers -UseBasicParsing
                        $DatasAssocloc = [System.Text.Encoding]::UTF8.GetString($ResponseAssocloc.RawContentStream.ToArray()) | ConvertFrom-Json
                    } catch {
                        Write-Log "Erreur lors de l'appel à l'API pour l'adresse de l'association $($Association.'id') : $($_.Exception.Message)" -Level ERROR
                    }
                    $Departement = $DatasAssocloc.'administrativeArea2'
                    $Région = $DatasAssocloc.'administrativeArea1'
                    $CodePostal = $DatasAssocloc.'Postal'
                    $TypeGA = ""

                    If($association.'id' -in $IndexARD.Keys) {
                        $TypeGA = "ARD"
                    }else {
                        $TypeGA = "LOC"
                    }
                    $AssociationLocale = [PSCustomObject]@{
                        Id = $Association.'id'
                        Nom = $Association.'name'
                        Type = $Association.'type'
                        Departement = $Departement
                        Region = $Région
                        Code_Postal = $CodePostal
                        TypeGA = $TypeGA
                        UID = $CodePostal + "_" + $Association.'name'.Substring($Association.'name'.Length - 10)
                    }
                    $AllResults += $AssociationLocale
                } else {
                    write-log "Le groupe avancé avec l'ID $($Association.'id') est déjà présent dans la liste des groupes avancés DT. Il sera ignoré." -Level WARNING
                }
            }
        }
            $Nb_Associations_parcourues = $Nb_Associations_parcourues + $Datas.'hydra:member'.Count 

            if ($Nb_Associations_parcourues -eq $TotalItem) {
                $HasMoreData = $false
            }
            else {
                $Page++
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
$heureActuelle = Get-Date -Format "HH:mm:ss"
write-Log "Début du script à $heureActuelle"


if (Test-Path "$RepOutput\Groups_avances.csv") {
    # $Dossier = Split-Path "$RepOutput\Groups_avances.csv"
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
    # $Dossier = Split-Path "$RepOutput\Groups_avances.json"
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

#$Results | Export-Csv -Path "$RepOutput\Groups_avances.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ";"
$Results | Export-Csv -Path "$RepOutput\Groups_avances.csv" -NoTypeInformation -Delimiter ";"

# ==========================================
# Export JSON
# ==========================================

$Results | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\Groups_avances.json" -Encoding UTF8

$heureActuelle = Get-Date -Format "HH:mm:ss"
Write-Log "Fin du script à $heureActuelle"
Write-Host "Fin du script. Les résultats ont été exportés vers '$RepOutput\Groups_avances.csv' et '$RepOutput\Groups_avances.json'." -ForegroundColor Green
