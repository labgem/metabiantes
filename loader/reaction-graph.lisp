
(defun reaction-layout (pathway)
  (get-pwy-reaction-layout pathway nil gkb::*current-kb*))

(defun format-reaction-direction (direction)
  (cond ((equal direction :L2R) "left-to-right")
        ((equal direction :R2L) "right-to-left")))

(defun parse-reaction-metabolite-graph-edges (pathway)
  (let ((layout (reaction-layout pathway))
        (graph-edges ())
        (u-compounds ())
        (v-compounds ())
        (formatted-direction ()))
    (loop for reaction-edge in layout
          for reaction = (car reaction-edge)
          for left-primaries = (cdr (nth 1 reaction-edge))
          for right-primaries = (cdr (nth 3 reaction-edge))
          for direction = (cdr (nth 2 reaction-edge))
          do (progn
               (cond 
                      ((equal (car direction) :L2R)
                       (progn
                       (setq u-compounds left-primaries)
                       (setq v-compounds right-primaries)))
                      ((equal (car direction) :R2L)
                       (progn
                       (setq u-compounds right-primaries)
                       (setq v-compounds left-primaries)))
                   )
               (setq formatted-direction (format-reaction-direction (car direction)))
               (loop for u in u-compounds
                     do (progn
                          (loop for v in v-compounds
                            do
                               (setq graph-edges (cons (list reaction u v formatted-direction) graph-edges)))))))
    graph-edges))


(defun metabolite-graph-edges-to-reaction-graph-edges (edges)
  (let ((reaction-edges ()))
    (loop for edge1 in edges
          for reaction1 = (nth 0 edge1)
          for target-compound = (nth 2 edge1)
          do (loop for edge2 in edges
                   for reaction2 = (nth 0 edge2)
                   for source-compound = (nth 1 edge2)
                   when (equal source-compound target-compound)
                     do (setq reaction-edges (cons (cons reaction1 reaction2) reaction-edges))))
    reaction-edges))
; example for D-apiose: PWY-8089
; RXN-20929 -> RXN-20928 -> RXN-20930, hence two edges.
; ((#<"RXN-20928" instance frame in METABASE[F] @ #x100240be682>
;;   #<"RXN-20930" instance frame in METABASE[F] @ #x100241d5aa2>)
;;  (#<"RXN-20929" instance frame in METABASE[F] @ #x100259af8e2>
;;   #<"RXN-20928" instance frame in METABASE[F] @ #x100240be682>)) 
;; ;


;; (defun main ()
;;   (select-organism :org-id 'meta)
;;   (print (metabolite-graph-edges-to-reaction-graph-edges
;;           (parse-reaction-metabolite-graph-edges '|PWY-8089|)))
;;   )

; (main)
