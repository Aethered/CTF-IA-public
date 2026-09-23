# CTF-IA : Challenges Cybersecurite et Intelligence Artificielle

Ce depot propose 14 challenges de type CTF concus pour des etudiants en cybersecurite, couvrant la securite des modeles de langage (LLM), le Machine Learning classique et les bases de la securite web.

---

## Demarrage rapide

### Sous Linux / macOS

Le script `./ctf.sh` permet de gerer le telechargement du modele, le serveur LLM partage et le basculement d'un challenge a l'autre sans conflit de port.

```bash
# 1. Rendre le script executable
chmod +x ctf.sh

# 2. Lancer le gestionnaire
./ctf.sh
```

### Sous Windows

Le projet fournit un lanceur natif `ctf.bat` (qui invoque PowerShell sans bloquer sur les politiques d'execution) :
- **Via l'explorateur :** Double-cliquez directement sur `ctf.bat` a la racine du dossier.
- **Via le terminal (Invite de commandes ou PowerShell) :**
  ```cmd
  .\ctf.bat
  ```

Le script controle automatiquement la presence de Docker Desktop et guide son installation si necessaire.

### Commandes directes

Les memes sous-commandes sont disponibles sous Linux (`./ctf.sh <commande>`) et sous Windows (`.\ctf.bat <commande>`) :

- `start <01-14>` : Coupe le challenge precedent, demarre le LLM si necessaire, et lance le challenge selectionne sur `http://localhost:8000`.
- `flag [<01-14>] [<flag>]` : Valide un flag trouve (directement pour le challenge actif ou en precisant le numero) et enregistre la progression.
- `score` : Affiche l'etat d'avancement et la liste des challenges resolus.
- `stop` : Arrete le challenge actif.
- `stop all` : Arrete l'ensemble des conteneurs (challenge et LLM).
- `model` : Configure le modele actif (Qwen 2.5 3B ou 1.5B).
- `download 3b` : Telecharge le modele 3B dans le repertoire `models/`.
- `test` : Envoie une requete de test au serveur LLM.
- `logs` : Affiche les journaux du challenge actif ou du LLM.

---

## Architecture technique

1. **Serveur LLM mutualise :**
   - Une unique instance `llama.cpp` s'execute en arriere-plan sur le port 8080.
   - Les applications FastAPI s'y connectent via le reseau Docker interne (`http://llm:8080/v1/chat/completions`).
   - Le modele reste charge en memoire, rendant la transition d'un challenge a l'autre immediate.
2. **Repertoire de modeles centralise :**
   - Les fichiers de poids GGUF sont stockes dans `models/`.
3. **Gestion des ports :**
   - Seul le challenge selectionne ecoute sur le port 8000. Le script arrete automatiquement le conteneur precedent avant de lancer le nouveau.

---

## Liste des challenges

### Securite LLM (OWASP LLM Top 10)
- **Challenge 01 - Sentinel :** Direct Prompt Injection et contournement de filtre applicatif.
- **Challenge 02 - KnowledgeBot :** RAG Access Control Bypass (fuite documentaire via absence de controle d'acces sur le retriever).
- **Challenge 04 - KnowledgeBot v2 :** Indirect Prompt Injection via empoisonnement documentaire.
- **Challenge 05 - OpsAgent :** Insecure Tool Execution et elevation de privileges.
- **Challenge 07 - AutoGrader :** LLM-as-a-judge Jailbreak (manipulation d'un evaluateur automatique).
- **Challenge 08 - HelpDesk :** BOLA / IDOR applique aux outils d'un agent.
- **Challenge 09 - OpsAssistant :** Chaine d'attaque combinant RAG, IDOR et injection indirecte.

### Machine Learning classique (Adversarial ML)
- **Challenge 03 - MailGuard :** ML Evasion (perturbation adverse sur modele de classification sans LLM).
- **Challenge 06 - PhishLearn :** Data Poisoning (empoisonnement du jeu d'entrainement).

### Securite Web
- **Challenge 10 - Web Basics :** Reconnaissance (code source, en-tetes, cookies, robots.txt).
- **Challenge 11 - Invoices :** IDOR (Broken Object Level Authorization).
- **Challenge 12 - Tampering :** Manipulation de donnees et de roles cote client.
- **Challenge 13 - DocServer :** Path Traversal / LFI.
- **Challenge 14 - PingDiag :** Injection de commande systeme (RCE).

---

## Modeles supportes

- **Qwen 2.5 3B (`qwen2.5-3b-instruct-q4_k_m.gguf`) [Recommande] :**
  - Taille : ~2.0 Go | RAM : ~2.3 Go.
  - Meilleure comprehension des contraintes, des roles et des formats structures (JSON).
- **Qwen 2.5 1.5B (`qwen2.5-1.5b-instruct-q4_k_m.gguf`) [Optionnel] :**
  - Taille : ~1.1 Go | RAM : ~1.5 Go.
  - Adapte aux machines disposant de ressources memoire tres limitees.
