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
        [int]$ItemsPerPage)
    
    $ListedesContactsRecuperes = @()

    $NombreDeContactsDansLaBase = 0
    $NbreDeContactsRecuperes = 0

    $Page = 1
    $HasMoreData = $true

    while ($HasMoreData) {


        $Url = "$BaseUrl/organizations/$($config.Organisation)/$Endpoint"+"?page=$Page&itemsPerPage=$ItemsPerPage"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan

        $response = $null

        try {
            $Response = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing
            $Data = [System.Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray()) | ConvertFrom-Json
        }
        catch {
            Write-Host "Erreur lors de la lecture de la page $Page : $($_.Exception.Message)" -ForegroundColor Red
            $ListedesContactsRecuperes | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\$Endpoint.json" -Encoding UTF8
            exit 1
        }

        $NombreDeContactsDansLaBase = $Data.'hydra:totalItems'
        Write-Host "Nombre de contacts dans la base assoconnect : $NombreDeContactsDansLaBase" -ForegroundColor Green

        If ($Data.'hydra:member') {
            $ListeDesContactsdelaPage  = $Data.'hydra:member'
            $ListeDesContactsRecuperes += $ListeDesContactsdelaPage

            $NbreDeContactsRecuperes = $NbreDeContactsRecuperes + $ListeDesContactsdelaPage.Count

            if ($NbreDeContactsRecuperes -eq $NombreDeContactsDansLaBase) {
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
    return $ListedesContactsRecuperes
}
# ==========================================
# Fin de déclaration des fonctions
# ==========================================


# ==========================================
# Main script
# ==========================================

if (Test-Path "$RepOutput\$Endpoint.json") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$Endpoint.json")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$Endpoint.json")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$Endpoint.json" -NewName $NouveauNom
}
$ListedesContactsRecuperes = Get-contacts -baseUrl $BaseUrl -Endpoint "contacts" -ItemsPerPage $ItemsPerPage

# ==========================================
# Export JSON
# ==========================================

$ListedesContactsRecuperes | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\$Endpoint.json" -Encoding UTF8

write-host "Fin du script"