Add-Type -Path ".\itext.kernel.dll"
Add-Type -Path ".\itext.layout.dll"

$pdfReader = [iText.Kernel.Pdf.PdfReader]::new("document.pdf")
$pdfWriter = [iText.Kernel.Pdf.PdfWriter]::new("document_personnalise.pdf")
$pdf = [iText.Kernel.Pdf.PdfDocument]::new($pdfReader,$pdfWriter)

$doc = [iText.Layout.Document]::new($pdf)

$imageData = [iText.IO.Image.ImageDataFactory]::Create("logo.png")
$image = [iText.Layout.Element.Image]::new($imageData)

$image.SetFixedPosition(1,400,700)
$image.ScaleToFit(120,120)

$doc.Add($image)

$doc.Close()