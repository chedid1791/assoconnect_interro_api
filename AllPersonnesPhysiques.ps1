# ==========================================
# Configuration
# ==========================================

$ApiToken = "c25b826deaf6ea84a1b5fda376b2dd000ec21a5e"
$Organisation = "01H0HRRZE6KWCK4JGYMWG7KX49"
$RepApp = Get-Location
$RepData = "$RepApp\output\"

$BaseUrl = "https://app.assoconnect.com/api/v1/organizations/$Organisation/contacts/?type=PERSON"

# Nombre d'éléments par page
$ItemsPerPage = 100

# ==========================================
# En-têtes HTTP
# ==========================================

$Headers = @{
    "Accept"       = "application/ld+json"
    "X-AUTH-TOKEN" = $ApiToken
}

# ==========================================
# Fonction de récupération paginée
# ==========================================

function Get-AssoConnectData {

    param(
        [string]$Endpoint, 
        [int]$ItemsPerPage
    )
    $AllResults = @()
    $Page = 1
    $HasMoreData = $true
    $ItemsTotaux = 0

    while ($HasMoreData) {

        $Url = "$BaseUrl"+"&page=$page&itemsPerPage=$ItemsPerPage"
        Write-Host "Url : $url"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan

        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers
            
            If ($Response.'hydra:totalItems') {
                    $TotalItem = $response.'hydra:totalItems'
                    #$TotalItem = 100
                }

            # Cas API Hydra (JSON-LD)
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
        catch {
            Write-Error "Erreur API : $($_.Exception.Message)"
            $HasMoreData = $false
        }
        }
    write-host "$All"
 return $AllResults
 }
# ==========================================
# Exécution
# ==========================================

$Results = Get-AssoConnectData $Endpoint $ItemsPerPage

Write-Host "Total récupéré : $($Results.Count)" -ForegroundColor Green

# ==========================================
# Export JSON
# ==========================================

$Results |
    ConvertTo-Json -Depth 20 |
    Out-File "$RepData\personnes_physiques.json" -Encoding UTF8

Write-Host ""
Write-Host "Fichiers générés :" -ForegroundColor Green