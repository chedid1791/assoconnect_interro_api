$Headers = @{
    "Accept"      = "application/ld+json"
    "X-AUTH-TOKEN" = "c25b826deaf6ea84a1b5fda376b2dd000ec21a5e"
}

$Uri = "https://app.assoconnect.com/api/v1/organizations/01H0HTDDDPTVDZYPC49KZG4JMT/address"

$Reponse = Invoke-RestMethod `
    -Uri $Uri `
    -Method Get `
    -Headers $Headers

$Reponse