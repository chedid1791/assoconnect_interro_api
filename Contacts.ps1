# ==========================================
# Configuration
# ==========================================

$ApiToken = "c25b826deaf6ea84a1b5fda376b2dd000ec21a5e"
$Organisation = "01H0HRRZE6KWCK4JGYMWG7KX49"
$BaseUrl = "https://app.assoconnect.com/api/v1/organizations/$Organisation"

# Endpoint à interroger
$Endpoint_p1 = "contacts"
$Endpoint_p2 = "?relationType=MEMBERSHIP"
$Endpoint = $Endpoint_p1+$Endpoint_p2

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
        $Endpoint = "contacts"

        $Url = "$BaseUrl/$Endpoint"+"?page=$page&itemsPerPage=$ItemsPerPage"
        Write-Host "Url : $url"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan

        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

            Foreach ($Contact in $Response.'hydra:member') {
                If ($contact.Type -eq "PERSON") {
                    # Recherche de la relation AFFILIATION
                    $Affiliation = $Contact.relations | Where-Object {
                    $_.type -eq "AFFILIATION"
                    } | Select-Object
                   
                    $compteur_total = $affiliation.count

                    $GA = @()
                    $GA1 = @()

                    $GA1 += ($Affiliation[($compteur_total-2)].Organization -split '/')[-1]

                    foreach ($Relation in $Affiliation) {
                        If ((($Relation.organization -split '/')[-1] -ne $Organisation)) {
                        $GA += ($Relation.organization -split '/')[-1]
                     }
                     }

                    $NouvelleLigne = [PSCustomObject]@{
                    Id = $Contact.'@id'

                    Type = $contact.Type
                    Prenom = $Contact.firstname
                    Nom    = $Contact.lastname
                    Genre = $Contact.gender
                    Image = $Contact.profilPictureUrl
                    Email  = $Contact.email
                    T_Fixe = $Contact.landlinePhone
                    Mobile = $Contact.mobilePhone
                    Adresse_Street = $Contact.postalAddress.street1
                    Adresse_Street2 = $Contact.postalAddress.street2
                    Code_Postal = $Contact.postalAddress.postal
                    Ville = $Contact.postalAddress.city
                    Région = $Contact.postalAddress.administrativeArea1
                    Département = $Contact.postalAddress.administrativeArea2
                    Pays = $Contact.postalAddress.country
                    Adresse_complete = $Contact.postalAddress.formattedAddress
                    Date_Naissance = $Contact.dateOfBirth

                    # Informations complémentaires bénévoles, jeunes et (partenaires)
                    Rôle = $Contact.customFields."Role_P98owFE357qz"
                    Atelier = $Contact.customFields."Atelier_9xLxw2fYNNdH"
                    Présence = $Contact.customFields."Presence-aux-ateliers_Fv2EBQ6Vqy1C"
                    Droit_image = $Contact.customFields."Droit-a-l-image_4nyX6TVRKLDb"
                    Date_inscription = $Contact.customField."Date-inscription"
                    Personne_a_contacter = $Contact.customFields."Personne-a-contacter-en-urgence-si-different-des-parents"
                    Saison = $Contact.customFields."Saison-s"."01KS25BZEGDK3EMZX2ES4JQ1MC"
                    Commentaires = $Contact.customFields."Commentaires"
                    Date_de_sortie= $Contact.customFields."Date-de-sortie"
                    Motif_de_sortie = $Contact.customFields."Motif-sortie"

                    # Informations complémentaires bénévoles uniquement
                    CPSTI = $Contact.customFields."Ancien-adherent-au-regime-social-des-independants-RSI-CPSTI"
                    Délégués_au_vote_2026 = $Contact.customFields."Delegue-au-vote-AG-Nationale"

                    # Informations complémentaires jeunes uniquement
                    
                    Autorisation_rentrée = $contact.custumfield."Sortie-autorisee_g128wVsBBXVq"
                    Civilité_parent_1 = $Contact.customFields."Civilite-parent-1"
                    Prénom_parent_1 = $Contact.customFields."Prenom-parent-1"
                    Nom_parent_1 = $Contact.customFields."Nom-Parent-1"
                    Adresse_parent_1 = $Contact.customFields."Adresse-parent-1_KuNgFtiVoiqc"
                    Complément_adresse_parent_1 = $Contact.customFields."Complement-d-adresse-parent-1"
                    Code_postal_parent_1 = $Contact.customFields."Code-postal-parent-1"
                    Ville_parent_1 = $Contact.customFields."Ville-parent-1"
                    Téléphone_parent_1 = $Contact.customFields."Telephone-parent-1"
                    Email_parent_1 = $Contact.customFields."Email-parent-1"
                    Civilité_parent_2 = $Contact.customFields."Civilite-parent-2"
                    Prénom_parent_2 = $Contact.customFields."Prenom-parent-2"
                    Nom_parent_2 = $Contact.customFields."Nom-Parent-2"
                    Adresse_parent_2 = $Contact.customFields."Adresse-parent-2_xgJm1VLyifhF"
                    Complément_adresse_parent_2 = $Contact.customFields."Complement-d-adresse-parent-2"
                    Code_postal_parent_2 = $Contact.customFields."Ville-parent-2"
                    Ville_parent_2 = $Contact.customFields."Ville-parent-2"
                    Téléphone_parent_2 = $Contact.customFields."Telephone-parent-2"
                    Email_parent_2 = $Contact.customFields."Email-parent-2"
                    
                    # National uniquement (champs réservés à l'équipe salariés)
                    DT_Adm_Numérique_Sécurité_Communication = $Contact.customFields."DT-Administrateur-informatique"
                    Compte_technique = $Contact.customFields."Compte-technique"


                    GA1 = if ($GA.Count -ge 1) { $GA[0] } else { "" }
                    GA2 = if ($GA.Count -ge 2) { $GA[1] } else { "" }
                    GA3 = if ($GA.Count -ge 3) { $GA[2] } else { "" }
                    GA4 = if ($GA.Count -ge 4) { $GA[3] } else { "" }
                    GA5 = if ($GA.Count -ge 4) { $GA[4] } else { "" }
                    GA6 = if ($GA.Count -ge 4) { $GA[5] } else { "" }
                    GA7 = if ($GA.Count -ge 4) { $GA[6] } else { "" }
                    G8 = $GA[-1]
                    Date_creation = $Contact.createdAt
                    }

                    # ==========================================
                    # Export CSV
                    # ==========================================
                   
                    $NouvelleLigne | Export-Csv `
                    -Path "D:\200 - Développement info\API\contacts_2.csv" `
                    -NoTypeInformation `
                    -Encoding UTF8 `
                    -Delimiter ";" `
                    -Append

               $compteur_total--
               }

               If ($Response.'hydra:totalItems') {

                $TotalItem = $response.'hydra:totalItems'
               
               # $TotalItem | Out-File "D:\200 - Développement info\API\totalitem.txt"
                }
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
    Out-File "D:\200 - Développement info\API\$Endpoint_P1.json" -Encoding UTF8

Write-Host ""
Write-Host "Fichiers générés :" -ForegroundColor Green
Write-Host " - $Endpoint.csv"
Write-Host " - $Endpoint.json"

