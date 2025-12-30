param(
    [Parameter(Mandatory = $true)]
    [string]$CertPath,

    [Parameter(Mandatory = $true)]
    [string]$KeyPath,

    [string]$DnsName = "localhost"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Join-Bytes {
    param([Parameter(Mandatory = $true)][object[]]$Parts)
    $ms = New-Object System.IO.MemoryStream
    foreach ($p in $Parts) {
        if ($null -eq $p) {
            continue
        }

        if ($p -is [byte]) {
            $ms.WriteByte([byte]$p) | Out-Null
            continue
        }

        if ($p -is [byte[]]) {
            if ($p.Length -gt 0) {
                $ms.Write($p, 0, $p.Length) | Out-Null
            }
            continue
        }

        if ($p -is [System.Collections.IEnumerable]) {
            foreach ($b in $p) {
                if ($null -eq $b) { continue }
                $ms.WriteByte([byte]$b) | Out-Null
            }
            continue
        }

        throw "Join-Bytes: Unsupported part type: $($p.GetType().FullName)"
    }
    $ms.ToArray()
}

function Der-Length {
    param([Parameter(Mandatory = $true)][int]$Length)
    if ($Length -lt 128) {
        return [byte[]]@([byte]$Length)
    }
    $bytes = New-Object System.Collections.Generic.List[byte]
    $n = $Length
    while ($n -gt 0) {
        $bytes.Insert(0, [byte]($n -band 0xFF))
        $n = $n -shr 8
    }
    $prefix = [byte](0x80 -bor $bytes.Count)
    return Join-Bytes -Parts @([byte[]]@($prefix), [byte[]]$bytes.ToArray())
}

function Der-Integer {
    param([Parameter(Mandatory = $true)][byte[]]$BigEndian)

    # Ensure we have at least one byte.
    if ($null -eq $BigEndian -or $BigEndian.Length -eq 0) {
        $BigEndian = [byte[]]@([byte]0x00)
    }

    # Strip leading zeros (but keep at least 1 byte).
    $start = 0
    while ($start -lt ($BigEndian.Length - 1) -and $BigEndian[$start] -eq 0x00) {
        $start++
    }
    if ($start -gt 0) {
        $BigEndian = $BigEndian[$start..($BigEndian.Length - 1)]
    }

    # If the highest bit is set, prefix with 0x00 to keep integer positive.
    if (($BigEndian[0] -band 0x80) -ne 0) {
        $BigEndian = Join-Bytes -Parts @([byte[]]@([byte]0x00), $BigEndian)
    }

    $len = Der-Length -Length $BigEndian.Length
    return Join-Bytes -Parts @([byte[]]@([byte]0x02), $len, $BigEndian)
}

function Der-Sequence {
    param([Parameter(Mandatory = $true)][byte[]]$Content)
    $len = Der-Length -Length $Content.Length
    return Join-Bytes -Parts @([byte[]]@([byte]0x30), $len, $Content)
}

function Write-PemFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][byte[]]$Der
    )

    $b64 = [Convert]::ToBase64String($Der)
    $lines = [regex]::Matches($b64, ".{1,64}") | ForEach-Object { $_.Value }
    $pem = @(
        "-----BEGIN $Label-----"
        $lines
        "-----END $Label-----"
        ""
    ) -join "`r`n"

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -Path $Path -Value $pem -Encoding ascii
}

# Generate RSA key (CSP) so we can export private parameters easily on Windows PowerShell 5.1 (.NET Framework).
$rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider 2048

# Build a self-signed certificate for localhost.
$subject = "CN=$DnsName"
$hash = [System.Security.Cryptography.HashAlgorithmName]::SHA256
$pad = [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
$req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest $subject, $rsa, $hash, $pad

$san = New-Object System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder
$san.AddDnsName($DnsName)
$san.AddIpAddress([System.Net.IPAddress]::Parse("127.0.0.1"))
$req.CertificateExtensions.Add($san.Build())

$req.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension $false, $false, 0, $false))
$req.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509KeyUsageExtension (
    [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
    [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment
), $false))

$oids = New-Object System.Security.Cryptography.OidCollection
$oids.Add((New-Object System.Security.Cryptography.Oid "1.3.6.1.5.5.7.3.1")) | Out-Null # Server Authentication
$req.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension $oids, $false))

$notBefore = [DateTimeOffset]::Now.AddDays(-1)
$notAfter = [DateTimeOffset]::Now.AddYears(5)
$cert = $req.CreateSelfSigned($notBefore, $notAfter)

$certDer = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
Write-PemFile -Path $CertPath -Label "CERTIFICATE" -Der $certDer

# Export RSA private key as PKCS#1 (RSA PRIVATE KEY) DER.
$p = $rsa.ExportParameters($true)
$keyContent = Join-Bytes -Parts @(
    (Der-Integer -BigEndian ([byte[]]@([byte]0x00)))  # version
    (Der-Integer -BigEndian $p.Modulus)
    (Der-Integer -BigEndian $p.Exponent)
    (Der-Integer -BigEndian $p.D)
    (Der-Integer -BigEndian $p.P)
    (Der-Integer -BigEndian $p.Q)
    (Der-Integer -BigEndian $p.DP)
    (Der-Integer -BigEndian $p.DQ)
    (Der-Integer -BigEndian $p.InverseQ)
)
$keyDer = Der-Sequence -Content $keyContent
Write-PemFile -Path $KeyPath -Label "RSA PRIVATE KEY" -Der $keyDer

Write-Output "Generated dev TLS cert:"
Write-Output "  Cert: $CertPath"
Write-Output "  Key : $KeyPath"
