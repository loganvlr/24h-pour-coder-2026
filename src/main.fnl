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
(local path [{:x 0 :y 64}
             {:x 48 :y 64}
             {:x 48 :y 32}
             {:x 112 :y 32}
             {:x 112 :y 96}
             {:x 192 :y 96}])

;; ÉTAT DU JEU
(var state :menu) ; :menu, :playing, :gameover, :victory
(var tick 0)
(var gold 100)
(var lives 10)
(var wave 0)
(var enemies [])

;; Classe ennemi
(fn creer-ennemi [nom-p x-p y-p vitesse-p pv-p sprite-p]
  {:nom nom-p
   :x x-p
   :y y-p
   :vitesse vitesse-p
   :index-chemin 1
   :pv pv-p
   :max-pv pv-p
   :sprite sprite-p
   :alive true

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
                    (let [cible (. path self.index-chemin)]
                      (when cible
                        (: self :deplacer cible.x cible.y)
                        (when (and (= self.x cible.x) (= self.y cible.y))
                          (if (= self.index-chemin (length path))
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
                 (rect (- self.x 4) (- self.y 7) filled 2 6)))})

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
  (let [start (. path 1)]
    (table.insert enemies (creer-ennemi nom start.x start.y vitesse pv sprite))))

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

;; INIT
(fn init-game []
  (set tick 0)
  (set gold 100)
  (set lives 10)
  (set wave 1)
  (set enemies [])
  (spawn-enemy "basic1" 1 100 1)
  (set state :playing))

;; BOUCLE PRINCIPALE
(fn _G.TIC []
  (set tick (+ tick 1))

  (when (and (= state :playing) (= (% tick 30) 0) (< (length enemies) 5))
    (spawn-enemy (.. "basic" tick) 1 100 1))

  (match state
    :menu     (do
                (cls 0)
                (draw-menu)
                (when (btnp 4) (init-game)))

    :playing  (do
                (update-enemies)
                (when (<= lives 0) (set state :gameover))
                (cls 0)
                (map 0 0 30 17)
                (draw-enemies)
                (draw-ui))

    :gameover (do
                (cls 0)
                (draw-gameover)
                (when (btnp 4) (init-game)))

    :victory  (do
                (cls 0)
                (draw-victory)
                (when (btnp 4) (init-game)))))