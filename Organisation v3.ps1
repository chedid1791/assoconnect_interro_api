# ==========================================
# Configuration
# ==========================================

# $ApiToken = "e48d0ed9cc62a5b6e173765ece28e828c63842ff"
$ApiToken = "c25b826deaf6ea84a1b5fda376b2dd000ec21a5e"
# $BaseUrl = "https://app.assoconnect.com/api/v1/organizations/01GWH0MKT4KZ7GMJAVD0YS9KKX"
$BaseUrl = "https://app.assoconnect.com/api/v1/organizations/01H0HRRZE6KWCK4JGYMWG7KX49"

# Endpoint à interroger
$Endpoint_p1 = "groups"
$Endpoint_p2 = "CHAPTER_STATIC"


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

    while ($HasMoreData) {
        $Url = "$BaseUrl/$Endpoint_p1"+"?page=$page&itemsPerPage=$ItemsPerPage"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan
        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

            Foreach($Group in $Response.'hydra:member') {
                If ($Group.type -eq $Endpoint_p2) {
                    $NouvelleLigne = [PSCustomObject]@{
                        Id = $Group.'id'
                        Nom = $Group.'name'
                        Tel = $Group.'phoneNumber'
                        Mail = $Group.'email'
                        Date_Creation = $Group.'createdAt'
                        Type = $Group.'type'
                    }
                    # ==========================================
                    # Export CSV
                    # ==========================================
                   
                    $NouvelleLigne | Export-Csv `
                    -Path "D:\200 - Développement info\API\Groups.csv" `
                    -NoTypeInformation `
                    -Encoding UTF8 `
                    -Delimiter ";" `
                    -Append
                }
            }
            If ($Response.'hydra:totalItems') {
                $TotalItem = $response.'hydra:totalItems'
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
Out-File "D:\200 - Développement info\API\$Endpoint_p1.json" -Encoding UTF8
