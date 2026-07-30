# ==========================================
# Configuration
# ==========================================

$ApiToken = "c25b826deaf6ea84a1b5fda376b2dd000ec21a5e"
$Organisation = "01H0HRRZE6KWCK4JGYMWG7KX49"
$BaseUrl = "https://app.assoconnect.com/api/v1/organizations/$Organisation/groups"

$RepApp = Get-Location
$RepData = "$RepApp\output\"

$Type = "GROUP_STATIC"


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
        $Url = "$BaseUrl"+"?page=$page&itemsPerPage=$ItemsPerPage"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan
        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

            Foreach($Group in $Response.'hydra:member') {
                If ($Group.type -eq $Type) {
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
                    -Path "$RepData\Groups_fixes.csv" `
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
Out-File "$RepData\Groupes_Fixes.json" -Encoding UTF8
