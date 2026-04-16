;; title:   Tower Defense
;; author:  Logan
;; desc:    Tower Defense game
;; site:    
;; license: MIT License
;; version: 0.1
;; script:  fennel
;; strict:  true

;; ============================================================
;; CONSTANTES GENERALES
;; ============================================================
;; Dimensions de l'ecran TIC-80 et taille d'une tile
(local SCREEN-W 240)
(local SCREEN-H 136)
(local TILE-SIZE 16)

;; ============================================================
;; TYPES DE TOURS
;; ============================================================
;; Chaque type de tour a un cout d'achat, une puissance de degats,
;; une portee de detection, un cooldown entre chaque tir,
;; un sprite pour l'affichage et un nom affiche dans le shop.
(local TOUR-TYPES
  {:ecraseur {:cout 50  :puissance 25 :range 20 :cooldown 300 :sprite 448 :nom "Ecraseur" :max-niveau 2}
   :tesla    {:cout 80  :puissance 2  :range 30 :cooldown 60  :sprite 366 :nom "Tesla"    :max-niveau 4}
   :canon    {:cout 120 :puissance 15 :range 60 :cooldown 90  :sprite 430 :nom "Canon"    :max-niveau 4}})

(local UPGRADE-COUTS [55 85 155])

(local SPRITES-TOURS
  {:canon [494 462 430 398]
   :tesla [366 334 302 270]
   :ecraseur [448 384 384 384]}) ; On met 384 pour la suite au cas où
(local SPRITES-ECRASEUR
  {1 {:anim [448 450 452 454 456 480 482 484 486] :barre 488}
   2 {:anim [384 386 388 390 392 416 418 420 422] :barre 424}})
(local MAX-NIVEAU 4)

;; ============================================================
;; CHEMINS DES ENNEMIS
;; ============================================================
;; Les ennemis suivent un chemin compose de waypoints (coordonnees en pixels).
;; Deux chemins existent, l'ennemi en choisit un au hasard au spawn.
;; path1 et path2 different au niveau du segment central (y=78 vs y=45).
(local path1 [{:x 5 :y 15}
             {:x 233 :y 15}
             {:x 233 :y 62}
             {:x 190 :y 62}
             {:x 185 :y 78}
             {:x 107 :y 78}
             {:x 99 :y 64}
             {:x 58 :y 62}
             {:x 55 :y 31}
             {:x 9 :y 32}
             {:x 10 :y 80}
             {:x 39 :y 80}
             {:x 39 :y 95}
             {:x 9 :y 96}
             {:x 8 :y 110}
             {:x 117 :y 112}
             {:x 119 :y 96}
             {:x 173 :y 96}
             {:x 176 :y 111}
             {:x 236 :y 111}])

(local path2 [{:x 5 :y 15}
             {:x 233 :y 15}
             {:x 233 :y 62}
             {:x 190 :y 62}
             {:x 185 :y 45}
             {:x 107 :y 45}
             {:x 99 :y 64}
             {:x 58 :y 62}
             {:x 55 :y 31}
             {:x 9 :y 32}
             {:x 10 :y 80}
             {:x 39 :y 80}
             {:x 39 :y 95}
             {:x 9 :y 96}
             {:x 8 :y 110}
             {:x 117 :y 112}
             {:x 119 :y 96}
             {:x 173 :y 96}
             {:x 176 :y 111}
             {:x 236 :y 111}])

;; ============================================================
;; ETAT DU JEU (variables mutables)
;; ============================================================
;; state : l'etat courant du jeu (menu, playing, gameover, victory)
;; tick : compteur de frames depuis le debut de la partie
;; gold : monnaie du joueur pour acheter et ameliorer des tours
;; lives : points de vie du joueur, decremente quand un ennemi arrive au bout
;; wave : numero de la vague actuelle
;; enemies : liste de tous les ennemis vivants sur le terrain
;; liste-tours : liste de toutes les tours posees sur le terrain
;; nb_click : anti-rebond pour le clic souris (1 = pret, 0 = en attente de relachement)
;; emplacements-tours : positions disponibles ou le joueur peut poser une tour
;; message-flash : texte temporaire affiche a l'ecran (ex: "Pas assez d'or !")
;; message-timer : nombre de frames restantes pour afficher le message flash
(var state :menu)
(var tick 0)
(var gold 250)
(var lives 10)
(var wave 0)
(var enemies [])
(var liste-tours [])
(var nb_click 1)
(var emplacements-tours [])
(var message-flash nil)
(var message-timer 0)
(var projectiles [])  
(var mobs-to-spawn 0)
(var spawn-timer 0)
(var boss-to-spawn nil)
(var buff-timer 0)
(var base-flash-timer 0)

;; Dictionnaire de tous les ennemis possibles
(local ENNEMIS-TYPES
  {:slime-vert   {:nom "Slime V" :vitesse 0.5  :pv 7  :anim [320 321]     :w 1 :h 1 :degats 1 :heal 0}
   :slime-orange {:nom "Slime O" :vitesse 0.55 :pv 12  :anim [336 337]     :w 1 :h 1 :degats 1 :heal 0}
   :zombie       {:nom "Zombie"  :vitesse 0.4  :pv 18  :anim [324 340 325] :w 1 :h 1 :degats 1 :heal 0}
   :crabe        {:nom "Crabe"   :vitesse 0.45 :pv 25  :anim [322 338]     :w 2 :h 1 :degats 1 :heal 0}
   :ogre-vert    {:nom "Ogre V"  :vitesse 0.3  :pv 300 :anim [352 354 356] :w 2 :h 2 :degats 5 :heal 2}
   :ogre-rouge   {:nom "Ogre R"  :vitesse 0.35 :pv 500 :anim [358 360 362] :w 2 :h 2 :degats 5 :heal 2}}) 

;; ============================================================
;; ETAT DU SHOP (systeme de pause avec menu d'achat/gestion)
;; ============================================================
;; shop-mode : nil = pas de shop ouvert, :achat = menu de choix de tour,
;;             :gestion = menu upgrade/vente d'une tour existante
;; shop-emplacement : reference vers l'emplacement vide clique
;; shop-emplacement-idx : index de cet emplacement dans la liste
;; shop-tour : reference vers la tour cliquee pour gestion
;; shop-tour-idx : index de cette tour dans liste-tours
;; shop-cursor : position du curseur de selection dans le menu (0, 1, 2...)
(var shop-mode nil)
(var shop-emplacement nil)
(var shop-emplacement-idx nil)
(var shop-tour nil)
(var shop-tour-idx nil)
(var shop-cursor 0)

;; ============================================================
;; REINITIALISATION DES EMPLACEMENTS
;; ============================================================
;; Remet tous les emplacements de construction a leur etat initial.
;; Appele dans init-game pour que chaque nouvelle partie commence
;; avec tous les emplacements disponibles.
(fn reset-emplacements []
  (set emplacements-tours
     [{:x 25  :y 45}
      {:x 73  :y 33}
      {:x 200 :y 32}
      {:x 120 :y 56}
      {:x 152 :y 56}
      {:x 53  :y 82}
      {:x 77  :y 82}
      {:x 140 :y 110}
      {:x 222 :y 71}
      {:x 190 :y 88}
      {:x 119 :y 24}
      {:x 156 :y 24}]))

;; ============================================================
;; CLASSE ENNEMI
;; ============================================================
;; Cree une table representant un ennemi avec ses proprietes et methodes.
;; Chaque ennemi a une position (x,y), des points de vie, une vitesse,
;; un sprite, et un chemin a suivre. Il avance de waypoint en waypoint
;; et retire une vie au joueur s'il atteint la fin du chemin.
;;
;; Parametres :
;;   nom-p    : identifiant de l'ennemi (pour debug)
;;   x-p, y-p : position initiale en pixels
;;   vitesse-p: nombre de pixels parcourus par frame
;;   pv-p     : points de vie initiaux
;;   sprite-p : ID du sprite dans l'editeur TIC-80
;;   path-p   : reference vers le chemin (path1 ou path2)
(fn creer-ennemi [nom-p x-p y-p vitesse-p pv-p anim-p path-p w-p h-p degats-p heal-p]
  {:nom nom-p
   :x x-p :y y-p :vitesse vitesse-p :index-chemin 1
   :pv pv-p :max-pv pv-p :anim anim-p :alive true :path path-p
   :w (or w-p 1) :h (or h-p 1)
   :degats (or degats-p 1) 
   :heal (or heal-p 0)
   :direction 0 :etat 1 :timer-anim 0

   :deplacer (fn [self cible-x cible-y]
               (let [dx (- cible-x self.x) dy (- cible-y self.y)
                     dist (math.sqrt (+ (* dx dx) (* dy dy)))]
                 (when (> dist 0)
                   (if (> (math.abs dx) (math.abs dy))
                       (if (> dx 0) (set self.direction 0) (set self.direction 2))
                       (if (> dy 0) (set self.direction 1) (set self.direction 3)))
                       
                   (let [vx (/ dx dist) vy (/ dy dist)
                         move (math.min self.vitesse dist)]
                     (set self.x (+ self.x (* vx move)))
                     (set self.y (+ self.y (* vy move)))))))

   :prendre-degats (fn [self montant]
                     (let [degats-finaux (if (> buff-timer 0) (* montant 2) montant)]
                       (set self.pv (- self.pv degats-finaux))
                       (when (<= self.pv 0)
                         (set self.alive false)
                         (when (> self.heal 0) 
                           (set lives (+ lives self.heal))))))

   :suivre-chemin (fn [self]
                    (let [cible (. self.path self.index-chemin)]
                      (when cible
                        (: self :deplacer cible.x cible.y)
                        (when (and (= (math.floor self.x) cible.x)
                                   (= (math.floor self.y) cible.y))
                          (if (= self.index-chemin (length self.path))
                              (: self :arrivee)
                              (set self.index-chemin (+ self.index-chemin 1)))))))

   :arrivee (fn [self]
              (set self.alive false)
              (set lives (- lives self.degats))
              (set base-flash-timer 30))

   :afficher (fn [self]
               (set self.timer-anim (+ (or self.timer-anim 0) 1))
               (when (>= self.timer-anim 12) 
                 (set self.timer-anim 0)
                 (set self.etat (+ self.etat 1))
                 (when (> self.etat (length self.anim))
                   (set self.etat 1)))

               (let [x (math.floor self.x)
                     y (math.floor self.y)
                     sprite-actuel (. self.anim self.etat)
                     
                     est-petit? (and (= self.w 1) (= self.h 1))
                     flip (if (= self.direction 2) 1 0)
                     
                     rot (if est-petit?
                             (match self.direction 0 0 1 1 2 0 3 3)
                             0)
                             
                     offset-x (* self.w 4)
                     offset-y (* self.h 4)]

                 (spr sprite-actuel (- x offset-x) (- y offset-y) 0 1 flip rot self.w self.h)

                 (let [bar-w (* self.w 8)
                       filled (math.ceil (* (/ self.pv self.max-pv) bar-w))]
                   (rect (- x offset-x) (- y (+ offset-y 3)) bar-w 2 2)
                   (rect (- x offset-x) (- y (+ offset-y 3)) filled 2 7))))})
;; ============================================================
;; GESTION DES ENNEMIS
;; ============================================================
;; Cree un nouvel ennemi au debut d'un chemin choisi au hasard
;; et l'ajoute a la liste des ennemis actifs.
(fn spawn-enemy-type [type-key]
  (let [template (. ENNEMIS-TYPES type-key)
        chosen-path (if (< (math.random) 0.5) path1 path2)
        start (. chosen-path 1)
        
        palier (math.floor (/ wave 5))
        multi-pv (+ 1 (* palier 0.4))  
        multi-vit (+ 1 (* palier 0.1)) 
        
        pv-final (* template.pv multi-pv)
        vit-final (* template.vitesse multi-vit)]
        
    (table.insert enemies
      (creer-ennemi template.nom start.x start.y vit-final pv-final template.anim chosen-path template.w template.h template.degats template.heal))))

(fn demarrer-vague []
  (set wave (+ wave 1))
  (set mobs-to-spawn (+ 5 (* wave 2))) 
  (set spawn-timer 60)
  
  (if (= (% wave 20) 0)
      (set boss-to-spawn :ogre-rouge)
      (= (% wave 5) 0)
      (set boss-to-spawn :ogre-vert)
      (set boss-to-spawn nil)))

(fn gerer-vagues []
  (when (and (= (length enemies) 0) (= mobs-to-spawn 0) (not boss-to-spawn))
    (demarrer-vague))
    
  (when (> spawn-timer 0)
    (set spawn-timer (- spawn-timer 1)))
    
  (when (= spawn-timer 0)
    (if (> mobs-to-spawn 0)
        (do
          (let [types [:slime-vert :slime-orange :zombie :crabe]
                choix (. types (math.random 1 4))]
            (spawn-enemy-type choix))
          (set mobs-to-spawn (- mobs-to-spawn 1))
          (set spawn-timer (math.max 20 (- 50 wave))))
          
        boss-to-spawn
        (do
          (spawn-enemy-type boss-to-spawn)
          (set boss-to-spawn nil)
          (set spawn-timer 120))))) 

(fn update-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :suivre-chemin)))
  (for [i (length enemies) 1 -1]
    (let [enemy (. enemies i)]
      (when (not enemy.alive)
        (when (<= enemy.pv 0)
          (set gold (+ gold 6))) 
        (table.remove enemies i)))))

(fn draw-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :afficher))))

;; --- GESTION DES PROJECTILES ---

(fn creer-projectile [x y dx dy dmg]
  {:x x :y y :dx dx :dy dy :dmg dmg 
   :sprite 278 
   :hits {}
   :alive true})

(fn update-projectiles []
  (for [i (length projectiles) 1 -1]
    (let [p (. projectiles i)]
      (set p.x (+ p.x p.dx))
      (set p.y (+ p.y p.dy))
      
      (each [_ enemy (ipairs enemies)]
        (when (and enemy.alive 
                   (< (math.abs (- p.x enemy.x)) 8) 
                   (< (math.abs (- p.y enemy.y)) 8))
          (when (not (. p.hits enemy))
            (: enemy :prendre-degats p.dmg)
            (tset p.hits enemy true))))

      (when (or (< p.x -10) (> p.x 250) (< p.y -10) (> p.y 150))
        (set p.alive false))
      
      (if (not p.alive) (table.remove projectiles i)))))

(fn draw-projectiles []
  (each [_ p (ipairs projectiles)]
    (spr p.sprite p.x p.y 0)))
;; ============================================================
;; CLASSE TOUR
;; ============================================================
;; Cree une tour a partir d'un type defini dans TOUR-TYPES.
;; La tour herite des stats du type (degats, portee, cooldown, sprite)
;; et peut etre amelioree jusqu'au niveau MAX-NIVEAU.
;;
;; Parametres :
;;   nom-p    : nom affiche (pour debug et shop)
;;   x-p, y-p : position du coin haut-gauche du sprite 16x16
;;   type-key : cle dans TOUR-TYPES (:ecraseur, :tesla, :canon)
(fn creer-tour [nom-p x-p y-p type-key]
  (let [template (. TOUR-TYPES type-key)]
    {:nom nom-p :x x-p :y y-p :type type-key :niveau 1
     :range template.range :puissance template.puissance
     :sprite template.sprite :cooldown template.cooldown
     :max-niveau template.max-niveau
     :timer_tir 0 :direction 0 :anim_cercle 0

     :dans-ligne-de-tir (fn [self enemy-x enemy-y]
       (let [cx (+ self.x 8) cy (+ self.y 8)
             dx (- enemy-x cx) dy (- enemy-y cy) largeur 16]
         (if
           (= self.direction 0) (and (> dx 0) (<= dx self.range) (>= dy (- 0 (/ largeur 2))) (<= dy (/ largeur 2)))
           (= self.direction 1) (and (> dy 0) (<= dy self.range) (>= dx (- 0 (/ largeur 2))) (<= dx (/ largeur 2)))
           (= self.direction 2) (and (< dx 0) (>= dx (- 0 self.range)) (>= dy (- 0 (/ largeur 2))) (<= dy (/ largeur 2)))
           (= self.direction 3) (and (< dy 0) (>= dy (- 0 self.range)) (>= dx (- 0 (/ largeur 2))) (<= dx (/ largeur 2)))
           false)))

     :tirs (fn [self]
             (set self.timer_tir (+ self.timer_tir 1))
             (when (>= self.timer_tir self.cooldown)
               (let [cx (+ self.x 8) cy (+ self.y 8)]
                 
                 (if (= self.type :canon)
                   (do
                     (var cible-en-vue? false)
                     (each [_ enemy (ipairs enemies) &until cible-en-vue?]
                       (when (and enemy.alive (: self :dans-ligne-de-tir enemy.x enemy.y))
                         (set cible-en-vue? true)))
                     (when cible-en-vue?
                       (set self.timer_tir 0)
                       (let [v 2
                             (dx dy) (match self.direction 0 (values v 0) 1 (values 0 v) 2 (values (- v) 0) 3 (values 0 (- v)))] 
                         (table.insert projectiles (creer-projectile (+ self.x 4) (+ self.y 4) dx dy self.puissance)))))
                   
                   ;; --- LOGIQUE ECRASEUR ET TESLA ---
                   (do
                     (var a-tire? false)
                     (each [_ enemy (ipairs enemies)]
                       (when (and enemy.alive (> enemy.pv 0))
                         (let [dx (- enemy.x cx) dy (- enemy.y cy)
                               dist-sq (+ (* dx dx) (* dy dy))
                               range-sq (* self.range self.range)]
                           (when (<= dist-sq range-sq)
                             (: enemy :prendre-degats self.puissance)
                             (set a-tire? true)))))
                     
                     (when a-tire?
                       (set self.timer_tir 0)
                       (when (= self.type :ecraseur)
                         (set self.anim_cercle 15))))))))

     :tourner (fn [self] (set self.direction (% (+ self.direction 1) 4)))

     :ameliorer (fn [self]
                  (set self.niveau (+ self.niveau 1))
                  (if (= self.type :ecraseur)
                    (do
                      (set self.range 30)
                      (set self.puissance (+ self.puissance 20))
                      (set self.cooldown 180))
                    (do
                      (set self.range (+ self.range 8))
                      (set self.puissance (+ self.puissance 3))
                      (set self.cooldown (math.max 10 (- self.cooldown 5))))))

     :valeur-vente (fn [self]
                     (let [template (. TOUR-TYPES self.type) base template.cout]
                       (var total base)
                       (for [i 1 (- self.niveau 1)]
                         (when (<= i (length UPGRADE-COUTS))
                           (set total (+ total (. UPGRADE-COUTS i)))))
                       (math.floor (* total 0.5))))

     :afficher (fn [self]
                 (let [cx (+ self.x 8) cy (+ self.y 8)]
                   
                   ;; --- ZONES D'EFFET ---
                   (when (= self.type :tesla)
                     (circb cx cy self.range 12))
                     
                   (when (and (= self.type :ecraseur) (> self.anim_cercle 0))
                     (set self.anim_cercle (- self.anim_cercle 1))
                     (circb cx cy self.range 9)
                     (circb cx cy (- self.range 1) 9))

                   ;; --- DESSIN DES SPRITES ---
                   (if (= self.type :ecraseur)
                       ;; LOGIQUE SPÉCIFIQUE ECRASEUR
                       (let [data (. SPRITES-ECRASEUR self.niveau)
                             progression (/ self.timer_tir self.cooldown)
                             frame-idx (math.max 1 (math.min 9 (math.floor (+ 1 (* progression 9)))))
                             sprite-id (. data.anim frame-idx)
                             y-offset (math.floor (/ (- frame-idx 1) 2))]
                         
                         (spr data.barre self.x self.y 0 1 0 0 2 2)
                         (spr sprite-id self.x (- self.y y-offset) 0 1 0 0 2 2))

                       (let [sprite-id (. (. SPRITES-TOURS self.type) self.niveau)
                             rot (if (= self.type :canon) (% (+ (or self.direction 0) 2) 4) 0)]
                         (spr sprite-id self.x self.y 0 1 0 rot 2 2)))

                 (print self.niveau (+ self.x 6) (- self.y 8) 15)))}))
;; ============================================================
;; GESTION DES TOURS
;; ============================================================
(fn spawn-tour [nom x y type-key]
  (table.insert liste-tours (creer-tour nom x y type-key)))

(fn update-tours []
  (each [_ t (ipairs liste-tours)]
    (: t :tirs)))

(fn draw-tours []
  (each [_ t (ipairs liste-tours)]
    (: t :afficher)))

(fn draw-emplacements []
  (each [_ empla (ipairs emplacements-tours)]
    (spr 258 empla.x empla.y 0 1 0 0 2 2)))

(fn find-tour-at [px py]
  (var found-tour nil)
  (var found-idx nil)
  (each [i tour (ipairs liste-tours)]
    (when (and (>= px tour.x) (<= px (+ tour.x 16))
               (>= py tour.y) (<= py (+ tour.y 16)))
      (set found-tour tour)
      (set found-idx i)))
  (values found-tour found-idx))

;; ============================================================
;; SHOP : ECRAN D'ACHAT DE TOUR
;; ============================================================
;; Affiche quand le joueur clique sur un emplacement vide.
;; Le jeu est en pause. Le joueur navigue avec haut/bas
;; et confirme avec Z. Il peut choisir parmi les 3 types
;; de tours ou annuler.

(fn draw-shop-achat []
  (cls 0)
  (print "CHOISIR UNE TOUR" 65 5 12 true)
  (print (.. "Gold: " gold) 5 5 14)

  (let [sel (= shop-cursor 0)
        col (if sel 6 13)
        t (. TOUR-TYPES :ecraseur)]
    (rectb 20 25 200 22 col)
    (when sel (rect 21 26 198 20 1))
    (print (.. "ECRASEUR  -  $" t.cout) 30 29 col)
    (print (.. "DMG:" t.puissance " RNG:" t.range " SPD:" t.cooldown) 30 38 15))

  (let [sel (= shop-cursor 1)
        col (if sel 9 13)
        t (. TOUR-TYPES :tesla)]
    (rectb 20 52 200 22 col)
    (when sel (rect 21 53 198 20 1))
    (print (.. "TESLA  -  $" t.cout) 30 56 col)
    (print (.. "DMG:" t.puissance " RNG:" t.range " SPD:" t.cooldown) 30 65 15))

  (let [sel (= shop-cursor 2)
        col (if sel 2 13)
        t (. TOUR-TYPES :canon)]
    (rectb 20 79 200 22 col)
    (when sel (rect 21 80 198 20 1))
    (print (.. "CANON  -  $" t.cout) 30 83 col)
    (print (.. "DMG:" t.puissance " RNG:" t.range " SPD:" t.cooldown) 30 92 15))

  (let [sel (= shop-cursor 3)
        col (if sel 8 13)]
    (rectb 20 106 200 14 col)
    (when sel (rect 21 107 198 12 1))
    (print "ANNULER" 30 109 col))

  (print "UP/DOWN: choisir  Z: confirmer" 30 125 13))

(fn update-shop-achat []
  (when (btnp 0) (set shop-cursor (math.max 0 (- shop-cursor 1))))
  (when (btnp 1) (set shop-cursor (math.min 3 (+ shop-cursor 1))))

  (when (btnp 4)
    (if (= shop-cursor 3)
        (set shop-mode nil)

        (let [type-key (if (= shop-cursor 0) :ecraseur
                           (= shop-cursor 1) :tesla
                           :canon)
              template (. TOUR-TYPES type-key)]
          (if (>= gold template.cout)
              (do
                (set gold (- gold template.cout))
                (spawn-tour template.nom shop-emplacement.x shop-emplacement.y type-key)
                (table.remove emplacements-tours shop-emplacement-idx)
                (set shop-mode nil))
              (do
                (set message-flash "Pas assez d'or !")
                (set message-timer 60)
                (set shop-mode nil)))))))

;; ============================================================
;; SHOP : ECRAN DE GESTION DE TOUR (upgrade / vente)
;; ============================================================
;; Affiche quand le joueur clique sur une tour existante.
;; Le jeu est en pause. Le joueur peut ameliorer la tour,
;; la vendre (recupere 50% de l'investissement total),
;; ou revenir au jeu.
(fn draw-shop-gestion []
  (cls 0)
  (let [tour shop-tour
        template (. TOUR-TYPES tour.type)
        is-canon (= tour.type :canon)
        dir-noms ["Haut" "Droite" "Bas" "Gauche"]]
    (print (.. "GESTION : " template.nom) 55 5 12 true)
    (print (.. "Gold: " gold) 5 5 14)

    (print (.. "Niveau: " tour.niveau "/" tour.max-niveau) 30 22 15)
    (print (.. "Degats: " tour.puissance) 30 32 15)
    (print (.. "Portee: " tour.range) 30 42 15)
    (print (.. "Vitesse: " tour.cooldown " (bas=rapide)") 30 52 15)
    (when is-canon
      (print (.. "Direction: " (. dir-noms (+ tour.direction 1))) 130 42 2))

    (let [sel (= shop-cursor 0)
          col (if sel 6 13)
          can-upgrade (< tour.niveau tour.max-niveau) 
          upgrade-cout (if can-upgrade (. UPGRADE-COUTS tour.niveau) 0)]
      (rectb 20 62 200 22 col)
      (when sel (rect 21 63 198 20 1))
      (if can-upgrade
          (do
            (print (.. "AMELIORER  -  $" upgrade-cout) 30 66 col)
            (if (= tour.type :ecraseur)
              (print (.. "-> DMG:" (+ tour.puissance 20) " RNG:30 SPD:180") 30 75 11)
              (print (.. "-> DMG:" (+ tour.puissance 3) " RNG:" (+ tour.range 8) " SPD:" (math.max 10 (- tour.cooldown 5))) 30 75 11)))
          (print "NIVEAU MAX ATTEINT" 30 69 8)))

    (let [sel (= shop-cursor 1) col (if sel 12 13)]
      (rectb 20 87 200 14 col)
      (when sel (rect 21 88 198 12 1))
      (if is-canon
          (let [next-dir (. dir-noms (+ (% (+ tour.direction 1) 4) 1))]
            (print (.. "TOURNER -> " next-dir) 30 90 col))
          (print "-- non disponible --" 30 90 7)))

    (let [sel (= shop-cursor 2) col (if sel 14 13) prix-vente (: tour :valeur-vente)]
      (rectb 20 104 200 14 col)
      (when sel (rect 21 105 198 12 1))
      (print (.. "VENDRE  +$" prix-vente) 30 107 col))

    (let [sel (= shop-cursor 3) col (if sel 8 13)]
      (rectb 20 121 200 14 col)
      (when sel (rect 21 122 198 12 1))
      (print "RETOUR" 30 124 col))

    (print "UP/DOWN: choisir  Z: confirmer" 30 130 13)))

(fn update-shop-gestion []
  (when (btnp 0) (set shop-cursor (math.max 0 (- shop-cursor 1))))
  (when (btnp 1) (set shop-cursor (math.min 3 (+ shop-cursor 1))))

  (when (btnp 4)
    (if
      (= shop-cursor 0)
      (let [tour shop-tour]
        (when (< tour.niveau tour.max-niveau)
          (let [cout (. UPGRADE-COUTS tour.niveau)]
            (if (>= gold cout)
                (do
                  (set gold (- gold cout))
                  (: tour :ameliorer))
                (do
                  (set message-flash "Pas assez d'or !")
                  (set message-timer 60)
                  (set shop-mode nil))))))

      (= shop-cursor 1)
      (when (= shop-tour.type :canon) (: shop-tour :tourner))

      (= shop-cursor 2)
      (let [tour shop-tour prix (: tour :valeur-vente)]
        (set gold (+ gold prix))
        (table.insert emplacements-tours {:x tour.x :y tour.y})
        (table.remove liste-tours shop-tour-idx)
        (set shop-mode nil))

      (= shop-cursor 3)
      (set shop-mode nil))))

;; ============================================================
;; INPUT : DETECTION DES CLICS SOURIS
;; ============================================================
;; Gere le clic souris pendant le jeu (hors shop).
;; Un systeme anti-rebond (nb_click) empeche de detecter
;; plusieurs clics quand le bouton reste enfonce.
;;
;; Priorite : on verifie d'abord si le clic est sur une tour
;; existante (ouvre le menu gestion), sinon sur un emplacement
;; vide (ouvre le menu d'achat).
(fn handle-click []
  (let [(mx my clic) (mouse)]
    (if (and clic (= nb_click 1))
        (do
          (set nb_click 0)

          (if (and (<= buff-timer 0) (>= mx 160) (<= mx 200) (>= my 0) (<= my 16))
              (if (>= gold 100)
                  (do
                    (set gold (- gold 100))
                    (set buff-timer 1800)) ; 30 secondes à 60 fps
                  (do
                    (set message-flash "Pas assez d'or !")
                    (set message-timer 60)))

              (let [(tour idx) (find-tour-at mx my)]
                (if tour
                    (do
                      (set shop-tour tour)
                      (set shop-tour-idx idx)
                      (set shop-cursor 0)
                      (set shop-mode :gestion))

                    (do
                      (var found false)
                      (each [i empla (ipairs emplacements-tours) &until found]
                        (when (and (>= mx empla.x) (<= mx (+ empla.x 16))
                                   (>= my empla.y) (<= my (+ empla.y 16)))
                          (set found true)
                          (set shop-emplacement empla)
                          (set shop-emplacement-idx i)
                          (set shop-cursor 0)
                          (set shop-mode :achat))))))))

        (when (not clic)
          (set nb_click 1)))))

;; ============================================================
;; ECRANS PRINCIPAUX (menu, game over, victoire)
;; ============================================================

(fn draw-menu []
  (print "TOWER DEFENSE" 40 40 12 true 2)
  (print "Appuyez sur Z pour commencer" 38 70 15)
  (print "par Victor, Thomas, Samy et Logan" 30 90 13))

(fn draw-gameover []
  (print "GAME OVER" 65 50 2 true 2)
  (print (.. "Wave: " wave) 100 75 15)
  (print "Appuyez sur Z pour réessayer" 40 90 12))

(fn draw-victory []
  (print "VICTORY!" 70 50 6 true 2)
  (print "Toutes les vagues sont finies !" 37 75 15)
  (print "Appuyez sur Z pour rejouer" 45 90 12))

(fn draw-base-flash []
  (when (> base-flash-timer 0)
    (when (= (% (math.floor (/ base-flash-timer 4)) 2) 0)
      ;; On a changé le 96 en 88 ici :
      (spr 298 208 88 0 1 0 0 4 4))))

(fn draw-ui []
  (rect 0 0 240 8 0)
  (print (.. "Gold:" gold) 2 1 14)
  (print (.. "Lives:" lives) 60 1 8)
  (print (.. "Wave:" wave) 120 1 12)
  
  (if (> buff-timer 0)
    (print (.. "X2: " (math.ceil (/ buff-timer 60)) "s") 170 1 6)
    (do
      (print "BUFF:" 160 1 11)
      (spr 276 190 0 0 1 0 0 1 1))) 
      
  (when (> message-timer 0)
    (set message-timer (- message-timer 1))
    (print message-flash 70 112 2)))


;; ============================================================
;; INITIALISATION D'UNE NOUVELLE PARTIE
;; ============================================================
;; Remet toutes les variables a leurs valeurs de depart.
;; Appele au premier lancement et a chaque restart.
(fn init-game []
  (set tick 0)
  (set gold 250)
  (set lives 10)
  (set wave 1)
  (set enemies [])
  (set liste-tours [])
  (set nb_click 1)
  (set message-flash nil)
  (set message-timer 0)
  (set shop-mode nil)
  (set shop-tour nil)
  (set shop-emplacement nil)
  (reset-emplacements)
  (set state :playing)
  (set buff-timer 0))

;; ============================================================
;; BOUCLE PRINCIPALE : _G.TIC
;; ============================================================
;; Appelee par TIC-80 a chaque frame (60 fps).
;; Gere les transitions entre les etats du jeu :
;;   :menu     -> affiche le titre, attend Z pour lancer
;;   :playing  -> si shop ouvert : affiche le shop (jeu en pause)
;;               sinon : spawn ennemis, gere les clics,
;;               met a jour ennemis et tours, verifie game over,
;;               dessine tout (map, emplacements, ennemis, tours, UI)
;;   :gameover -> affiche l'ecran de defaite, attend Z pour relancer
;;   :victory  -> affiche l'ecran de victoire, attend Z pour relancer
(fn _G.TIC []
  (set tick (+ tick 1))

  (match state
    :menu     (do
                (cls 0)
                (draw-menu)
                (when (btnp 4) (init-game)))

    :playing  (do
                (if shop-mode
                    (do
                      (if (= shop-mode :achat)
                          (do (draw-shop-achat) (update-shop-achat))
                          (= shop-mode :gestion)
                          (do (draw-shop-gestion) (update-shop-gestion))))

                    (do
                      (when (> buff-timer 0) 
                        (set buff-timer (- buff-timer 1)))
                        
                      (when (> base-flash-timer 0)
                        (set base-flash-timer (- base-flash-timer 1)))

                      (gerer-vagues)
                      (handle-click)
                      (update-enemies)
                      (update-tours)
                      (update-projectiles)
                      (when (<= lives 0) (set state :gameover))
                      (cls 0)
                      (map 0 0 30 17)
                      (draw-emplacements)
                      (draw-enemies)
                      (draw-tours)
                      (draw-projectiles)
                      (draw-base-flash)
                      (draw-ui))))

    :gameover (do
                (cls 0)
                (draw-gameover)
                (when (btnp 4) (init-game)))

    :victory  (do
                (cls 0)
                (draw-victory)
                (when (btnp 4) (init-game)))))