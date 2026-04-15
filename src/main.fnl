;; title:   Tower Defense
;; author:  Logan
;; desc:    Tower Defense game
;; site:    
;; license: MIT License
;; version: 0.1
;; script:  fennel
;; strict:  true

;; CONSTANTES
(local SCREEN-W 224)
(local SCREEN-H 112)
(local TILE-SIZE 16)

;; Chemin des ennemis
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

(global emplacements-tours [
  {:x 20  :y 25}  ; Début du chemin (segment haut)
  {:x 120 :y 5}   ; Milieu du long segment horizontal haut
  {:x 220 :y 30}  ; Près du premier grand virage à droite
  {:x 210 :y 75}  ; Dans le creux du virage à 185, 78
  {:x 150 :y 68}  ; Le long du segment central
  {:x 75  :y 45}  ; Près de la remontée à x=55
  {:x 25  :y 70}  ; Dans la boucle à gauche (zone x=10)
  {:x 80  :y 122} ; Le long du grand segment horizontal bas
  {:x 150 :y 105} ; Avant le dernier virage
  {:x 210 :y 125} ; Proche de la fin du niveau
])
;; ÉTAT DU JEU
(var state :menu) ; :menu, :playing, :gameover, :victory
(var tick 0)
(var gold 100)
(var lives 10)
(var wave 0)
(var enemies [])
(var liste-tours [])
(var toggle-path true)
(var nb_click 1)


;; Classe ennemi
(fn creer-ennemi [nom-p x-p y-p vitesse-p pv-p sprite-p path-p]
  {:nom nom-p
   :x x-p
   :y y-p
   :vitesse vitesse-p
   :index-chemin 1
   :pv pv-p
   :max-pv pv-p
   :sprite sprite-p
   :alive true
   :path path-p

   :deplacer (fn [self cible-x cible-y]
               (if (< self.x cible-x) (set self.x (math.min (+ self.x self.vitesse) cible-x))
                   (> self.x cible-x) (set self.x (math.max (- self.x self.vitesse) cible-x)))
               (if (< self.y cible-y) (set self.y (math.min (+ self.y self.vitesse) cible-y))
                   (> self.y cible-y) (set self.y (math.max (- self.y self.vitesse) cible-y))))

   :prendre-degats (fn [self montant]
                     (set self.pv (- self.pv montant))
                     (when (<= self.pv 0)
                       (set self.alive false)))

   :suivre-chemin (fn [self]
                    (let [cible (. self.path self.index-chemin)]
                      (when cible
                        (: self :deplacer cible.x cible.y)
                        (when (and (= self.x cible.x) (= self.y cible.y))
                          (if (= self.index-chemin (length self.path))
                              (: self :arrivee)
                              (set self.index-chemin (+ self.index-chemin 1)))))))

   :arrivee (fn [self]
              (set self.alive false)
              (set lives (- lives 1)))

   :afficher (fn [self]
               (spr self.sprite (- self.x 4) (- self.y 4) 0)
               (let [w 8
                     filled (math.ceil (* (/ self.pv self.max-pv) w))]
                 (rect (- self.x 4) (- self.y 7) w 2 2)
                 (rect (- self.x 4) (- self.y 7) filled 2 7)))})

;; DRAW — écrans
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

(fn draw-ui []
  (rect 0 0 SCREEN-W 8 0)
  (print (.. "Gold:" gold) 2 1 14)
  (print (.. "Lives:" lives) 60 1 8)
  (print (.. "Wave:" wave) 120 1 12))

;; ENEMIES — gestion de la liste
(fn spawn-enemy [nom vitesse pv sprite]
  (let [chosen-path (if (< (math.random) 0.5) path1 path2)
        start (. chosen-path 1)]
    
    (table.insert enemies
      (creer-ennemi nom start.x start.y vitesse pv sprite chosen-path))

    ;; alterner pour le prochain ennemi
    (set toggle-path (not toggle-path))))

(fn update-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :suivre-chemin))
      )
  (for [i (length enemies) 1 -1]
    (let [enemy (. enemies i)]
      (when (not enemy.alive)
        (when (<= enemy.pv 0)
          (set gold (+ gold 10)))
        (table.remove enemies i)))))

(fn draw-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :afficher))))

;; Tours
;; --- LE CONSTRUCTEUR DE TOUR ---
(fn creer-tour [nom-p x-p y-p]
  {
   :nom nom-p
   :x x-p
   :y y-p
   :niveau 1
   :range 1000
   :puissance 1
   :sprite 1
   :timer_tir 0

   ;; Logique de détection et de tir
  :tirs (fn [self]
  ;; 1. On remet l'état de cible à false et on incrémente le timer
    (set self.timer_tir (+ self.timer_tir 1))

    ;; 2. Si le timer atteint 3
:tirs (fn [self]
    ;; 1. On incrémente le timer
    (set self.timer_tir (+ self.timer_tir 1))

    ;; 2. On ne cherche une cible QUE si le timer est prêt (ex: >= 30 frames)
    (if (>= self.timer_tir 30)
        (do
          ;; On utilise une variable locale pour la recherche
          (var cible-trouvee? false)
          
          (each [_ enemy (ipairs enemies) &until cible-trouvee?] 
            (let [dx (- enemy.x self.x)
                  dy (- enemy.y self.y)
                  dist-sq (+ (* dx dx) (* dy dy))
                  range-sq (* self.range self.range)]
              
              (when (<= dist-sq range-sq)
                (set cible-trouvee? true)
                (set self.timer_tir 0)
                (: enemy :prendre-degats self.puissance)
                (set self.cibles true)))))))

  )


   ;; Amélioration de la tour
   :ameliorer (fn [self]
                (set self.niveau (+ self.niveau 1))
                (set self.range (+ self.range 10))
                (set self.puissance (+ self.puissance 0.5)))

   ;; Affichage graphique
   :afficher (fn [self]
               ;; Dessine la tour
               (spr self.sprite (- self.x 4) (- self.y 4) 0)
               ;; Affiche le niveau au-dessus
               (print self.niveau (- self.x 2) (- self.y 12) 15))
  })

;; --- FONCTIONS DE GESTION ---

(fn spawn-tour [nom x y]
  (table.insert liste-tours (creer-tour nom x y)))

(fn update-tours []
  (each [_ t (ipairs liste-tours)]
    (: t :tirs)))

(fn draw-tours []
  (each [_ t (ipairs liste-tours)]
    (: t :afficher)))




(fn place-tour [emplacements l]
  (let [(mx my clic) (mouse)]
    (if (and clic (= nb_click 1))
        (do
          (set nb_click 0) ; On bloque le clic unique
          (var a-supprimer nil) ; On va stocker l'index à supprimer ici

          (each [i empla (ipairs emplacements) &until a-supprimer]
            (when (and (>= mx empla.x) (<= mx (+ empla.x l))
                       (>= my empla.y) (<= my (+ empla.y l)))
              (if (>= gold 50)
                  (do
                    (set gold (- gold 50))
                    (spawn-tour "Tour Base" empla.x empla.y)
                    (set a-supprimer i)) ; On a trouvé, on stocke l'index
                  (print "Pas assez d'or" mx (- my 10) 6))))

          ;; Si on a trouvé un emplacement valide, on le retire de la liste
          (when a-supprimer
            (table.remove emplacements a-supprimer)))

        ;; Reset du clic quand on relâche
        (not clic)
        (set nb_click 1))))


;; INIT
(fn init-game []
  (set tick 0)
  (set gold 100)
  (set lives 1000)
  (set wave 1)
  (set enemies [])
  (spawn-enemy "basic1" 1 100 1)

  (set state :playing))

;; BOUCLE PRINCIPALE
(fn _G.TIC []
  (set tick (+ tick 1))

  (when (and (= state :playing) (= (% tick 30) 0) (< (length enemies) 100))
    (spawn-enemy (.. "basic" tick) 1 1000 320))



  (match state
    :menu     (do
                (cls 0)
                (draw-menu)
                (when (btnp 4) (init-game)))

    :playing  (do
                (place-tour emplacements-tours 16)
                (update-enemies)
                (update-tours)
                (when (<= lives 0) (set state :gameover))
                (cls 0)
                (map 0 0 30 17)
                (draw-enemies)
                (draw-tours)
                (draw-ui)
                (let [(mx my pressed) (mouse)]
                  (print (.. "x:" mx) 170 1 15)
                  (print (.. "y:" my) 205 1 15)))

    :gameover (do
                (cls 0)
                (draw-gameover)
                (when (btnp 4) (init-game)))

    :victory  (do
                (cls 0)
                (draw-victory)
                (when (btnp 4) (init-game)))))