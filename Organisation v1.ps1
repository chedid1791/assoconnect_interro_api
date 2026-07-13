# ==========================================
# Configuration
# ==========================================

$ApiToken = "e48d0ed9cc62a5b6e173765ece28e828c63842ff"
$BaseUrl = "https://app.assoconnect.com/api/v1/organizations/01GWH0MKT4KZ7GMJAVD0YS9KKX"

# Endpoint à interroger
$Endpoint = "groups"

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


    Write-Host ""
    Write-Host "Endpoint : $Endpoint" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pages : $ItemsPerPage" -ForegroundColor Green

    $AllResults = @()
    $Page = 1
    $HasMoreData = $true

    while ($HasMoreData) {
        $Url = "$BaseUrl/$Endpoint"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan
        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

            # Cas API Hydra (JSON-LD)
            if ($Response.'hydra:member') {

                $Items = $Response.'hydra:member'

                $AllResults += $Items

                Write-Host "$($Items.Count) enregistrements récupérés"

                if ($Items.Count -lt $ItemsPerPage) {
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
 return $AllResults
}
# ==========================================
# Exécution
# ==========================================

$Results = Get-AssoConnectData $Endpoint $ItemsPerPage

Write-Host ""
Write-Host "Total récupéré : $($Results.Count)" -ForegroundColor Green

# ==========================================
# Export JSON
# ==========================================

$Results |
    ConvertTo-Json -Depth 20 |
    Out-File "D:\200 - Développement info\API\$Endpoint.json" -Encoding UTF8
