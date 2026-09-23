# ==============================================================================
# CTF-IA - Gestionnaire de challenges et serveur LLM mutualise (Windows PowerShell)
# ==============================================================================

param(
    [string]$Command = "",
    [string]$Arg1 = "",
    [string]$Arg2 = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$EnvFile = Join-Path $ScriptDir ".env"
$ModelsDir = Join-Path $ScriptDir "models"
$ProgressFile = Join-Path $ScriptDir ".progress"

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

# Configuration par defaut
$ModelFile = "qwen2.5-3b-instruct-q4_k_m.gguf"
$LlmThreads = "4"

# Charger .env si present
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)\s*=\s*(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($name -eq "MODEL_FILE") { $ModelFile = $value }
            if ($name -eq "LLM_THREADS") { $LlmThreads = $value }
        }
    }
}

# URLs Hugging Face
$Url3B = "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
$File3B = "qwen2.5-3b-instruct-q4_k_m.gguf"

$Url15B = "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
$File15B = "qwen2.5-1.5b-instruct-q4_k_m.gguf"

# 14 challenges
$ChNames = [ordered]@{
    "01" = "Sentinel (Assistant de securite)"
    "02" = "KnowledgeBot (Base documentaire)"
    "03" = "MailGuard (Filtre de messagerie)"
    "04" = "KnowledgeBot v2 (Base collaborative)"
    "05" = "OpsAgent (Gestionnaire d'incidents)"
    "06" = "PhishLearn (Detecteur adaptatif)"
    "07" = "AutoGrader (Plateforme d'evaluation)"
    "08" = "HelpDesk (Annuaire d'entreprise)"
    "09" = "OpsAssistant (Centre d'operations)"
    "10" = "Web Portal (Portail d'entreprise)"
    "11" = "Invoices (Portail de facturation)"
    "12" = "Intranet (Espace collaboratif)"
    "13" = "DocServer (Serveur documentaire)"
    "14" = "NetTools (Diagnostic reseau)"
}

# Briefings d'audit et objectifs par challenge (sans divulgation de solution)
$ChMissions = [ordered]@{
    "01" = "Extraire la cle secrete de validation confiee a l'assistant lors de son initialisation."
    "02" = "Acceder aux informations confidentielles du plan de continuite d'activite de l'entreprise."
    "03" = "Adapter l'email fourni pour qu'il soit classe comme legitime tout en respectant les contraintes."
    "04" = "Tirer parti des fonctionnalites de la plateforme pour extraire la cle de configuration de l'assistant."
    "05" = "Interagir avec l'assistant afin de recuperer le secret de restauration d'identite du serveur."
    "06" = "Utiliser vos contributions pour faire reclasser l'email de test actuellement bloque comme legitime."
    "07" = "Soumettre une reponse a l'exercice permettant d'obtenir la note maximale de 10/10."
    "08" = "Utiliser l'assistant pour acceder aux informations confidentielles d'un compte de direction."
    "09" = "Retrouver l'ensemble des 3 fragments de secours et soumettre la cle reconstituee."
    "10" = "Examiner les elements exposes publiquement par l'application pour retrouver le jeton de validation."
    "11" = "Retrouver et consulter une facture confidentielle appartenant a un autre compte de l'organisation."
    "12" = "Acceder a la zone d'administration restreinte de la plateforme pour en reveler le contenu."
    "13" = "Recuperer le fichier de configuration confidentiel conserve dans l'espace prive du serveur."
    "14" = "Demontrer la possibilite de lire les donnees confidentielles hebergees sur le serveur d'execution."
}

# Hashes SHA-256 des flags
$FlagHashes = @{
    "01" = @("e99d25b70999ab71352904c079e11bd198aa106f5f0ac615755480c3b035363b", "41fffe12d2150733ac92fa2d9c30e093f933efaf8b12defe886a09a231a677bf")
    "02" = @("85aacffa676232465934292cb5336ca294c6b4f47264141ffa54e8d884972055")
    "03" = @("9613ec07e91eb511b6473c9bc336e46f4ced6423ddabc85b4c598c0f5bae1690")
    "04" = @("315cdc042862944d45911060c151227b40ca0ecb823718a8400925129acb118d")
    "05" = @("d8fd185eaf05a1a18793e1a38e1d3dc3389264259672fc36e327c4a50341a270")
    "06" = @("9afdf8f6dd8b2bd62bef92717c7198d4c63ba9b6dddd6e991526af3d48d12fd6")
    "07" = @("9370b941e12b503ce37a1c2e8502d0b6b62646ebdaf6a017eb91873d70e20acf")
    "08" = @("2634c85c74888d435ebce9873a99294f8ef2a846f686e63a7161c85873e62104")
    "09" = @("51a1e870f25e071a33fa86144152e38897f1ddc8c812a33cb81f67d9589bbc82")
    "10" = @("ccc3da23d45d0b632ac06bdacef887473d6d06b87a7d69996412dead1d848f33", "fdbef3d5933555b163ff5ce34195689c709266094cf0a61de5d7e7050e46b320", "2543df8a03be5a8f6e596be25d998ed2ec090a77d7ce26057b5c14a492163d30", "a8f8b34bc6053e4140335261ba69f8c1969157eb84e23cb8b7f4c9b66be82047", "f9fb779b94de59f2fc87ade84bac8de8d0b3dc235f71ca380aff44ccaeff0ccd", "7c47cdac03d5c3259653478c4bee47e15fc3a82dbbe7edd79866c85c6cbf4036", "2fcc53b388843943d15bb0e9ab77fe3ce79f88e422b3fce44a46d4437a3ef0a9")
    "11" = @("da32bba1698e25511c1c511ebea5233ce098e2aae0d962082d3bfb02dafa2404")
    "12" = @("ae00aa2490cc10592c44aeb4f8d1c8e60dc7aabc82b2a2f9b4c134e84b481a3e")
    "13" = @("40d58f91bf007c6ee94c3888f7b1312e09cdf61a7fbcf2c058affd253d7fc3dc")
    "14" = @("904ec1e2b1b7e83976e693bf3339700510877a67d8377a32ab3a14218d9e676b")
}

function Get-Sha256([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text.Trim())
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-').ToLower()
}

function Test-DockerInstalled {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Write-Host "`n[ERREUR] Docker n'est pas installe sur ce systeme !" -ForegroundColor Red
        Write-Host "Le CTF necessite Docker Desktop pour executer les environnements des challenges." -ForegroundColor Yellow
        
        $installPrompt = Read-Host "Souhaitez-vous ouvrir la page officielle de telechargement de Docker Desktop ? (O/n)"
        if ($installPrompt -ne "n" -and $installPrompt -ne "N") {
            Start-Process "https://docs.docker.com/desktop/setup/install/windows-install/"
        }
        exit 1
    }
}

function Test-DockerRunning {
    Test-DockerInstalled
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERREUR] Docker Desktop n'est pas demarre !" -ForegroundColor Red
        Write-Host "Veuillez lancer l'application Docker Desktop depuis le menu Demarrer." -ForegroundColor Yellow
        Write-Host "Attendez que l'icone Docker dans la barre des taches devienne verte, puis relancez ce script." -ForegroundColor Yellow
        exit 1
    }
}

function Get-ActiveChallenge {
    $running = docker ps --filter "name=ctf-ch-" --format "{{.Names}}" 2>$null
    if ($running -match 'ctf-ch-(\d{2})') {
        return $matches[1]
    }
    return $null
}

function Test-LlmRunning {
    $running = docker ps --filter "name=ctf-llm" --format "{{.Names}}" 2>$null
    return ($running -eq "ctf-llm")
}

function Requires-Llm([string]$ch) {
    return @("01", "02", "04", "05", "07", "08", "09") -contains $ch
}

function Is-ChallengeSolved([string]$ch) {
    if (Test-Path $ProgressFile) {
        $lines = Get-Content $ProgressFile
        return ($lines -contains $ch)
    }
    return $false
}

function Get-SolvedCount {
    if (Test-Path $ProgressFile) {
        $lines = Get-Content $ProgressFile | Where-Object { $_ -match '^\d{2}$' } | Select-Object -Unique
        return @($lines).Count
    }
    return 0
}

function Wait-ForLlm {
    Write-Host "[INFO] Attente de la disponibilite du service..." -NoNewline -ForegroundColor Cyan
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get -TimeoutSec 2 -ErrorAction Stop
            Write-Host "`n[OK] Serveur LLM pret sur http://localhost:8080" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
    Write-Host "`n[ERREUR] Le serveur LLM ne repond pas." -ForegroundColor Red
    return $false
}

function Start-Llm {
    Test-DockerRunning
    if (Test-LlmRunning) {
        Write-Host "[OK] Le serveur LLM est deja actif sur http://localhost:8080" -ForegroundColor Green
        return $true
    }

    $dest = Join-Path $ModelsDir $ModelFile
    if (-not (Test-Path $dest)) {
        Write-Host "`n[ATTENTION] Modele '$ModelFile' introuvable dans models/ !" -ForegroundColor Yellow
        $choice = Read-Host "Telecharger le modele recommande (Qwen 2.5 3B, ~2 Go) maintenant ? (O/n)"
        if ($choice -ne "n" -and $choice -ne "N") {
            Download-Model "3b"
        } else {
            return $false
        }
    }

    Write-Host "[INFO] Demarrage du conteneur LLM ($ModelFile)..." -ForegroundColor Cyan
    $env:MODEL_FILE = $ModelFile
    $env:LLM_THREADS = $LlmThreads
    docker compose up -d llm

    return (Wait-ForLlm)
}

function Show-ChallengeInfo([string]$num) {
    if ($num -match '^[1-9]$') { $num = "0$num" }
    if (-not $ChNames.Contains($num)) {
        Write-Host "[ERREUR] Challenge '$num' inconnu (valeurs valides : 01 a 14)." -ForegroundColor Red
        return
    }
    Write-Host "`n------------------------------------------------------------" -ForegroundColor White
    Write-Host " Challenge $num : $($ChNames[$num])" -ForegroundColor Cyan
    Write-Host " URL     : http://localhost:8000" -ForegroundColor Cyan
    Write-Host " Mission : $($ChMissions[$num])" -ForegroundColor White
    Write-Host "------------------------------------------------------------`n" -ForegroundColor White
}

function Start-Challenge([string]$num) {
    Test-DockerRunning
    if ($num -match '^[1-9]$') { $num = "0$num" }
    
    if (-not $ChNames.Contains($num)) {
        Write-Host "[ERREUR] Challenge '$num' inconnu (valeurs valides : 01 a 14)." -ForegroundColor Red
        return
    }

    Write-Host "`n------------------------------------------------------------" -ForegroundColor White
    Write-Host "Challenge $num : $($ChNames[$num])" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------" -ForegroundColor White

    $current = Get-ActiveChallenge
    if ($current -eq $num) {
        Write-Host "[OK] Le Challenge $num est deja en cours d'execution sur http://localhost:8000" -ForegroundColor Green
        Write-Host "Mission : $($ChMissions[$num])" -ForegroundColor White
        return
    }

    if ($current) {
        Write-Host "[INFO] Arret du Challenge $current..." -ForegroundColor Yellow
        docker compose stop "challenge_$current" | Out-Null
    }

    if (Requires-Llm $num) {
        if (-not (Test-LlmRunning)) {
            Write-Host "[INFO] Ce challenge requiert le backend LLM." -ForegroundColor Cyan
            if (-not (Start-Llm)) {
                Write-Host "[ERREUR] Impossible de lancer le challenge $num sans backend LLM." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "[OK] Backend LLM actif." -ForegroundColor Green
        }
    }

    Write-Host "[INFO] Demarrage du Challenge $num..." -ForegroundColor Cyan
    $env:MODEL_FILE = $ModelFile
    $env:LLM_THREADS = $LlmThreads
    docker compose up -d "challenge_$num"

    Write-Host "`n------------------------------------------------------------" -ForegroundColor Green
    Write-Host " [OK] Challenge $num demarre : $($ChNames[$num])" -ForegroundColor Green
    Write-Host " URL     : http://localhost:8000" -ForegroundColor Cyan
    Write-Host " Mission : $($ChMissions[$num])" -ForegroundColor White
    Write-Host "------------------------------------------------------------`n" -ForegroundColor Green
}

function Stop-ActiveChallenge {
    Test-DockerRunning
    $current = Get-ActiveChallenge
    if ($current) {
        Write-Host "[INFO] Arret du Challenge $current..." -ForegroundColor Yellow
        docker compose stop "challenge_$current"
        Write-Host "[OK] Challenge $current arrete." -ForegroundColor Green
    } else {
        Write-Host "[INFO] Aucun challenge en cours d'execution." -ForegroundColor Gray
    }
}

function Stop-All {
    Test-DockerRunning
    Write-Host "[INFO] Arret de l'ensemble des conteneurs..." -ForegroundColor Yellow
    docker compose down
    Write-Host "[OK] Tous les conteneurs sont arretes." -ForegroundColor Green
}

function Validate-Flag([string]$ch, [string]$flag) {
    if (-not $ch) {
        $ch = Get-ActiveChallenge
        if (-not $ch) {
            Write-Host "[ERREUR] Aucun challenge actif detecte." -ForegroundColor Red
            Write-Host "Usage: .\ctf.ps1 flag <01-14> <FLAG{...}>" -ForegroundColor Yellow
            return
        }
    }

    if ($ch -match '^[1-9]$') { $ch = "0$ch" }

    if (-not $ChNames.Contains($ch)) {
        Write-Host "[ERREUR] Challenge '$ch' invalide (01 a 14)." -ForegroundColor Red
        return
    }

    if (-not $flag) {
        $flag = Read-Host "Entrez le flag pour le Challenge $ch ($($ChNames[$ch]))"
    }

    $flag = $flag.Trim()
    if (-not $flag) {
        Write-Host "[ERREUR] Flag vide." -ForegroundColor Red
        return
    }

    $inputHash = Get-Sha256 $flag
    $expectedHashes = $FlagHashes[$ch]

    if ($expectedHashes -contains $inputHash) {
        $already = Is-ChallengeSolved $ch
        if (-not $already) {
            Add-Content -Path $ProgressFile -Value $ch
            $count = Get-SolvedCount
            Write-Host "`n[BRAVO] Flag valide ! Challenge $ch valide avec succes." -ForegroundColor Green
            Write-Host "Progression : $count / 14 challenges resolus.`n" -ForegroundColor Cyan
        } else {
            $count = Get-SolvedCount
            Write-Host "`n[OK] Flag valide ! (Challenge $ch deja comptabilise)" -ForegroundColor Green
            Write-Host "Progression : $count / 14 challenges resolus.`n" -ForegroundColor Cyan
        }
    } else {
        Write-Host "`n[INCORRECT] Flag incorrect pour le Challenge $ch. Reessayez !`n" -ForegroundColor Red
    }
}

function Show-Score {
    $count = Get-SolvedCount
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " CTF-IA - Progression des epreuves : $count / 14 resolus" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    foreach ($key in $ChNames.Keys) {
        if (Is-ChallengeSolved $key) {
            Write-Host "  [$key] $($ChNames[$key]) " -NoNewline
            Write-Host "[RESOLU]" -ForegroundColor Green
        } else {
            Write-Host "  [$key] $($ChNames[$key]) " -NoNewline
            Write-Host "[NON RESOLU]" -ForegroundColor Gray
        }
    }
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

function Download-Model([string]$choice) {
    $targetFile = ""
    $targetUrl = ""

    if ($choice -eq "3b" -or $choice -eq "1") {
        $targetFile = $File3B
        $targetUrl = $Url3B
    } elseif ($choice -eq "1.5b" -or $choice -eq "2") {
        $targetFile = $File15B
        $targetUrl = $Url15B
    } else {
        Write-Host "`nSelection du modele a telecharger :" -ForegroundColor Yellow
        Write-Host "  [1] Qwen 2.5 3B  (Recommande - ~2.0 Go)"
        Write-Host "  [2] Qwen 2.5 1.5B (Optionnel   - ~1.1 Go)"
        $sub = Read-Host "Choix [1-2]"
        if ($sub -eq "2") {
            $targetFile = $File15B
            $targetUrl = $Url15B
        } else {
            $targetFile = $File3B
            $targetUrl = $Url3B
        }
    }

    $dest = Join-Path $ModelsDir $targetFile
    if (Test-Path $dest) {
        Write-Host "[INFO] Le modele $targetFile est deja present dans models/." -ForegroundColor Green
        $re = Read-Host "Retelecharger le fichier ? (o/N)"
        if ($re -ne "o" -and $re -ne "O") { return }
    }

    Write-Host "`n[INFO] Telechargement de $targetFile..." -ForegroundColor Cyan
    Write-Host "Source : $targetUrl" -ForegroundColor Gray
    Write-Host "Cible  : $dest`n" -ForegroundColor Gray

    # Utiliser curl.exe si dispo (standard sur Windows 10/11) pour barre de progression
    $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCmd) {
        & curl.exe -L --progress-bar -C - $targetUrl -o $dest
    } else {
        Start-BitsTransfer -Source $targetUrl -Destination $dest -Description "Telechargement modele CTF-IA"
    }

    if (Test-Path $dest) {
        Write-Host "`n[OK] Telechargement termine : $dest" -ForegroundColor Green
    }
}

function Configure-Model {
    Write-Host "`nModeles disponibles :" -ForegroundColor Cyan
    Write-Host "  [1] Qwen 2.5 3B  (qwen2.5-3b-instruct-q4_k_m.gguf) [Recommande]"
    Write-Host "  [2] Qwen 2.5 1.5B (qwen2.5-1.5b-instruct-q4_k_m.gguf) [Ultra-leger]"
    $choice = Read-Host "Choix [1-2]"

    $newModel = ""
    if ($choice -eq "2") {
        $newModel = $File15B
    } else {
        $newModel = $File3B
    }

    $dest = Join-Path $ModelsDir $newModel
    if (-not (Test-Path $dest)) {
        $down = Read-Host "Modele absent de models/. Le telecharger maintenant ? (O/n)"
        if ($down -ne "n" -and $down -ne "N") {
            if ($choice -eq "2") { Download-Model "1.5b" } else { Download-Model "3b" }
        }
    }

    $script:ModelFile = $newModel
    Set-Content -Path $EnvFile -Value "# Configuration CTF-IA`nMODEL_FILE=$ModelFile`nLLM_THREADS=$LlmThreads"
    Write-Host "[OK] Modele actif : $ModelFile" -ForegroundColor Green

    if (Test-LlmRunning) {
        Write-Host "[INFO] Redemarrage du LLM avec $ModelFile..." -ForegroundColor Cyan
        docker compose stop llm | Out-Null
        Start-Llm | Out-Null
    }
}

function Test-Llm {
    Test-DockerRunning
    if (-not (Test-LlmRunning)) {
        Write-Host "[ERREUR] Le serveur LLM n'est pas demarre." -ForegroundColor Red
        return
    }

    Write-Host "[INFO] Envoi d'une requete de test au modele $ModelFile..." -ForegroundColor Cyan
    $body = @{
        messages = @(
            @{ role = "user"; content = "Reponds brievement : es-tu operationnel ?" }
        )
        max_tokens = 50
    } | ConvertTo-Json

    try {
        $res = Invoke-RestMethod -Uri "http://localhost:8080/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30
        Write-Host "[OK] Reponse recue du modele :" -ForegroundColor Green
        Write-Host $res.choices[0].message.content -ForegroundColor White
    } catch {
        Write-Host "[ERREUR] Echec de la requete test : $_" -ForegroundColor Red
    }
}

function Show-Logs {
    Test-DockerRunning
    $current = Get-ActiveChallenge
    Write-Host "`nAffichage des logs :" -ForegroundColor Cyan
    if ($current) {
        Write-Host "  [1] Challenge actif ($current)"
    } else {
        Write-Host "  [1] Challenge actif (aucun en cours)"
    }
    Write-Host "  [2] Serveur LLM"
    $c = Read-Host "Choix [1-2]"
    if ($c -eq "2") {
        docker compose logs -f llm
    } elseif ($current) {
        docker compose logs -f "challenge_$current"
    } else {
        Write-Host "Aucun challenge en cours d'execution." -ForegroundColor Yellow
    }
}

function Show-Menu {
    Test-DockerInstalled
    Clear-Host
    
    $dockerOk = $false
    $null = docker info 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }

    $activeCh = Get-ActiveChallenge
    $llmOk = Test-LlmRunning
    $solved = Get-SolvedCount

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   CTF-IA : Cybersecurity & Artificial Intelligence (Win)   " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    if ($dockerOk) {
        Write-Host " Docker  : " -NoNewline; Write-Host "Actif" -ForegroundColor Green
    } else {
        Write-Host " Docker  : " -NoNewline; Write-Host "Non demarre (Lancez Docker Desktop)" -ForegroundColor Red
    }

    if ($llmOk) {
        Write-Host " LLM     : " -NoNewline; Write-Host "En ligne (http://localhost:8080 | $ModelFile)" -ForegroundColor Green
    } else {
        Write-Host " LLM     : " -NoNewline; Write-Host "Arrete ($ModelFile)" -ForegroundColor Gray
    }

    if ($activeCh) {
        Write-Host " Actif   : " -NoNewline; Write-Host "Challenge $activeCh - $($ChNames[$activeCh]) (http://localhost:8000)" -ForegroundColor Yellow
    } else {
        Write-Host " Actif   : " -NoNewline; Write-Host "Aucun challenge en cours" -ForegroundColor Gray
    }
    
    Write-Host " Score   : " -NoNewline; Write-Host "$solved / 14 resolus" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Host "`n[SECURITE LLM]" -ForegroundColor White
    @("01", "02", "04", "05", "07", "08", "09") | ForEach-Object {
        $prefix = if ($activeCh -eq $_) { "  * " } else { "    " }
        Write-Host "$prefix[$_] $($ChNames[$_])" -NoNewline
        if (Is-ChallengeSolved $_) { Write-Host " [RESOLU]" -ForegroundColor Green } else { Write-Host "" }
    }

    Write-Host "`n[MACHINE LEARNING CLASSIQUE]" -ForegroundColor White
    @("03", "06") | ForEach-Object {
        $prefix = if ($activeCh -eq $_) { "  * " } else { "    " }
        Write-Host "$prefix[$_] $($ChNames[$_])" -NoNewline
        if (Is-ChallengeSolved $_) { Write-Host " [RESOLU]" -ForegroundColor Green } else { Write-Host "" }
    }

    Write-Host "`n[SECURITE WEB CLASSIQUE]" -ForegroundColor White
    @("10", "11", "12", "13", "14") | ForEach-Object {
        $prefix = if ($activeCh -eq $_) { "  * " } else { "    " }
        Write-Host "$prefix[$_] $($ChNames[$_])" -NoNewline
        if (Is-ChallengeSolved $_) { Write-Host " [RESOLU]" -ForegroundColor Green } else { Write-Host "" }
    }

    Write-Host "`n[ACTIONS GLOBALES]" -ForegroundColor White
    Write-Host "    [f] Valider un flag"
    Write-Host "    [i] Briefing de mission"
    Write-Host "    [s] Arreter le challenge actif"
    Write-Host "    [S] Arreter TOUT (challenge + LLM)"
    Write-Host "    [m] Changer de modele LLM"
    Write-Host "    [d] Telecharger un modele GGUF"
    Write-Host "    [t] Tester le serveur LLM"
    Write-Host "    [l] Voir les logs"
    Write-Host "    [q] Quitter"
    Write-Host "============================================================" -ForegroundColor Cyan

    $choice = Read-Host "Commande [01-14 ou action]"
    switch ($choice) {
        "q" { exit 0 }
        "f" { Validate-Flag; break }
        "i" {
            $ch = Read-Host "Numero du challenge (01-14)"
            Show-ChallengeInfo $ch
            Read-Host "Appuyez sur Entree pour continuer..."
            break
        }
        "s" { Stop-ActiveChallenge; break }
        "S" { Stop-All; break }
        "m" { Configure-Model; break }
        "d" { Download-Model ""; break }
        "t" { Test-Llm; break }
        "l" { Show-Logs; break }
        default {
            if ($choice -match '^\d+$') {
                Start-Challenge $choice
            }
        }
    }
}

# --- Point d'entree CLI ---
switch ($Command) {
    "start"    { Start-Challenge $Arg1 }
    "info"     { Show-ChallengeInfo $Arg1 }
    "mission"  { Show-ChallengeInfo $Arg1 }
    "stop"     { if ($Arg1 -eq "all") { Stop-All } else { Stop-ActiveChallenge } }
    "flag"     { Validate-Flag $Arg1 $Arg2 }
    "score"    { Show-Score }
    "download" { Download-Model $Arg1 }
    "model"    { Configure-Model }
    "test"     { Test-Llm }
    "logs"     { Show-Logs }
    default    { Show-Menu }
}
