# Commandes Utiles pour Romifleur

Ce fichier regroupe les commandes essentielles pour le développement, l'installation et la compilation de **Romifleur**.

## 1. Installation des Dépendances

Pour installer toutes les librairies nécessaires au projet :

```powershell
pip install customtkinter requests beautifulsoup4 pillow pyinstaller py7zr
```

## 2. Lancer l'Application (Mode Développement)

Pour tester l'application sans la compiler :

```powershell
python main.py
```

## 3. Générer l'Icône (.ico)

Si vous avez besoin de régénérer le fichier `icon.ico` à partir du logo PNG :

```powershell
python -c "from PIL import Image; img = Image.open('logo-romifleur-mini.png'); img.save('icon.ico', format='ICO', sizes=[(256, 256)])"
```

## 4. Créer l'Exécutable (.exe)

Pour générer un fichier **Romifleur.exe** autonome (incluant toutes les dépendances et les assets) :

```powershell
pyinstaller --noconsole --onefile --icon=icon.ico --name Romifleur --add-data "consoles.json;." --add-data "logo-romifleur.png;." --add-data "logo-romifleur-mini.png;." --collect-all customtkinter main.py
```

*   Une fois terminé, l'exécutable se trouvera dans le dossier `dist/`.
*   Le fichier `Romifleur.spec` peut être supprimé si vous relancez toujours cette commande complète.

## 5. Nettoyage

Si vous rencontrez des erreurs de build, supprimez les dossiers générés avant de recommencer :

```powershell
Remove-Item -Recurse -Force build, dist
Remove-Item -Recurse -Force __pycache__
Remove-Item Romifleur.spec
```

Pour faire une release, il faut:

❯ git tag v1.0.7
❯ git push origin main --tags