# ==========================================
# Configuration
# ==========================================


#Répertoires de travail
$RepApp = Get-Location
$RepParam = "$RepApp\Parametres"
$RepOutput = "$RepApp\Output"
$RepLog = "$RepApp\Logs"

# Source des paramètres
$ParamFile = "Params.psd1"

$NbContactsPP = 0
$NbContactsPM = 0

$Endpoint = "contacts"
$ListeGroupesAvances= "groups_avances.csv"

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

        [string]$LogFile = "$RepLog\$Endpoint$(Get-Date -Format 'yyyy-MM-dd').log"
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
# Fonction récupération des contacts
# ==========================================

function Get-contacts {

    param(
        [string]$BaseUrl,
        [string]$Endpoint, 
        [int]$ItemsPerPage,
        [Int]$NbContactsPP,
        [Int]$NbContactsPM
    )

    $AllResults = @()
    $Page = 1
    $HasMoreData = $true
    $ItemsTotaux = 0

    #Chargement de la liste des Associations locales et idexation
    If (test-Path $RepOutput\$ListegroupesAvances) {
        $L_contacts = Import-Csv -Path "$RepOutput\$ListegroupesAvances" -Delimiter ";"
        write-Log "Le fichier '$RepOutput\$ListegroupesAvances' est chargé." -Level SUCCESS
    } else {
        Write-Log "Le fichier '$RepOutput\$ListegroupesAvances' est introuvable." -Level ERROR
        Exit 1
    }
    $IndexGroupeAvances = @{}

    foreach ($Ligne in $L_contacts) {
        $IndexGroupeAvances[$Ligne.Id] = $Ligne
    }
    write-Log "Indexation des groupes avancés terminée. Nombre de groupes : $($IndexGroupeAvances.Count)" -Level INFO

    $Url = "$BaseUrl/organizations/$($config.Organisation)/$Endpoint"

    while ($HasMoreData) {

        $Url = "$BaseUrl/organizations/$($config.Organisation)/$Endpoint"+"?page=$Page&itemsPerPage=$ItemsPerPage"

        Write-Host "Lecture page $Page ..." -ForegroundColor Cyan
        Write-Log "Recherche des contacts page : $page"

        try {
            $Response = Invoke-RestMethod `
                -Uri $Url  `
                -Method GET `
                -Headers $Headers

            If ($Response.'hydra:totalItems') {
                $TotalItem = $response.'hydra:totalItems'
                write-Log "Nombre de contacts dans la base assoconnect : $TotalItem" -Level INFO
                # write-host "Nombre de contacts dans la base assoconnect : $TotalItem"
            }
        }
        catch {
            Write-Log "Erreur lors de la lecture de la page $Page : $($_.Exception.Message)" -Level ERROR
            exit 1
        }
        Foreach ($Contact in $Response.'hydra:member') {
            $Affiliation = $Contact.relations | Where-Object {
                $_.type -eq "AFFILIATION"
            } | Select-Object

            Foreach ($Relation in $Affiliation) {
                $id_GroupeAvance = ($Relation.organization -split '/')[-1]
                If ($id_GroupeAvance -in $IndexGroupeAvances.Keys) {
                    $GA_Nom = $IndexGroupeAvances[$id_GroupeAvance].Nom
                    $GA_Departement = $IndexGroupeAvances[$id_GroupeAvance].Departement
                    $GA_Region = $IndexGroupeAvances[$id_GroupeAvance].Region
                }
            }
           # Write-Host $Contact.Type
           # Write-host $contact.'@id'

            If ($Contact.Type -eq "PERSON"){
                $NouvelleLignePP = [PSCustomObject]@{
                    Id = $Contact.'@id'
                    Type = $contact.Type
                    Date_creation = $Contact.createdAt
                    Date_modification = $Contact.creaupdateAt
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
                    GA_Nom = $GA_Nom
                    GA_Departement = $GA_Departement
                    GA_Region = $GA_Region

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
                    Code_postal_parent_2 = $Contact.customFields."Code-postal-parent-2"
                    Ville_parent_2 = $Contact.customFields."Ville-parent-2"
                    Téléphone_parent_2 = $Contact.customFields."Telephone-parent-2"
                    Email_parent_2 = $Contact.customFields."Email-parent-2"
                    
                    # National uniquement (champs réservés à l'équipe salariés)
                    DT_Adm_Numérique_Sécurité_Communication = $Contact.customFields."DT-Administrateur-informatique"
                    Compte_technique = $Contact.customFields."Compte-technique"
                }
                $NouvelleLignePP | Export-Csv `
                    -Path "$RepOutput\Contacts_PP.csv" `
                    -NoTypeInformation `
                    -Encoding UTF8 `
                    -Delimiter ";" `
                    -Append
                $NbContactsPP++
            }
            # Write-host $Contact.type
            # Write-host $contact.'@id'

            If ($Contact.type -eq "STRUCTURE"){
                $NouvelleLignePM = [PSCustomObject]@{
                    Id = $Contact.'@id'
                    Type = $contact.Type
                    Status = $Contact.status
                    Name = $Contact.name
                    Email = $Contact.email
                    TelMobile = $Contact.mobilePhone
                    Code_Postal = $Contact.postalAddress.postal
                    Ville = $Contact.postalAddress.city
                    Région = $Contact.postalAddress.administrativeArea1
                    Département = $Contact.postalAddress.administrativeArea2
                    Pays = $Contact.postalAddress.country
                    DateDeCréation = $Contact.createdAt
                    DateDeModification = $Contact.updatedAt
                }

                $NouvelleLignePM | Export-Csv `
                    -Path "$RepOutput\Contacts_PM.csv" `
                    -NoTypeInformation `
                    -Encoding UTF8 `
                    -Delimiter ";" `
                    -Append
                $NbContactsPM++
            }
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

                <#if ($ItemsTotaux -eq 600) {
                    $HasMoreData = $false
                }
                else {
                    $Page++
                }#>
            }
            else {

                Write-Warning "Aucune donnée trouvée."
                $HasMoreData = $false
            }
    }
return $AllResults, $NbContactsPP, $NbContactsPM
}
# ==========================================
# Fin de déclaration des fonctions
# ==========================================


# ==========================================
# Main script
# ==========================================
write-Log "Début du script" -Level INFO

$FichierPPCSV = $Endpoint+"_PP"
$FichierPMCSV = $Endpoint+"_PM"

if (Test-Path "$RepOutput\$FichierPPCSV.csv") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$FichierPPCSV.csv")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$FichierPPCSV.csv")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$FichierPPCSV.csv" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\$FichierPPCSV.csv' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\$FichierPPCSV.csv' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

if (Test-Path "$RepOutput\$FichierPMCSV.csv") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$FichierPMCSV.csv")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$FichierPMCSV.csv")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$FichierPMCSV.csv" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\$FichierPMCSV.csv' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\$FichierPMCSV.csv' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

if (Test-Path "$RepOutput\$Endpoint.json") {
    $Nom = [System.IO.Path]::GetFileNameWithoutExtension("$RepOutput\$Endpoint.json")
    $Extension = [System.IO.Path]::GetExtension("$RepOutput\$Endpoint.json")
    $Date = Get-Date -Format "yyyyMMdd_HHmmss"

    $NouveauNom = "$Nom`_$Date$Extension"

    Rename-Item -Path "$RepOutput\$Endpoint.json" -NewName $NouveauNom
    Write-Log "Le fichier '$RepOutput\$Endpoint.json' a été renommé en '$NouveauNom'." -Level SUCCESS
}else {
    Write-Log "Le fichier '$RepOutput\$Endpoint.json' n'existe pas. Aucun renommage nécessaire." -Level INFO
}

$Results = Get-contacts -baseUrl $BaseUrl -Endpoint "contacts" -ItemsPerPage 100 -NbContactsPP 0 -NbContactsPM 0
Write-Log "Nbre de contacts PP : $($Results[1])"
Write-Log "Nbre de contacts PM : $($Results[2])"


# ==========================================
# Export JSON
# ==========================================

$Results[0] | ConvertTo-Json -Depth 20 | Out-File "$RepOutput\$Endpoint.json" -Encoding UTF8

Write-Log "Fin du script" -Level INFO