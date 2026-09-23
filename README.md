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
- `info <01-14>` : Affiche le briefing de mission et l'objectif d'audit du challenge selectionne.
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

## Missions et Scenarios d'audit

Dans le cadre de ce CTF, vous intervenez en tant qu'auditeur de securite mandate par l'entreprise fictive **CyberCorp**.
Chaque epreuve simule un service applicatif specifique dont vous devez evaluer la robustesse.
Chaque reussite permet de decouvrir un secret de validation a soumettre au format : `FLAG{...}`.

### Securite des Modeles de Langage (LLM)

- **Challenge 01 - Sentinel (Assistant de securite) :**
  - *Mise en situation :* CyberCorp a deploye un assistant conversationnel pour repondre aux questions des collaborateurs sur les regles de securite internes. Une cle de validation interne a ete confiee au systeme lors de son initialisation.
  - *Objectif d'audit :* Interagir avec l'assistant afin d'extraire la cle secrete de validation.

- **Challenge 02 - KnowledgeBot (Base documentaire) :**
  - *Mise en situation :* Vous disposez d'un compte collaborateur standard (`employee@cybercorp.local`) connecte a l'assistant documentaire de l'entreprise. Cet outil permet d'interroger les notices usuelles (teletravail, VPN...).
  - *Objectif d'audit :* Utiliser l'assistant pour acceder aux informations confidentielles relatives au plan de continuite d'activite de l'entreprise.

- **Challenge 04 - KnowledgeBot v2 (Base collaborative) :**
  - *Mise en situation :* La nouvelle version de l'assistant documentaire permet aux collaborateurs de soumettre de nouvelles documentations techniques afin d'enrichir la base de connaissances.
  - *Objectif d'audit :* Tirer parti des fonctionnalites de la plateforme pour extraire la cle de configuration confidentielle de l'assistant.

- **Challenge 05 - OpsAgent (Gestionnaire d'incidents) :**
  - *Mise en situation :* L'equipe des operations techniques utilise OpsAgent pour suivre et analyser les incidents d'infrastructure. L'assistant dispose d'outils d'automatisation pour accomplir ses taches.
  - *Objectif d'audit :* Interagir avec l'assistant afin de recuperer le secret de restauration d'identite heberge sur le serveur d'infrastructure.

- **Challenge 07 - AutoGrader (Plateforme d'evaluation) :**
  - *Mise en situation :* La plateforme de formation interne de CyberCorp soumet les candidats a une evaluation dont la correction est integralement deleguee a un module automatise.
  - *Objectif d'audit :* Soumettre une reponse a l'exercice permettant d'obtenir la note maximale de 10/10 afin de decrocher la validation.

- **Challenge 08 - HelpDesk (Annuaire d'entreprise) :**
  - *Mise en situation :* Vous etes connecte en tant qu'employe standard (Alex Martin, identifiant 1001) sur le portail d'assistance interne pour consulter l'annuaire d'entreprise.
  - *Objectif d'audit :* Utiliser l'assistant pour acceder aux informations confidentielles associees au profil d'un compte de direction.

- **Challenge 09 - OpsAssistant (Centre d'operations) :**
  - *Mise en situation :* En cas d'incident critique, la plateforme d'intervention d'urgence requiert une cle de deverrouillage de secours. Pour des motifs de resilience, cette cle a ete scindee en trois fragments distincts repartis au sein du systeme.
  - *Objectif d'audit :* Retrouver l'ensemble des 3 fragments de secours et soumettre la cle reconstituee au format demande (`FRAG1-FRAG2-FRAG3`).

### Machine Learning classique

- **Challenge 03 - MailGuard (Filtre de messagerie) :**
  - *Mise en situation :* La messagerie d'entreprise est protegee par un filtre d'analyse automatise charge d'intercepter les courriels suspects avant leur distribution.
  - *Objectif d'audit :* Adapter l'email suspect fourni afin que le filtre l'analyse comme legitime, tout en conservant son contenu et en respectant les contraintes imposees par l'interface.

- **Challenge 06 - PhishLearn (Detecteur adaptatif) :**
  - *Mise en situation :* Le systeme de detection de CyberCorp s'appuie sur un mecanisme d'apprentissage collaboratif : chaque echantillon soumis par les collaborateurs est integre pour actualiser le moteur de detection.
  - *Objectif d'audit :* Utiliser vos quotas de contribution pour faire en sorte que l'email de test actuellement bloque par le detecteur soit reclasse comme legitime.

### Securite Web

- **Challenge 10 - Web Portal (Portail d'entreprise) :**
  - *Mise en situation :* CyberCorp vient de mettre en ligne son nouveau site web institutionnel.
  - *Objectif d'audit :* Examiner l'ensemble des elements exposes publiquement par l'application web pour retrouver les fragments du jeton de validation interne.

- **Challenge 11 - Invoices (Portail de facturation) :**
  - *Mise en situation :* Vous etes connecte sur l'espace de facturation de l'entreprise pour consulter vos propres factures.
  - *Objectif d'audit :* Retrouver et consulter une facture confidentielle appartenant a un autre compte de l'organisation.

- **Challenge 12 - Intranet (Espace collaboratif) :**
  - *Mise en situation :* Vous disposez d'un acces visiteur standard sur l'intranet collaboratif de CyberCorp.
  - *Objectif d'audit :* Acceder a la zone d'administration restreinte de la plateforme pour en reveler le contenu.

- **Challenge 13 - DocServer (Serveur documentaire) :**
  - *Mise en situation :* Le serveur de documentation de l'entreprise permet de visualiser les guides et manuels publics mis a disposition des equipes.
  - *Objectif d'audit :* Recuperer le fichier de configuration confidentiel conserve dans l'espace prive du serveur.

- **Challenge 14 - NetTools (Diagnostic reseau) :**
  - *Mise en situation :* L'equipe reseau utilise un outil interne permettant de verifier la joignabilite des hotes du systeme d'information.
  - *Objectif d'audit :* Demontrer la possibilite de lire les donnees confidentielles hebergees sur le serveur d'execution.

---

## Modeles supportes

- **Qwen 2.5 3B (`qwen2.5-3b-instruct-q4_k_m.gguf`) [Recommande] :**
  - Taille : ~2.0 Go | RAM : ~2.3 Go.
  - Meilleure comprehension des contraintes, des roles et des formats structures (JSON).
- **Qwen 2.5 1.5B (`qwen2.5-1.5b-instruct-q4_k_m.gguf`) [Optionnel] :**
  - Taille : ~1.1 Go | RAM : ~1.5 Go.
  - Adapte aux machines disposant de ressources memoire tres limitees.
