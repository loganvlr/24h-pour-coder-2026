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
  {:ecraseur  {:cout 50  :puissance 3  :range 40 :cooldown 30 :sprite 392 :nom "Ecraseur"}
   :tesla    {:cout 80  :puissance 7  :range 30 :cooldown 60 :sprite 366 :nom "Tesla"}
   :canon  {:cout 120 :puissance 15 :range 60 :cooldown 90 :sprite 430 :nom "Canon"}})

;; Cout pour ameliorer une tour selon son niveau actuel.
;; Index 1 = passage du niveau 1 au 2, index 2 = niveau 2 au 3, etc.
(local UPGRADE-COUTS [40 80 150])
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
(var gold 100)
(var lives 10)
(var wave 0)
(var enemies [])
(var liste-tours [])
(var nb_click 1)
(var emplacements-tours [])
(var message-flash nil)
(var message-timer 0)

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
      {:x 206 :y 71}
      {:x 206 :y 88}
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
(fn creer-ennemi [nom-p x-p y-p vitesse-p pv-p sprite-p path-p]
  {:nom nom-p
   :x x-p
   :y y-p
   :vitesse vitesse-p
   :index-chemin 1     ;; index du prochain waypoint a atteindre (commence a 1)
   :pv pv-p            ;; points de vie actuels
   :max-pv pv-p        ;; points de vie max (pour la barre de vie)
   :sprite sprite-p
   :alive true          ;; false quand l'ennemi est mort ou arrive au bout
   :path path-p         ;; reference vers le tableau de waypoints

   ;; Deplace l'ennemi vers une position cible (cible-x, cible-y).
   ;; Utilise la normalisation du vecteur direction pour un deplacement
   ;; fluide en diagonale. math.min empeche de depasser la cible.
   :deplacer (fn [self cible-x cible-y]
               (let [dx (- cible-x self.x)
                     dy (- cible-y self.y)
                     dist (math.sqrt (+ (* dx dx) (* dy dy)))]
                 (when (> dist 0)
                   (if (> self.x cible-x) (set self.direction 0) (set self.direction 1))
                   (let [vx (/ dx dist)
                         vy (/ dy dist)
                         move (math.min self.vitesse dist)]
                     (set self.x (+ self.x (* vx move)))
                     (set self.y (+ self.y (* vy move)))))))

   ;; Inflige des degats a l'ennemi. Si les PV tombent a 0 ou moins,
   ;; l'ennemi est marque comme mort.
   :prendre-degats (fn [self montant]
                     (set self.pv (- self.pv montant))
                     (when (<= self.pv 0)
                       (set self.alive false)))

   ;; Fait avancer l'ennemi le long de son chemin.
   ;; A chaque frame, il se deplace vers le waypoint courant.
   ;; Quand il l'atteint (comparaison avec math.floor pour gerer
   ;; les positions decimales), il passe au waypoint suivant.
   ;; S'il a atteint le dernier waypoint, il appelle :arrivee.
   :suivre-chemin (fn [self]
                    (let [cible (. self.path self.index-chemin)]
                      (when cible
                        (: self :deplacer cible.x cible.y)
                        (when (and (= (math.floor self.x) cible.x)
                                   (= (math.floor self.y) cible.y))
                          (if (= self.index-chemin (length self.path))
                              (: self :arrivee)
                              (set self.index-chemin (+ self.index-chemin 1)))))))

   ;; Appele quand l'ennemi atteint la fin du chemin.
   ;; Le joueur perd une vie et l'ennemi est retire du jeu.
   :arrivee (fn [self]
              (set self.alive false)
              (set lives (- lives 1)))

   ;; Dessine l'ennemi a l'ecran : son sprite centre sur sa position,
   ;; puis une barre de vie au-dessus (rouge = fond, vert = vie restante).
   :afficher (fn [self]
                   (set self.timer-anim (+ (or self.timer-anim 0) 1))
    (when (>= self.timer-anim 12) ; Change de sprite toutes les 15 frames
      (set self.timer-anim 0)
      (if (= self.etat 1) (set self.etat 2) (set self.etat 1)))

    ;; 2. On prépare les coordonnées
    (let [x (math.floor self.x)
          y (math.floor self.y)
          ;; On choisit le sprite selon l'état
          sprite (if (= self.etat 1) 337 336)]
          (if (= self.direction 0) (spr sprite (- x 4) (- y 4) 0 1 1) (spr sprite (- x 4) (- y 4) 0))

          
          (let [w 8
                       filled (math.ceil (* (/ self.pv self.max-pv) w))]
                   (rect (- x 4) (- y 7) w 2 2)
                   (rect (- x 4) (- y 7) filled 2 7))))})

;; ============================================================
;; GESTION DES ENNEMIS
;; ============================================================

;; Cree un nouvel ennemi au debut d'un chemin choisi au hasard
;; et l'ajoute a la liste des ennemis actifs.
(fn spawn-enemy [nom vitesse pv sprite]
  (let [chosen-path (if (< (math.random) 0.5) path1 path2)
        start (. chosen-path 1)]
    (table.insert enemies
      (creer-ennemi nom start.x start.y vitesse pv sprite chosen-path))))

;; Met a jour tous les ennemis : deplacement puis nettoyage des morts.
;; La suppression se fait en boucle inversee pour ne pas decaler les index.
;; Quand un ennemi meurt par degats (pv <= 0), le joueur gagne du gold.
(fn update-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :suivre-chemin)))
  (for [i (length enemies) 1 -1]
    (let [enemy (. enemies i)]
      (when (not enemy.alive)
        (when (<= enemy.pv 0)
          (set gold (+ gold 10)))
        (table.remove enemies i)))))

;; Dessine tous les ennemis vivants a l'ecran.
(fn draw-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :afficher))))

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
    {:nom nom-p
     :x x-p
     :y y-p
     :type type-key
     :niveau 1
     :range template.range
     :puissance template.puissance
     :sprite template.sprite
     :cooldown template.cooldown
     :timer_tir 0
     ;; Direction du canon : 0=droite, 1=bas, 2=gauche, 3=haut
     ;; Seul le canon utilise cette propriete, les autres tours l'ignorent
     :direction 0

     ;; Verifie si un ennemi est dans la ligne de tir du canon.
     ;; Le canon ne tire que dans un couloir aligne sur sa direction.
     ;; Le couloir fait 16 pixels de large (la taille d'une tile).
     ;; Retourne true si l'ennemi est dans le couloir ET dans la portee.
     :dans-ligne-de-tir (fn [self enemy-x enemy-y]
       (let [cx (+ self.x 8)
             cy (+ self.y 8)
             dx (- enemy-x cx)
             dy (- enemy-y cy)
             largeur 16]
         (if
           ;; Direction droite : ennemi a droite, aligne verticalement
           (= self.direction 0)
           (and (> dx 0) (<= dx self.range)
                (>= dy (- 0 (/ largeur 2))) (<= dy (/ largeur 2)))

           ;; Direction bas : ennemi en bas, aligne horizontalement
           (= self.direction 1)
           (and (> dy 0) (<= dy self.range)
                (>= dx (- 0 (/ largeur 2))) (<= dx (/ largeur 2)))

           ;; Direction gauche : ennemi a gauche, aligne verticalement
           (= self.direction 2)
           (and (< dx 0) (>= dx (- 0 self.range))
                (>= dy (- 0 (/ largeur 2))) (<= dy (/ largeur 2)))

           ;; Direction haut : ennemi en haut, aligne horizontalement
           (= self.direction 3)
           (and (< dy 0) (>= dy (- 0 self.range))
                (>= dx (- 0 (/ largeur 2))) (<= dx (/ largeur 2)))

           ;; Fallback
           false)))

     ;; Logique de tir.
     ;; Pour le canon : verifie que l'ennemi est dans la ligne de tir.
     ;; Pour les autres tours : verifie la distance circulaire classique.
     ;; Dans les deux cas, cible l'ennemi le plus avance dans le chemin.
     :tirs (fn [self]
             (set self.timer_tir (+ self.timer_tir 1))
             (when (>= self.timer_tir self.cooldown)
               (var best nil)
               (var best-waypoint 0)
               (let [cx (+ self.x 8)
                     cy (+ self.y 8)]
                 (each [_ enemy (ipairs enemies)]
                   (when (and enemy.alive (> enemy.pv 0))
                     (let [in-range
                           (if (= self.type :canon)
                               ;; Canon : detection en ligne
                               (: self :dans-ligne-de-tir enemy.x enemy.y)
                               ;; Autres tours : detection circulaire
                               (let [dx (- enemy.x cx)
                                     dy (- enemy.y cy)
                                     dist-sq (+ (* dx dx) (* dy dy))
                                     range-sq (* self.range self.range)]
                                 (<= dist-sq range-sq)))]
                       (when (and in-range
                                  (>= enemy.index-chemin best-waypoint))
                         (set best enemy)
                         (set best-waypoint enemy.index-chemin))))))
               (when best
                 (set self.timer_tir 0)
                 (: best :prendre-degats self.puissance))))

     ;; Tourne le canon dans la direction suivante (cycle : 0->1->2->3->0)
     :tourner (fn [self]
                (set self.direction (% (+ self.direction 1) 4)))

     :ameliorer (fn [self]
                  (set self.niveau (+ self.niveau 1))
                  (set self.range (+ self.range 8))
                  (set self.puissance (+ self.puissance 3))
                  (set self.cooldown (math.max 10 (- self.cooldown 5))))

     :valeur-vente (fn [self]
                     (let [template (. TOUR-TYPES self.type)
                           base template.cout]
                       (var total base)
                       (for [i 1 (- self.niveau 1)]
                         (when (<= i (length UPGRADE-COUTS))
                           (set total (+ total (. UPGRADE-COUTS i)))))
                       (math.floor (* total 0.5))))

     ;; Affichage de la tour.
     ;; Pour le canon, dessine aussi un indicateur de direction
     ;; sous forme de ligne depuis le centre vers la direction de tir.
     :afficher (fn [self]
                 ;; Le parametre "flip" de spr permet de retourner le sprite.
                 ;; rotation : 0=normal, 1=90deg, 2=180deg, 3=270deg
                 ;; On utilise la direction du canon comme rotation du sprite.
                 (let [rot (if (= self.type :canon) (% (+ self.direction 3) 4) 0)]
                  (spr self.sprite self.x self.y 0 1 0 rot 2 2))
                 (print self.niveau (+ self.x 6) (- self.y 8) 15)

                 ;; Indicateur de direction pour le canon (ligne de tir)
                 (when (= self.type :canon)
                   (let [cx (+ self.x 8)
                         cy (+ self.y 8)
                         len self.range]
                     (if (= self.direction 0) (line cx cy (+ cx len) cy 2)
                         (= self.direction 1) (line cx cy cx (+ cy len) 2)
                         (= self.direction 2) (line cx cy (- cx len) cy 2)
                         (= self.direction 3) (line cx cy cx (- cy len) 2)))))}))

;; ============================================================
;; GESTION DES TOURS
;; ============================================================

;; Cree une nouvelle tour et l'ajoute a la liste des tours actives.
(fn spawn-tour [nom x y type-key]
  (table.insert liste-tours (creer-tour nom x y type-key)))

;; Met a jour toutes les tours : chacune execute sa logique de tir.
(fn update-tours []
  (each [_ t (ipairs liste-tours)]
    (: t :tirs)))

;; Dessine toutes les tours a l'ecran.
(fn draw-tours []
  (each [_ t (ipairs liste-tours)]
    (: t :afficher)))

;; Dessine les emplacements disponibles sous forme de carres gris.
;; Permet au joueur de voir ou il peut construire.
(fn draw-emplacements []
  (each [_ empla (ipairs emplacements-tours)]
    (rectb empla.x empla.y 16 16 13)))

;; Cherche si une tour existe a la position pixel (px, py).
;; Retourne la tour et son index si trouvee, nil sinon.
;; Utilise pour detecter le clic sur une tour existante.
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

;; Dessine l'ecran d'achat avec les 3 types de tours et leurs stats.
;; Le curseur est mis en surbrillance avec une couleur differente.
(fn draw-shop-achat []
  (cls 0)
  (print "CHOISIR UNE TOUR" 65 5 12 true)
  (print (.. "Gold: " gold) 5 5 14)

  ;; ecraseur : tour rapide, degats faibles, longue portee
  (let [sel (= shop-cursor 0)
        col (if sel 6 13)
        t (. TOUR-TYPES :ecraseur)]
    (rectb 20 25 200 22 col)
    (when sel (rect 21 26 198 20 1))
    (print (.. "ECRASEUR  -  $" t.cout) 30 29 col)
    (print (.. "DMG:" t.puissance " RNG:" t.range " SPD:" t.cooldown) 30 38 15))

  ;; tesla : tour equilibree, degats moyens, portee moyenne
  (let [sel (= shop-cursor 1)
        col (if sel 9 13)
        t (. TOUR-TYPES :tesla)]
    (rectb 20 52 200 22 col)
    (when sel (rect 21 53 198 20 1))
    (print (.. "TESLA  -  $" t.cout) 30 56 col)
    (print (.. "DMG:" t.puissance " RNG:" t.range " SPD:" t.cooldown) 30 65 15))

  ;; Canon : tour lente, gros degats, courte portee
  (let [sel (= shop-cursor 2)
        col (if sel 2 13)
        t (. TOUR-TYPES :canon)]
    (rectb 20 79 200 22 col)
    (when sel (rect 21 80 198 20 1))
    (print (.. "CANON  -  $" t.cout) 30 83 col)
    (print (.. "DMG:" t.puissance " RNG:" t.range " SPD:" t.cooldown) 30 92 15))

  ;; Option annuler pour fermer le shop sans acheter
  (let [sel (= shop-cursor 3)
        col (if sel 8 13)]
    (rectb 20 106 200 14 col)
    (when sel (rect 21 107 198 12 1))
    (print "ANNULER" 30 109 col))

  (print "UP/DOWN: choisir  Z: confirmer" 30 125 13))

;; Gere les inputs dans l'ecran d'achat.
;; Haut/bas deplace le curseur, Z confirme la selection.
;; Si le joueur n'a pas assez d'or, un message flash s'affiche
;; et le shop se ferme.
(fn update-shop-achat []
  (when (btnp 0) (set shop-cursor (math.max 0 (- shop-cursor 1))))
  (when (btnp 1) (set shop-cursor (math.min 3 (+ shop-cursor 1))))

  (when (btnp 4)
    (if (= shop-cursor 3)
        ;; Le joueur a choisi d'annuler
        (set shop-mode nil)

        ;; Le joueur a choisi un type de tour
        (let [type-key (if (= shop-cursor 0) :ecraseur
                           (= shop-cursor 1) :tesla
                           :canon)
              template (. TOUR-TYPES type-key)]
          (if (>= gold template.cout)
              ;; Assez d'or : creer la tour, retirer l'emplacement, fermer le shop
              (do
                (set gold (- gold template.cout))
                (spawn-tour template.nom shop-emplacement.x shop-emplacement.y type-key)
                (table.remove emplacements-tours shop-emplacement-idx)
                (set shop-mode nil))
              ;; Pas assez d'or : afficher un message et fermer
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

;; Dessine l'ecran de gestion avec les stats actuelles de la tour,
;; les options d'amelioration (avec preview des nouvelles stats),
;; de vente (avec le prix de rachat) et de retour.
(fn draw-shop-gestion []
  (cls 0)
  (let [tour shop-tour
        template (. TOUR-TYPES tour.type)
        is-canon (= tour.type :canon)
        ;; Noms des directions pour l'affichage
        dir-noms ["Droite" "Bas" "Gauche" "Haut"]]
    (print (.. "GESTION : " template.nom) 55 5 12 true)
    (print (.. "Gold: " gold) 5 5 14)

    ;; Stats actuelles
    (print (.. "Niveau: " tour.niveau "/" MAX-NIVEAU) 30 22 15)
    (print (.. "Degats: " tour.puissance) 30 32 15)
    (print (.. "Portee: " tour.range) 30 42 15)
    (print (.. "Vitesse: " tour.cooldown " (bas=rapide)") 30 52 15)
    ;; Afficher la direction si c'est un canon
    (when is-canon
      (print (.. "Direction: " (. dir-noms (+ tour.direction 1))) 130 42 2))

    ;; Option 0 : Ameliorer
    (let [sel (= shop-cursor 0)
          col (if sel 6 13)
          can-upgrade (< tour.niveau MAX-NIVEAU)
          upgrade-cout (if can-upgrade (. UPGRADE-COUTS tour.niveau) 0)]
      (rectb 20 62 200 22 col)
      (when sel (rect 21 63 198 20 1))
      (if can-upgrade
          (do
            (print (.. "AMELIORER  -  $" upgrade-cout) 30 66 col)
            (print (.. "-> DMG:" (+ tour.puissance 3)
                       " RNG:" (+ tour.range 8)
                       " SPD:" (math.max 10 (- tour.cooldown 5))) 30 75 11))
          (print "NIVEAU MAX ATTEINT" 30 69 8)))

    ;; Option 1 : Tourner (seulement pour le canon)
    (let [sel (= shop-cursor 1)
          col (if sel 12 13)]
      (rectb 20 87 200 14 col)
      (when sel (rect 21 88 198 12 1))
      (if is-canon
          (let [next-dir (. dir-noms (+ (% (+ tour.direction 1) 4) 1))]
            (print (.. "TOURNER -> " next-dir) 30 90 col))
          (print "-- non disponible --" 30 90 7)))

    ;; Option 2 : Vendre
    (let [sel (= shop-cursor 2)
          col (if sel 14 13)
          prix-vente (: tour :valeur-vente)]
      (rectb 20 104 200 14 col)
      (when sel (rect 21 105 198 12 1))
      (print (.. "VENDRE  +$" prix-vente) 30 107 col))

    ;; Option 3 : Retour
    (let [sel (= shop-cursor 3)
          col (if sel 8 13)]
      (rectb 20 121 200 14 col)
      (when sel (rect 21 122 198 12 1))
      (print "RETOUR" 30 124 col))

    (print "UP/DOWN: choisir  Z: confirmer" 30 130 13)))

(fn update-shop-gestion []
  (when (btnp 0) (set shop-cursor (math.max 0 (- shop-cursor 1))))
  (when (btnp 1) (set shop-cursor (math.min 3 (+ shop-cursor 1))))

  (when (btnp 4)
    (if
      ;; Ameliorer
      (= shop-cursor 0)
      (let [tour shop-tour]
        (when (< tour.niveau MAX-NIVEAU)
          (let [cout (. UPGRADE-COUTS tour.niveau)]
            (if (>= gold cout)
                (do
                  (set gold (- gold cout))
                  (: tour :ameliorer))
                (do
                  (set message-flash "Pas assez d'or !")
                  (set message-timer 60)
                  (set shop-mode nil))))))

      ;; Tourner (seulement pour le canon)
      (= shop-cursor 1)
      (when (= shop-tour.type :canon)
        (: shop-tour :tourner))

      ;; Vendre
      (= shop-cursor 2)
      (let [tour shop-tour
            prix (: tour :valeur-vente)]
        (set gold (+ gold prix))
        (table.insert emplacements-tours {:x tour.x :y tour.y})
        (table.remove liste-tours shop-tour-idx)
        (set shop-mode nil))

      ;; Retour
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

          ;; Verifier si le clic est sur une tour existante
          (let [(tour idx) (find-tour-at mx my)]
            (if tour
                ;; Tour trouvee : ouvrir le menu de gestion
                (do
                  (set shop-tour tour)
                  (set shop-tour-idx idx)
                  (set shop-cursor 0)
                  (set shop-mode :gestion))

                ;; Pas de tour : verifier si c'est un emplacement libre
                (do
                  (var found false)
                  (each [i empla (ipairs emplacements-tours) &until found]
                    (when (and (>= mx empla.x) (<= mx (+ empla.x 16))
                               (>= my empla.y) (<= my (+ empla.y 16)))
                      (set found true)
                      (set shop-emplacement empla)
                      (set shop-emplacement-idx i)
                      (set shop-cursor 0)
                      (set shop-mode :achat)))))))

        ;; Quand le bouton est relache, reactiver la detection
        (when (not clic)
          (set nb_click 1)))))

;; ============================================================
;; ECRANS PRINCIPAUX (menu, game over, victoire)
;; ============================================================

;; Ecran titre affiche au lancement du jeu.
(fn draw-menu []
  (print "TOWER DEFENSE" 40 40 12 true 2)
  (print "Appuyez sur Z pour commencer" 38 70 15)
  (print "par Victor, Thomas, Samy et Logan" 30 90 13))

;; Ecran de defaite avec le numero de vague atteint.
(fn draw-gameover []
  (print "GAME OVER" 65 50 2 true 2)
  (print (.. "Wave: " wave) 100 75 15)
  (print "Appuyez sur Z pour réessayer" 40 90 12))

;; Ecran de victoire quand toutes les vagues sont terminees.
(fn draw-victory []
  (print "VICTORY!" 70 50 6 true 2)
  (print "Toutes les vagues sont finies !" 37 75 15)
  (print "Appuyez sur Z pour rejouer" 45 90 12))

;; Interface en jeu : barre noire en haut avec gold, vies et vague.
;; Affiche aussi le message flash temporaire s'il y en a un.
(fn draw-ui []
  (rect 0 0 240 8 0)
  (print (.. "Gold:" gold) 2 1 14)
  (print (.. "Lives:" lives) 60 1 8)
  (print (.. "Wave:" wave) 120 1 12)
  (when (> message-timer 0)
    (set message-timer (- message-timer 1))
    (print message-flash 70 112 2)))


;;Vagues
(var numero_wave 1)
(var nb_ennemis 0)

(fn vague [numero]

  (if (= numero 1)
    (if (< nb_ennemis 15)
      (when (and (= (% tick 30) 0) (< (length enemies) 100))
      (set nb_ennemis (+ nb_ennemis 1))
      (spawn-enemy (.. "basic" tick) 0.5 10 320))
      )
      (set numero_wave (+ numero_wave 1))
  )
)

;; ============================================================
;; INITIALISATION D'UNE NOUVELLE PARTIE
;; ============================================================
;; Remet toutes les variables a leurs valeurs de depart.
;; Appele au premier lancement et a chaque restart.
(fn init-game []
  (set tick 0)
  (set gold 1000)
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
  (set state :playing))

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
                    ;; Shop ouvert : le jeu est en pause, seul le shop est actif
                    (do
                      (if (= shop-mode :achat)
                          (do (draw-shop-achat) (update-shop-achat))
                          (= shop-mode :gestion)
                          (do (draw-shop-gestion) (update-shop-gestion))))

                    ;; Pas de shop : gameplay normal
                    (do
                      ;; Spawn d'un ennemi toutes les 30 frames (0.5 sec)
                      ;; tant qu'il y a moins de 100 ennemis a l'ecran

                      (vague 1)
                      (handle-click)
                      (update-enemies)
                      (update-tours)
                      (when (<= lives 0) (set state :gameover))
                      (cls 0)
                      (map 0 0 30 17)
                      (draw-emplacements)
                      (draw-enemies)
                      (draw-tours)
                      (draw-ui))))

    :gameover (do
                (cls 0)
                (draw-gameover)
                (when (btnp 4) (init-game)))

    :victory  (do
                (cls 0)
                (draw-victory)
                (when (btnp 4) (init-game)))))