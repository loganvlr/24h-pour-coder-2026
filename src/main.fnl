;; title:   Tower Defense
;; author:  Logan
;; desc:    Tower Defense game
;; site:    
;; license: MIT License
;; version: 0.1
;; script:  fennel
;; strict:  true

;; Classe ennemi
(fn creer_ennemi [nom-p x-p y-p chemin-p]
  {
   :nom nom-p
   :x x-p
   :y y-p
   :vitesse 1
   :index-chemin 1 ; En Lua/Fennel, on commence à 1
   :pv 100
   :chemin chemin-p

   :deplacer (fn [self cible-x cible-y]
               (if (< self.x cible-x) (set self.x (+ self.x self.vitesse))
                   (> self.x cible-x) (set self.x (- self.x self.vitesse)))
               (if (< self.y cible-y) (set self.y (+ self.y self.vitesse))
                   (> self.y cible-y) (set self.y (- self.y self.vitesse))))

   :prendre-degats (fn [self montant]
                     (set self.pv (- self.pv montant)))

   ;; Méthode pour suivre le chemin
:suivre-chemin (fn [self]
                 (let [cible (. self.chemin self.index-chemin)]
                   (when cible
                     ;; 1. On se déplace vers la cible
                     (: self :deplacer cible.x cible.y)

                     ;; 2. Si on est arrivé au waypoint
                     (when (and (= self.x cible.x) (= self.y cible.y))
                       (if (= self.index-chemin (length self.chemin))
                           ;; Si c'est le dernier point -> Arrivée
                           (: self :arrivee) 
                           ;; Sinon -> On passe au suivant
                           (set self.index-chemin (+ self.index-chemin 1)))))))

    :arrivee (fn [self]
        (print "Quincieu zgeg")
    )

    :afficher (fn [self]
                ; spr dessine un sprite. Ici, on imagine que le sprite de base est le numéro 1
                (spr 1 self.x self.y 0))  
   })

;; CONSTANTES

(local SCREEN-W 240)
(local SCREEN-H 136)
(local TILE-SIZE 8)

;; ÉTAT DU JEU

(var state :menu)
(var tick 0)

;; DRAW — écrans

(fn draw-menu []
  (print "TOWER DEFENSE" 75 40 12 true 2)
  (print "Press Z to Start" 72 70 15)
  (print "by Logan" 88 90 13))

(fn draw-gameover []
  (print "GAME OVER" 80 50 2 true 2)
  (print "Press Z to Retry" 68 90 12))

(fn draw-victory []
  (print "VICTORY!" 82 50 6 true 2)
  (print "All waves cleared!" 68 75 15)
  (print "Press Z to Replay" 66 90 12))

;; INIT

(fn init-game []
  (set tick 0)
  (set state :playing))
  ;; Change to :playing when game logic is implemented

(global path [{:x 0 :y 64}
                {:x 48 :y 64}
                {:x 48 :y 32}
                {:x 112 :y 32}
                {:x 112 :y 96}
                {:x 192 :y 96}])
;; DECLAS ENNEMIS
(global ennemi (creer_ennemi "test" 60 60 path))

;; BOUCLE PRINCIPALE

(fn _G.TIC []
  (set tick (+ tick 1))

  (match state
    :menu     (do
                (cls 0)
                (draw-menu)
                (when (btnp 4) (init-game)))

    :playing  (do
                (cls 0)
                ; 1. On ajoute les ":" devant afficher
                (: ennemi :afficher)
                
                (: ennemi :suivre-chemin))

    :gameover (do
                (cls 0)
                (draw-gameover)
                (when (btnp 4) (init-game)))

    :victory  (do
                (cls 0)
                (draw-victory)
                (when (btnp 4) (init-game)))))