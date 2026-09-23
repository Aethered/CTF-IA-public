#!/usr/bin/env bash
# ==============================================================================
# CTF-IA - Gestionnaire de challenges et serveur LLM mutualise
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

# Fichiers et repertoires
ENV_FILE="$DIR/.env"
MODELS_DIR="$DIR/models"
mkdir -p "$MODELS_DIR"

# Charger .env si present
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

MODEL_FILE="${MODEL_FILE:-qwen2.5-3b-instruct-q4_k_m.gguf}"
LLM_THREADS="${LLM_THREADS:-4}"

# Sources Hugging Face
URL_3B="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
FILE_3B="qwen2.5-3b-instruct-q4_k_m.gguf"

URL_1_5B="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
FILE_1_5B="qwen2.5-1.5b-instruct-q4_k_m.gguf"

# Couleurs ANSI standard
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_CYAN=$'\033[36m'
C_GRAY=$'\033[90m'

# Liste des 14 challenges
declare -A CH_NAMES
CH_NAMES["01"]="Prompt Injection Directe (Sentinel)"
CH_NAMES["02"]="RAG Access Control Bypass (KnowledgeBot)"
CH_NAMES["03"]="Machine Learning Evasion (MailGuard)"
CH_NAMES["04"]="Indirect Prompt Injection (KnowledgeBot)"
CH_NAMES["05"]="OpsAgent - Insecure Tool Execution"
CH_NAMES["06"]="Data Poisoning (PhishLearn)"
CH_NAMES["07"]="LLM-as-a-judge Jailbreak (AutoGrader)"
CH_NAMES["08"]="Agent IDOR / BOLA (HelpDesk)"
CH_NAMES["09"]="Full AI Kill-Chain (OpsAssistant)"
CH_NAMES["10"]="Web Basics (Source, Headers, Cookies)"
CH_NAMES["11"]="Web - IDOR (Invoices)"
CH_NAMES["12"]="Web - Client-side Tampering"
CH_NAMES["13"]="Web - Path Traversal (DocServer)"
CH_NAMES["14"]="Web - Command Injection (PingDiag)"

# Suivi de progression locale
PROGRESS_FILE="$DIR/.progress"

# Empreintes SHA-256 des flags (verification securisee sans divulgation en clair)
declare -A FLAG_HASHES
FLAG_HASHES["01"]="e99d25b70999ab71352904c079e11bd198aa106f5f0ac615755480c3b035363b 41fffe12d2150733ac92fa2d9c30e093f933efaf8b12defe886a09a231a677bf"
FLAG_HASHES["02"]="85aacffa676232465934292cb5336ca294c6b4f47264141ffa54e8d884972055"
FLAG_HASHES["03"]="9613ec07e91eb511b6473c9bc336e46f4ced6423ddabc85b4c598c0f5bae1690"
FLAG_HASHES["04"]="315cdc042862944d45911060c151227b40ca0ecb823718a8400925129acb118d"
FLAG_HASHES["05"]="d8fd185eaf05a1a18793e1a38e1d3dc3389264259672fc36e327c4a50341a270"
FLAG_HASHES["06"]="9afdf8f6dd8b2bd62bef92717c7198d4c63ba9b6dddd6e991526af3d48d12fd6"
FLAG_HASHES["07"]="9370b941e12b503ce37a1c2e8502d0b6b62646ebdaf6a017eb91873d70e20acf"
FLAG_HASHES["08"]="2634c85c74888d435ebce9873a99294f8ef2a846f686e63a7161c85873e62104"
FLAG_HASHES["09"]="51a1e870f25e071a33fa86144152e38897f1ddc8c812a33cb81f67d9589bbc82"
FLAG_HASHES["10"]="ccc3da23d45d0b632ac06bdacef887473d6d06b87a7d69996412dead1d848f33 fdbef3d5933555b163ff5ce34195689c709266094cf0a61de5d7e7050e46b320 2543df8a03be5a8f6e596be25d998ed2ec090a77d7ce26057b5c14a492163d30 a8f8b34bc6053e4140335261ba69f8c1969157eb84e23cb8b7f4c9b66be82047 f9fb779b94de59f2fc87ade84bac8de8d0b3dc235f71ca380aff44ccaeff0ccd 7c47cdac03d5c3259653478c4bee47e15fc3a82dbbe7edd79866c85c6cbf4036 2fcc53b388843943d15bb0e9ab77fe3ce79f88e422b3fce44a46d4437a3ef0a9"
FLAG_HASHES["11"]="da32bba1698e25511c1c511ebea5233ce098e2aae0d962082d3bfb02dafa2404"
FLAG_HASHES["12"]="ae00aa2490cc10592c44aeb4f8d1c8e60dc7aabc82b2a2f9b4c134e84b481a3e"
FLAG_HASHES["13"]="40d58f91bf007c6ee94c3888f7b1312e09cdf61a7fbcf2c058affd253d7fc3dc"
FLAG_HASHES["14"]="904ec1e2b1b7e83976e693bf3339700510877a67d8377a32ab3a14218d9e676b"

# Verifie si un challenge a deja ete valide
is_challenge_solved() {
    local ch="$1"
    [ -f "$PROGRESS_FILE" ] && grep -qx "$ch" "$PROGRESS_FILE" 2>/dev/null
}

# Nombre de challenges resolus
get_solved_count() {
    if [ -f "$PROGRESS_FILE" ]; then
        sort -u "$PROGRESS_FILE" | grep -E '^[0-9]{2}$' | wc -l
    else
        echo "0"
    fi
}

# Verification de dependance LLM
requires_llm() {
    local ch="$1"
    case "$ch" in
        "01"|"02"|"04"|"05"|"07"|"08"|"09") return 0 ;;
        *) return 1 ;;
    esac
}

# Detection du challenge en cours
get_active_challenge() {
    local running
    running=$(docker ps --filter "name=ctf-ch-" --format "{{.Names}}" 2>/dev/null | head -n 1)
    if [ -n "$running" ]; then
        echo "${running#ctf-ch-}"
    else
        echo ""
    fi
}

# Statut du conteneur LLM
is_llm_running() {
    curl -sf "http://127.0.0.1:8080/health" >/dev/null 2>&1
}

# Telechargement d'un modele
download_model() {
    local choice="$1"
    local target_file=""
    local target_url=""

    if [ "$choice" = "3b" ] || [ "$choice" = "1" ]; then
        target_file="$FILE_3B"
        target_url="$URL_3B"
    elif [ "$choice" = "1.5b" ] || [ "$choice" = "2" ]; then
        target_file="$FILE_1_5B"
        target_url="$URL_1_5B"
    else
        echo -e "${C_YELLOW}Selection du modele a telecharger :${C_RESET}"
        echo -e "  [1] Qwen 2.5 3B  (Recommande - ~2.0 Go)"
        echo -e "  [2] Qwen 2.5 1.5B (Optionnel   - ~1.1 Go)"
        read -rp "Choix [1-2] : " sub_choice
        if [ "$sub_choice" = "2" ]; then
            target_file="$FILE_1_5B"
            target_url="$URL_1_5B"
        else
            target_file="$FILE_3B"
            target_url="$URL_3B"
        fi
    fi

    local dest="$MODELS_DIR/$target_file"

    if [ -f "$dest" ]; then
        echo -e "${C_GREEN}[INFO] Le modele $target_file est deja present dans models/.${C_RESET}"
        read -rp "Retelecharger le fichier ? (o/N) : " re
        if [[ ! "$re" =~ ^[oOyY]$ ]]; then
            return 0
        fi
    fi

    echo -e "\n${C_CYAN}[INFO] Telechargement de $target_file...${C_RESET}"
    echo -e "${C_GRAY}Source : $target_url${C_RESET}"
    echo -e "${C_GRAY}Cible  : $dest${C_RESET}\n"

    if command -v curl >/dev/null 2>&1; then
        if ! curl -L --progress-bar -C - "$target_url" -o "$dest"; then
            echo -e "${C_RED}[ERREUR] Echec du telechargement via curl.${C_RESET}"
            rm -f "$dest"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget --show-progress -c "$target_url" -O "$dest"; then
            echo -e "${C_RED}[ERREUR] Echec du telechargement via wget.${C_RESET}"
            rm -f "$dest"
            return 1
        fi
    else
        echo -e "${C_RED}[ERREUR] curl ou wget requis.${C_RESET}"
        return 1
    fi

    echo -e "\n${C_GREEN}[OK] Telechargement termine.${C_RESET}"
}

# Demarrage du serveur LLM
start_llm() {
    local target_model="$MODELS_DIR/$MODEL_FILE"

    if [ ! -f "$target_model" ]; then
        echo -e "${C_YELLOW}[WARN] Le modele $MODEL_FILE est absent de ./models/${C_RESET}"
        read -rp "Lancer le telechargement ? (O/n) : " rep
        if [[ "$rep" =~ ^[nN]$ ]]; then
            echo -e "${C_RED}[ERREUR] Fichier modele requis pour continuer.${C_RESET}"
            return 1
        fi
        if [[ "$MODEL_FILE" == *"3b"* ]]; then
            download_model "3b" || return 1
        else
            download_model "1.5b" || return 1
        fi
    fi

    if [ ! -f "$target_model" ]; then
        echo -e "${C_RED}[ERREUR] Fichier modele $MODEL_FILE introuvable dans ./models/${C_RESET}"
        return 1
    fi

    if is_llm_running; then
        echo -e "${C_GREEN}[OK] Serveur LLM deja actif sur le port 8080.${C_RESET}"
        return 0
    fi

    echo -e "${C_CYAN}[INFO] Demarrage du conteneur LLM ($MODEL_FILE)...${C_RESET}"
    MODEL_FILE="$MODEL_FILE" LLM_THREADS="$LLM_THREADS" docker compose up -d llm

    echo -ne "${C_YELLOW}[INFO] Attente de la disponibilite du service...${C_RESET}"
    for i in {1..30}; do
        if is_llm_running; then
            echo -e "\n${C_GREEN}[OK] Serveur LLM pret sur http://localhost:8080${C_RESET}"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo -e "\n${C_RED}[ERREUR] Le conteneur LLM a demarre mais ne repond pas sur le port 8080.${C_RESET}"
    echo -e "${C_GRAY}Verifiez les logs avec : ./ctf.sh logs ou docker logs ctf-llm${C_RESET}"
    return 1
}

# Arret du serveur LLM
stop_llm() {
    echo -e "${C_CYAN}[INFO] Arret du serveur LLM...${C_RESET}"
    docker compose stop llm
    echo -e "${C_GREEN}[OK] Serveur LLM arrete.${C_RESET}"
}

# Configuration du modele
switch_model() {
    echo -e "\n${C_BOLD}Selection du modele :${C_RESET}"
    echo -e "  [1] Qwen 2.5 3B  (Recommande - ~2.0 Go)"
    echo -e "  [2] Qwen 2.5 1.5B (Optionnel   - ~1.1 Go)"
    read -rp "Choix [1-2] : " m_choice

    local new_model=""
    if [ "$m_choice" = "2" ]; then
        new_model="$FILE_1_5B"
    else
        new_model="$FILE_3B"
    fi

    if [ ! -f "$MODELS_DIR/$new_model" ]; then
        echo -e "${C_YELLOW}[WARN] $new_model n'est pas encore telecharge.${C_RESET}"
        read -rp "Telecharger maintenant ? (O/n) : " yn
        if [[ ! "$yn" =~ ^[nN]$ ]]; then
            if [ "$m_choice" = "2" ]; then
                download_model "1.5b"
            else
                download_model "3b"
            fi
        fi
    fi

    MODEL_FILE="$new_model"
    cat <<EOF > "$ENV_FILE"
# Configuration CTF-IA
MODEL_FILE=$MODEL_FILE
LLM_THREADS=$LLM_THREADS
EOF
    echo -e "${C_GREEN}[OK] Modele actif : $MODEL_FILE${C_RESET}"

    if is_llm_running; then
        echo -e "${C_CYAN}[INFO] Redemarrage du LLM avec $MODEL_FILE...${C_RESET}"
        docker compose stop llm
        start_llm
    fi
}

# Lancement d'un challenge
start_challenge() {
    local num="$1"

    if [[ "$num" =~ ^[1-9]$ ]]; then
        num="0$num"
    fi

    local service="challenge_$num"

    if [ -z "${CH_NAMES[$num]}" ]; then
        echo -e "${C_RED}[ERREUR] Challenge '$num' inconnu (valeurs valides : 01 a 14).${C_RESET}"
        return 1
    fi

    echo -e "\n${C_BOLD}------------------------------------------------------------${C_RESET}"
    echo -e "${C_BOLD}Challenge $num : ${CH_NAMES[$num]}${C_RESET}"
    echo -e "${C_BOLD}------------------------------------------------------------${C_RESET}"

    local current
    current=$(get_active_challenge)
    if [ "$current" = "$num" ]; then
        echo -e "${C_GREEN}[OK] Le Challenge $num est deja en cours d'execution sur http://localhost:8000${C_RESET}"
        return 0
    fi

    if [ -n "$current" ]; then
        echo -e "${C_YELLOW}[INFO] Arret du Challenge $current...${C_RESET}"
        docker compose stop "challenge_$current"
    fi

    if requires_llm "$num"; then
        if ! is_llm_running; then
            echo -e "${C_CYAN}[INFO] Ce challenge requiert le backend LLM.${C_RESET}"
            if ! start_llm; then
                echo -e "${C_RED}[ERREUR] Impossible de lancer le challenge $num sans backend LLM.${C_RESET}"
                return 1
            fi
        else
            echo -e "${C_GREEN}[OK] Backend LLM actif.${C_RESET}"
        fi
    fi

    echo -e "${C_CYAN}[INFO] Demarrage du Challenge $num...${C_RESET}"
    MODEL_FILE="$MODEL_FILE" LLM_THREADS="$LLM_THREADS" docker compose up -d "$service"

    echo -e "\n${C_GREEN}------------------------------------------------------------${C_RESET}"
    echo -e " ${C_BOLD}${C_GREEN}[OK] Challenge $num demarre${C_RESET}"
    echo -e " URL : ${C_BOLD}${C_CYAN}http://localhost:8000${C_RESET}"
    echo -e "${C_GREEN}------------------------------------------------------------${C_RESET}\n"
}

# Arret du challenge actif
stop_active_challenge() {
    local current
    current=$(get_active_challenge)
    if [ -n "$current" ]; then
        echo -e "${C_YELLOW}[INFO] Arret du Challenge $current...${C_RESET}"
        docker compose stop "challenge_$current"
        echo -e "${C_GREEN}[OK] Challenge $current arrete.${C_RESET}"
    else
        echo -e "${C_GRAY}[INFO] Aucun challenge en cours d'execution.${C_RESET}"
    fi
}

# Arret global
stop_all() {
    echo -e "${C_YELLOW}[INFO] Arret de l'ensemble des conteneurs...${C_RESET}"
    docker compose down
    echo -e "${C_GREEN}[OK] Tous les conteneurs sont arretes.${C_RESET}"
}

# Test d'inference
test_llm() {
    if ! is_llm_running; then
        echo -e "${C_RED}[ERREUR] Le serveur LLM n'est pas demarre.${C_RESET}"
        return 1
    fi

    echo -e "${C_CYAN}[INFO] Test de requete sur http://localhost:8080...${C_RESET}"
    local prompt='{"messages":[{"role":"user","content":"Reponds simplement par : OK"}],"max_tokens":10,"temperature":0.0}'

    local res
    res=$(curl -s -X POST "http://localhost:8080/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "$prompt" 2>/dev/null || echo "")

    if echo "$res" | grep -q "choices"; then
        local reply
        reply=$(echo "$res" | grep -o '"content": *"[^"]*"' | head -n 1 | cut -d'"' -f4)
        echo -e "${C_GREEN}[OK] Reponse du serveur LLM :${C_RESET} \"$reply\""
    else
        echo -e "${C_RED}[ERREUR] Reponse inattendue du serveur LLM :${C_RESET}"
        echo "$res"
    fi
}

# Consultation des journaux
show_logs() {
    local current
    current=$(get_active_challenge)
    echo -e "Affichage des logs :"
    echo -e "  [1] Challenge actif ($current)"
    echo -e "  [2] Serveur LLM"
    read -rp "Choix [1-2] : " l_choice
    if [ "$l_choice" = "2" ]; then
        docker compose logs --tail=50 -f llm
    elif [ -n "$current" ]; then
        docker compose logs --tail=50 -f "challenge_$current"
    else
        echo -e "${C_YELLOW}[WARN] Aucun challenge actif.${C_RESET}"
    fi
}

# Validation d'un flag
validate_flag() {
    local ch="$1"
    local input_flag="$2"
    local active_ch
    active_ch=$(get_active_challenge)

    if [ -z "$ch" ]; then
        if [ -n "$active_ch" ]; then
            echo -e "\n${C_CYAN}[INFO] Challenge actif : $active_ch - ${CH_NAMES[$active_ch]}${C_RESET}"
            read -rp "Valider le flag pour ce challenge ($active_ch) ? [O/n] : " confirm
            if [[ "$confirm" =~ ^[nN]$ ]]; then
                read -rp "Numero du challenge cible [01-14] : " ch
            else
                ch="$active_ch"
            fi
        else
            echo -e "\n${C_YELLOW}[INFO] Aucun challenge n'est actuellement actif.${C_RESET}"
            read -rp "Numero du challenge a valider [01-14] : " ch
        fi
    fi

    # Si l'utilisateur a passe directement le flag en premier argument sans numero
    if [[ "$ch" =~ ^FLAG\{.*\}$ ]] && [ -n "$active_ch" ] && [ -z "$input_flag" ]; then
        input_flag="$ch"
        ch="$active_ch"
    fi

    if [[ "$ch" =~ ^[1-9]$ ]]; then
        ch="0$ch"
    fi

    if [ -z "${CH_NAMES[$ch]}" ]; then
        echo -e "${C_RED}[ERREUR] Challenge '$ch' invalide (valeurs possibles : 01 a 14).${C_RESET}"
        return 1
    fi

    if [ -z "$input_flag" ]; then
        echo -e "\nValidation pour : ${C_BOLD}Challenge $ch - ${CH_NAMES[$ch]}${C_RESET}"
        read -rp "Entrez le flag : " input_flag
    fi

    input_flag=$(echo "$input_flag" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [ -z "$input_flag" ]; then
        echo -e "${C_RED}[ERREUR] Aucun flag fourni.${C_RESET}"
        return 1
    fi

    local hashed=""
    if command -v sha256sum >/dev/null 2>&1; then
        hashed=$(echo -n "$input_flag" | sha256sum | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        hashed=$(echo -n "$input_flag" | shasum -a 256 | awk '{print $1}')
    elif command -v python3 >/dev/null 2>&1; then
        hashed=$(python3 -c "import hashlib, sys; sys.stdout.write(hashlib.sha256(sys.argv[1].encode()).hexdigest())" "$input_flag")
    fi

    if [ -z "$hashed" ]; then
        echo -e "${C_RED}[ERREUR] Impossible de calculer l'empreinte SHA-256 (sha256sum ou python3 requis).${C_RESET}"
        return 1
    fi

    local valid_hashes="${FLAG_HASHES[$ch]}"
    local success=false

    for h in $valid_hashes; do
        if [ "$hashed" = "$h" ]; then
            success=true
            break
        fi
    done

    if [ "$success" = "true" ]; then
        if is_challenge_solved "$ch"; then
            echo -e "\n${C_GREEN}[OK] Flag valide ! (Challenge $ch deja comptabilise)${C_RESET}"
        else
            echo "$ch" >> "$PROGRESS_FILE"
            echo -e "\n${C_GREEN}[BRAVO] Flag valide ! Challenge $ch valide avec succes.${C_RESET}"
        fi
        local total
        total=$(get_solved_count)
        echo -e "${C_CYAN}Progression : $total / 14 challenges resolus.${C_RESET}\n"
        return 0
    else
        echo -e "\n${C_RED}[ERREUR] Flag incorrect pour le Challenge $ch. Verifiez votre saisie.${C_RESET}\n"
        return 1
    fi
}

# Affichage du score
show_score() {
    local solved
    solved=$(get_solved_count)
    echo -e "${C_BOLD}Progression : $solved / 14 challenges resolus${C_RESET}"
    if [ -f "$PROGRESS_FILE" ]; then
        echo -ne "${C_GREEN}Challenges resolus :${C_RESET} "
        sort -u "$PROGRESS_FILE" | grep -E '^[0-9]{2}$' | tr '\n' ' '
        echo ""
    fi
}

# Interface interactive
interactive_menu() {
    while true; do
        clear
        local active_ch
        active_ch=$(get_active_challenge)
        local llm_status
        if is_llm_running; then
            llm_status="${C_GREEN}ACTIF (port 8080)${C_RESET}"
        else
            llm_status="${C_RED}INACTIF${C_RESET}"
        fi

        local model_status
        if [ -f "$MODELS_DIR/$MODEL_FILE" ]; then
            model_status="${C_GREEN}$MODEL_FILE [present]${C_RESET}"
        else
            model_status="${C_RED}$MODEL_FILE [manquant - option d]${C_RESET}"
        fi

        local solved_count
        solved_count=$(get_solved_count)

        echo -e "${C_BOLD}=== GESTIONNAIRE CTF-IA ===${C_RESET}"
        echo -e "Challenge actif : $([ -n "$active_ch" ] && echo -e "${C_BOLD}${C_GREEN}Challenge $active_ch - ${CH_NAMES[$active_ch]} (http://localhost:8000)${C_RESET}" || echo -e "${C_GRAY}Aucun${C_RESET}")"
        echo -e "Serveur LLM     : $llm_status"
        echo -e "Modele          : $model_status"
        echo -e "Progression     : ${C_BOLD}${C_CYAN}$solved_count / 14 challenges resolus${C_RESET}"
        echo -e "------------------------------------------------------------"

        echo -e "${C_BOLD}[SECURITE LLM]${C_RESET}"
        for c in 01 02 04 05 07 08 09; do
            local mark=" "
            [ "$active_ch" = "$c" ] && mark="*"
            local solved_mark=""
            is_challenge_solved "$c" && solved_mark=" ${C_GREEN}[RESOLU]${C_RESET}"
            echo -e "  $mark [$c] ${CH_NAMES[$c]}$solved_mark"
        done

        echo -e "\n${C_BOLD}[MACHINE LEARNING CLASSIQUE]${C_RESET}"
        for c in 03 06; do
            local mark=" "
            [ "$active_ch" = "$c" ] && mark="*"
            local solved_mark=""
            is_challenge_solved "$c" && solved_mark=" ${C_GREEN}[RESOLU]${C_RESET}"
            echo -e "  $mark [$c] ${CH_NAMES[$c]}$solved_mark"
        done

        echo -e "\n${C_BOLD}[SECURITE WEB]${C_RESET}"
        for c in 10 11 12 13 14; do
            local mark=" "
            [ "$active_ch" = "$c" ] && mark="*"
            local solved_mark=""
            is_challenge_solved "$c" && solved_mark=" ${C_GREEN}[RESOLU]${C_RESET}"
            echo -e "  $mark [$c] ${CH_NAMES[$c]}$solved_mark"
        done

        echo -e "------------------------------------------------------------"
        echo -e "Actions :"
        echo -e "  [v] Valider un flag                [s] Arreter le challenge actif"
        echo -e "  [S] Tout arreter (avec LLM)        [m] Changer de modele (3B / 1.5B)"
        echo -e "  [d] Telecharger un modele          [t] Tester la reponse du LLM"
        echo -e "  [l] Consulter les logs             [q] Quitter"
        echo -e "------------------------------------------------------------"
        read -rp "Commande [01-14 ou action] : " opt

        case "$opt" in
            01|02|03|04|05|06|07|08|09|10|11|12|13|14|1|2|3|4|5|6|7|8|9)
                start_challenge "$opt"
                read -rp "Appuyez sur [Entree] pour continuer..."
                ;;
            v|valider|flag)
                validate_flag
                read -rp "Appuyez sur [Entree] pour continuer..."
                ;;
            s)
                stop_active_challenge
                sleep 1
                ;;
            S)
                stop_all
                sleep 1
                ;;
            m)
                switch_model
                read -rp "Appuyez sur [Entree] pour continuer..."
                ;;
            d)
                download_model
                read -rp "Appuyez sur [Entree] pour continuer..."
                ;;
            t)
                test_llm
                read -rp "Appuyez sur [Entree] pour continuer..."
                ;;
            l)
                show_logs
                ;;
            q|exit)
                exit 0
                ;;
            *)
                echo -e "${C_RED}[ERREUR] Option invalide.${C_RESET}"
                sleep 1
                ;;
        esac
    done
}

# Ligne de commande non-interactive
case "$1" in
    start)
        if [ -z "$2" ]; then
            echo -e "Usage: ./ctf.sh start <01-14>"
            exit 1
        fi
        start_challenge "$2"
        ;;
    stop)
        if [ "$2" = "all" ]; then
            stop_all
        else
            stop_active_challenge
        fi
        ;;
    download)
        download_model "$2"
        ;;
    model)
        switch_model
        ;;
    test)
        test_llm
        ;;
    logs)
        show_logs
        ;;
    flag|validate)
        validate_flag "$2" "$3"
        ;;
    score|progress)
        show_score
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo -e "Usage: ./ctf.sh [start <01-14> | stop [all] | flag [<ch>] [<flag>] | score | download [3b|1.5b] | model | test | logs]"
        exit 1
        ;;
esac
