# ==========================================
# Configuration
# ==========================================


#Répertoires de travail
$RepApp = Get-Location
$RepParam = "$RepApp\Parametres"
$RepOutput = "$RepApp\Output"

# Source des paramètres
$ParamFile = "Params.psd1"

$Endpoint = "contacts"

# Nombre d'éléments par page
$ItemsPerPage = 100

#==========================================
# Charger les paramètres
#==========================================
If (test-Path $RepParam\$ParamFile) {
    $Config = Import-LocalizedData -BaseDirectory $RepParam -FileName $ParamFile
    $BaseUrl = $config.ApiUrl
} else {
    Write-Host "Le fichier de paramètres '$ParamFile' est introuvable." -ForegroundColor yellow
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
# Fonction récupération des contacts
# ==========================================

function Get-contacts {

    param(
        [string]$BaseUrl,
        [string]$Endpoint, 
        [int]$ItemsPerPage
    )

    $AllResults = @()
    $Page = 135
    $HasMoreData = $true
    $ItemsTotaux = 0

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
                #write-Log "Nombre de contacts dans la base assoconnect : $TotalItem" -Level INFO
                write-host "Nombre de contacts dans la base assoconnect : $TotalItem"
            }
        }
        catch {
            Write-Host "Erreur lors de la lecture de la page $Page : $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }

         if ($Response.'hydra:member') {
                $Items = $Response.'hydra:member'
                $AllResults += $Items

                $ItemsTotaux = $Itemstotaux +$Items.Count

                if ($ItemsTotaux -eq $TotalItem) {
                    $HasMoreData = $false
                }
                else {
                    $Page++
                }
            }
            else {

                Write-Warning "Aucune donnée trouvée."
                $HasMoreData = $false
            }
    }
return $AllResults
}
# ==========================================
# Fin de déclaration des fonctions
# ==========================================


# ==========================================
# Main script
# ==========================================
write-Log "Début du script" -Level INFO

if (Test-Path "$RepOutput\$Endpoint.json") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$Endpoint.json")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$Endpoint.json")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$Endpoint.json" -NewName $NouveauNom
}
    

    $Results = Get-contacts -baseUrl $BaseUrl -Endpoint "contacts" -ItemsPerPage 100

# ==========================================
# Export JSON
# ==========================================

$Results | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\$Endpoint.json" -Encoding UTF8

write-host "Fin du script"