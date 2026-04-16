# TIC-80 Tower Defense (Fennel Edition)

Ce projet est un jeu de Tower Defense entièrement développé en **Fennel** pour la console virtuelle **TIC-80**. Défendez votre base contre des vagues d'ennemis en plaçant stratégiquement des tours sur la carte et en utilisant des bonus actifs.

## 🚀 Installation et Configuration

1. Téléchargez et installez [TIC-80](https://tic80.com/).
2. Placez les fichiers main.fnl et game.tic dans votre dossier local TIC-80.
3. Chargez le projet dans la console TIC-80 :
```fennel
load game.tic
```
4. Importez le code source Fennel :
```fennel
import code main.fnl
```

## 🛡️ Arsenal des Tours

Le jeu propose trois types de tours avec des mécaniques d'attaque distinctes :

* **Canon (Sprites 494/462/430/398) :** Tire des boulets de canon (Sprite 278) qui transpercent les ennemis. Vous pouvez changer leur direction (Haut, Bas, Gauche, Droite) manuellement via le menu de gestion.
* **Tesla (Sprites 366/334/302/270) :** Inflige des dégâts constants à toutes les cibles dans son périmètre (Multi-target). Une zone circulaire blanche s'affiche pour montrer sa portée.
* **Écraseur (Sprites 448/384) :** Une tour lourde à 2 niveaux. Elle possède une animation procédurale de rotation sur 9 phases avec une élévation verticale de 1px toutes les deux frames. Elle s'écrase au sol pour infliger d'énormes dégâts de zone (cercle orange).

## 👾 Ennemis et Vagues

* **Bestiaire :** Slimes (Vert/Orange), Zombies, Crabes (16x8).
* **Boss :** Ogres Verts (toutes les 5 vagues) et Ogres Rouges (toutes les 20 vagues).
* **Mécanique de Boss :** Les ogres infligent 5 points de dégâts à la base s'ils passent, mais soignent la base de 2 PV s'ils sont tués.
* **Scaling :** La difficulté augmente tous les 5 paliers (augmentation des PV et de la vitesse des ennemis). Une nouvelle vague ne commence que lorsque la précédente est totalement éliminée.

## ✨ Bonus et Feedback Visuel

* **Dégâts x2 (Buff) :** Pour 100 pièces d'or, cliquez sur la flèche verte (Sprite 276) en haut à droite pour doubler vos dégâts pendant 30 secondes.
* **Feedback de Dégâts :** La tour principale clignote avec un sprite noir géant (32x32, Sprite 298) lorsqu'elle subit des dégâts.
* **Zones de construction :** Les emplacements libres sont marqués par des textures spécifiques (Sprite 258) qui disparaissent une fois la tour posée.

## 🎮 Contrôles

* **Souris :**
    * Clic sur un emplacement vide (Sprite 258) : Ouvre le shop d'achat.
    * Clic sur une tour existante : Ouvre le menu de gestion (Améliorer / Tourner / Vendre).
    * Clic sur l'icône de flèche verte : Active le Buff temporaire.
* **Clavier (Menus) :**
    * **Flèches :** Navigation dans les menus.
    * **Touche Z :** Confirmer l'achat ou l'action.

## 📝 Crédits

Développé par Victor, Thomas, Samy et Logan.
Moteur : TIC-80.
Langage : Fennel (Lisp-syntax Lua).