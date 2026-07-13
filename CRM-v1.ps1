# ==========================================
# Configuration
# ==========================================

$ApiToken = "e48d0ed9cc62a5b6e173765ece28e828c63842ff"
$Organisation = "01GWH0MKT4KZ7GMJAVD0YS9KKX"
$BaseUrl = "https://app.assoconnect.com/api/v1/organizations/$Organisation"

# Endpoint à interroger
$Endpoint_p1 = "crm"
$Endpoint_p2 = "/contacts"
$Endpoint = $Endpoint_p1+$Endpoint_p2

# Nombre d'éléments par page
$ItemsPerPage = 1000

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

    write-host "Endpoint : $Endpoint"

   # $Url = "$BaseUrl/$Endpoint"+"?page=$page&itemsPerPage=$ItemsPerPage"
   $Url = "https://app.assoconnect.com/api/v1/crm/contacts/"

        Write-Host "url : $url"
        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan

        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

                Write-Host "$Response"
        }
        
        catch {
            Write-Error "Erreur API : $($_.Exception.Message)"
            $HasMoreData = $false
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
    Out-File "D:\200 - Développement info\API\$Endpoint_P1.json" -Encoding UTF8

Write-Host ""
Write-Host "Fichiers générés :" -ForegroundColor Green
Write-Host " - $Endpoint.csv"
Write-Host " - $Endpoint.json"

