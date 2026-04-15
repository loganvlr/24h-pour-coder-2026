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

;; ÉTAT DU JEU
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

;; Reset des emplacements de tours
(fn reset-emplacements []
  (set emplacements-tours
    [ {:x 25  :y 45}
  {:x 73  :y 33}
  {:x 200 :y 32}
  {:x 138 :y 56}
  {:x 66  :y 82} 
  {:x 140  :y 110} 
  {:x 206  :y 80}
  {:x 136  :y 25}]))

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
               (let [dx (- cible-x self.x)
                     dy (- cible-y self.y)
                     dist (math.sqrt (+ (* dx dx) (* dy dy)))]
                 (when (> dist 0)
                   (let [vx (/ dx dist)
                         vy (/ dy dist)
                         move (math.min self.vitesse dist)]
                     (set self.x (+ self.x (* vx move)))
                     (set self.y (+ self.y (* vy move)))))))

   :prendre-degats (fn [self montant]
                     (set self.pv (- self.pv montant))
                     (when (<= self.pv 0)
                       (set self.alive false)))

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
              (set lives (- lives 1)))

   :afficher (fn [self]
               (let [x (math.floor self.x)
                     y (math.floor self.y)]
                 (spr self.sprite (- x 4) (- y 4) 0)
                 (let [w 8
                       filled (math.ceil (* (/ self.pv self.max-pv) w))]
                   (rect (- x 4) (- y 7) w 2 2)
                   (rect (- x 4) (- y 7) filled 2 7))))})

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
  (print (.. "Wave:" wave) 120 1 12)
  ;; Message flash
  (when (> message-timer 0)
    (set message-timer (- message-timer 1))
    (print message-flash 80 120 2)))

;; Indicateur visuel des emplacements disponibles
(fn draw-emplacements []
  (each [_ empla (ipairs emplacements-tours)]
    (rectb empla.x empla.y 16 16 13)))

;; ENEMIES — gestion de la liste
(fn spawn-enemy [nom vitesse pv sprite]
  (let [chosen-path (if (< (math.random) 0.5) path1 path2)
        start (. chosen-path 1)]
    (table.insert enemies
      (creer-ennemi nom start.x start.y vitesse pv sprite chosen-path))))

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

(fn draw-enemies []
  (each [_ enemy (ipairs enemies)]
    (when enemy.alive
      (: enemy :afficher))))

;; Tours
(fn creer-tour [nom-p x-p y-p]
  {:nom nom-p
   :x x-p
   :y y-p
   :niveau 1
   :range 40
   :puissance 5
   :sprite 256
   :timer_tir 0

   :tirs (fn [self]
           (set self.timer_tir (+ self.timer_tir 1))
           (when (>= self.timer_tir 30)
             (var best nil)
             (var best-waypoint 0)
             (each [_ enemy (ipairs enemies)]
               (when (and enemy.alive (> enemy.pv 0))
                 (let [dx (- enemy.x self.x)
                       dy (- enemy.y self.y)
                       dist-sq (+ (* dx dx) (* dy dy))
                       range-sq (* self.range self.range)]
                   (when (and (<= dist-sq range-sq)
                              (>= enemy.index-chemin best-waypoint))
                     (set best enemy)
                     (set best-waypoint enemy.index-chemin)))))
             (when best
               (set self.timer_tir 0)
               (: best :prendre-degats self.puissance))))

   :ameliorer (fn [self]
                (set self.niveau (+ self.niveau 1))
                (set self.range (+ self.range 10))
                (set self.puissance (+ self.puissance 0.5)))

   :afficher (fn [self]
               (spr self.sprite (- self.x 4) (- self.y 4) 0)
               (print self.niveau (- self.x 2) (- self.y 12) 15))})

;; Gestion des tours
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
          (set nb_click 0)
          (var a-supprimer nil)

          (each [i empla (ipairs emplacements) &until a-supprimer]
            (when (and (>= mx empla.x) (<= mx (+ empla.x l))
                       (>= my empla.y) (<= my (+ empla.y l)))
              (if (>= gold 50)
                  (do
                    (set gold (- gold 50))
                    (spawn-tour "Tour Base" empla.x empla.y)
                    (set a-supprimer i))
                  (do
                    (set message-flash "Pas assez d'or !")
                    (set message-timer 60)))))

          (when a-supprimer
            (table.remove emplacements a-supprimer)))

        (when (not clic)
          (set nb_click 1)))))

;; INIT
(fn init-game []
  (set tick 0)
  (set gold 100)
  (set lives 10)
  (set wave 1)
  (set enemies [])
  (set liste-tours [])
  (set nb_click 1)
  (set message-flash nil)
  (set message-timer 0)
  (reset-emplacements)
  (set state :playing))

;; BOUCLE PRINCIPALE
(fn _G.TIC []
  (set tick (+ tick 1))

  (when (and (= state :playing) (= (% tick 30) 0) (< (length enemies) 100))
    (spawn-enemy (.. "basic" tick) 0.5 10 320))

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
                (draw-emplacements)
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