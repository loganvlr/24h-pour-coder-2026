(fn tour [nom-p x-p y-p]
  {
   :nom nom-p
   :x x-p
   :y y-p
   :niveau 1
   :pv 100

   :tirs (fn [self cible-x cible-y]
        
        )

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