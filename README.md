# Romifleur

![Romifleur Logo](logo-romifleur.png)

---

## 🇺🇸 English

### What is Romifleur?
**Romifleur** is a modern, user-friendly desktop application designed to simplify the process of finding and downloading retro game ROMs. Built with Python and CustomTkinter, it provides a sleek interface to browse extensive catalogs for various classic consoles, offering a streamlined alternative to navigating complex archive websites manually.

### Features
*   **Modern GUI**: A clean, dark-themed interface powered by CustomTkinter.
*   **Multi-Console Support**: Access libraries for NES, SNES, N64, GameCube, PS1, PSP, Sega Genesis, Dreamcast, and more.
*   **Smart Search & Filtering**:
    *   Real-time search bar.
    *   **Region Filters**: Easily toggle between Europe, USA, and Japan versions.
    *   **Clean List**: Option to hide Demos, Betas, and Prototypes automatically.
*   **Download Queue**: Add multiple games from different consoles to a persistent queue.
*   **Batch Downloading**: Download your entire queue in parallel with a single click.
*   **Deduplication**: Automatically identifies and prioritizes the best version of a game (e.g., latest revision, preferred region).

### How to Use
1.  **Launch the App**: Open `Romifleur.exe` (or run `main.py`).
2.  **Select a Console**: Choose a platform from the left sidebar.
3.  **Find Games**: Use the search bar or scroll through the list.
4.  **Select Games**: Click the checkbox `[ ]` next to games or use the "Select All" button.
5.  **Queue**: Click **"Add to Queue ➡️"** to send them to the download panel on the right.
6.  **Download**: Click **"Start Downloads 🚀"** in the right panel to begin.
7.  **Play**: Click "Open ROMs Folder" to access your downloaded files, automatically organized by console.

### Development & Compilation
**Requirements:**
*   Python 3.9+
*   `pip install customtkinter requests beautifulsoup4 pillow pyinstaller py7zr`

**Running from Source:**
```bash
python main.py
```

**Compiling to Executable (.exe):**
To build a standalone executable that includes all assets (icons, database):
```bash
pyinstaller --noconsole --onefile --icon=icon.ico --name Romifleur --add-data "consoles.json;." --add-data "logo-romifleur.png;." --add-data "logo-romifleur-mini.png;." --collect-all customtkinter main.py
```
The output file will be located in the `dist/` folder.

---

## 🇫🇷 Français

### Qu'est-ce que Romifleur ?
**Romifleur** est une application de bureau moderne conçue pour simplifier la recherche et le téléchargement de ROMs de jeux rétro. Développée en Python avec CustomTkinter, elle offre une interface élégante pour naviguer dans les catalogues de nombreuses consoles classiques, remplaçant la navigation fastidieuse sur les sites d'archives.

### Fonctionnalités
*   **Interface Moderne** : Un design sombre et épuré propulsé par CustomTkinter.
*   **Multi-Consoles** : Accès aux bibliothèques NES, SNES, N64, GameCube, PS1, PSP, Megadrive, Dreamcast, et bien plus.
*   **Recherche et Filtres Intelligents** :
    *   Recherche en temps réel.
    *   **Filtres de Région** : Basculez facilement entre les versions Europe, USA et Japon.
    *   **Liste Propre** : Option pour masquer automatiquement les Démos, Bêtas et Prototypes.
*   **File d'Attente** : Ajoutez plusieurs jeux provenant de consoles différentes dans une liste d'attente globale.
*   **Téléchargement par Lot** : Lancez le téléchargement de toute votre file d'attente en parallèle.
*   **Dédoublonnage** : Identifie et priorise automatiquement la meilleure version d'un jeu (ex: dernière révision, région préférée).

### Utilisation
1.  **Lancer l'App** : Ouvrez `Romifleur.exe` (ou lancez `main.py`).
2.  **Choisir une Console** : Sélectionnez une plateforme dans le menu de gauche.
3.  **Trouver des Jeux** : Utilisez la barre de recherche ou parcourez la liste.
4.  **Sélectionner** : Cochez la case `[ ]` à côté des jeux ou utilisez le bouton "Select All".
5.  **Ajouter à la File** : Cliquez sur **"Add to Queue ➡️"** pour les envoyer dans le panneau de droite.
6.  **Télécharger** : Cliquez sur **"Start Downloads 🚀"** dans le panneau de droite pour lancer les téléchargements.
7.  **Jouer** : Cliquez sur "Open ROMs Folder" pour accéder à vos fichiers, automatiquement triés par console.

### Développement et Compilation
**Prérequis :**
*   Python 3.9+
*   `pip install customtkinter requests beautifulsoup4 pillow pyinstaller py7zr`

**Lancer depuis le code source :**
```bash
python main.py
```

**Compiler en Exécutable (.exe) :**
Pour créer un exécutable autonome incluant toutes les ressources (icônes, base de données) :
```bash
pyinstaller --noconsole --onefile --icon=icon.ico --name Romifleur --add-data "consoles.json;." --add-data "logo-romifleur.png;." --add-data "logo-romifleur-mini.png;." --collect-all customtkinter main.py
```
Le fichier final se trouvera dans le dossier `dist/`.
