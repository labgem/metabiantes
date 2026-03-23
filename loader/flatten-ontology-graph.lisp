;; Exemple: EC(): (build-ontology-graph '|Pathways|)
;;
;; ((("group" . "nodes")
;;   ("data" ("id" . |Pathways|) ("label" . "Pathways")
;;    ("frame-id" . |Pathways|)
;;    ("ttip"
;;     . "This class is the root of a classification hierarchy for metabolic
;; pathways.  Its subclasses divide pathways into groups
;; based on their biological functions, and based on the classes
;; of metabolites that they produce and/or consume.")
;;    ("url" . "/ECOLI/class-tree?object=Pathways")
;;    ("parents" |Generalized-Reactions|) ("nChildren" . 13)
;;    ("nSubclasses" . 12))
;;   ("position" ("x") ("y")) ("classes" . "keyframe")))

                                        ; On a (car ontology-graph), for exemple
                                        ; (("group" . "nodes")
;; ("data" ("id" . |D-Apiose-Degradation|)
;;  ("label" . "D-Apiose Degradation")
;;  ("frame-id" . |D-Apiose-Degradation|)
;;  ("ttip"
;;   . "This class holds pathways for the degradation of D-apiose.")
;;  ("url"
;;   . "/META/NEW-IMAGE?type=ECOCYC-CLASS&object=D-Apiose-Degradation")
;;  ("parents" |Sugars-And-Polysaccharides-Degradation|)
;;  ("nChildren" . 2) ("nSubclasses" . 0))
;; ("position" ("x") ("y")) ("classes" . "kbClass"))
                                        ; retrieve the id '|D-Apiose-Degradation|
(defun get-id-of-ontology-item (ontology-item)
  (cdr ; on |D-Apiose-Degradation|
   (car ; on ("id" . ...)
    (cdr ; skip "data" item
     (car ; on ("data" ...) item
      (cdr ; skip ("group" . "nodes")
       ontology-item))))))
                                        ; test: (get-id-of-ontology-item (car (build-ontology-graph '|PWY-8089|)
                                        ; expect: |D-Apiose-Degradation|

(defun get-parents-of-ontology-item (ontology-item)
  (cdr ; skip "parents", and keep remaining items
   (car ; on ("parents" ...)
    (cdr ; skip ("url" . ...)
     (cdr ; skip ("ttip" . ...)
      (cdr ; skip ("frame-id" . ...)
       (cdr ; skip ("label" . ...)
            (cdr ; skip ("id" . ...)
                 (cdr ; skip "data" item
                      (car ; on ("data" ...) item
                           (cdr ; skip ("group" . "nodes")
                                ontology-item)))))))))))
                                        ; test: (get-parents-of-ontology-item (car (build-ontology-graph '|PWY-8089|))))
                                        ; expected: (|Sugars-And-Polysaccharides-Degradation|)

(defun get-ontology-graph-edges (ontology-graph)
  "Get all (u, v) edges from the ontology graph."
  (let ((edges-accumulator ()))
    (loop for item in ontology-graph
          for u = (get-id-of-ontology-item item)
          for parents = (get-parents-of-ontology-item item)
          do (when (listp parents)
               (loop for v in parents
                     do
                        (setq
                         edges-accumulator
                         (cons (cons u v) edges-accumulator)))))
    edges-accumulator))

(defun parse-ontology-graph (ontology-graph)
  "Parse the ONTOLOGY-GRAPH as a graph in hash-table format."
  (let ((graph (make-hash-table)))
    (loop for edge in (get-ontology-graph-edges ontology-graph)
          for u = (car edge)
          for v = (cdr edge)
          do (setf (gethash u graph) (cons v (gethash u graph))))
    graph))

(defun flatten-ontology-graph (ontology-graph root-node)
  "Retrieve a flattened list of levels in the ontology graph.

Uses breadth first search.

Returns list of list with:
(PATHWAY ONTOLOGY-DEPTH PATH-ENUMERATION PATHWAY-CLASS)
"
  (let ((flattened-list ())
        (graph (parse-ontology-graph ontology-graph))
        (depth 0)
        (path-enumeration 0)
        (current-node root-node)
        (queue (make-queue)))
    (multiprocessing:enqueue queue (list current-node depth path-enumeration)) ;; add the root-node to the queue
    (loop while (not (multiprocessing:queue-empty-p queue))
          for queue-item = (multiprocessing:dequeue queue)
          for graph-node = (nth 0 queue-item)
          for previous-depth = (nth 1 queue-item)
          for previous-path-enumeration = (nth 2 queue-item)
          for children = (gethash graph-node graph)
          for depth = (+ 1 previous-depth)
          for path-enumeration = (- previous-path-enumeration 1)
          do (loop for child in children
                   do (progn
                        (setq path-enumeration (+ 1 path-enumeration))
                        (setq flattened-list
                              (cons
                               (list root-node depth path-enumeration child) flattened-list))
                        (multiprocessing:enqueue queue (list child depth path-enumeration)))))
    flattened-list))

(defun output-graph-to-graphviz-dot (graph root)
  "Write a DOT language description of the ontology graph for GRAPH, starting from node ROOT.

Taking PWY0-1321 as ROOT is a good exemple of a not so simple ontology graph, (see https://metacyc.org/pathway?orgid=META&id=PWY0-1321#ONT)

Example:

(output-graph-to-graphviz-dot (parse-ontology-graph (build-ontology-graph 'PWY0-1321)) 'PWY0-1321)

Then with dot, to print an graph visualization as png:
$ dot -Tpng <PWY.dot> -o <PWY.png>
"
  (let ((queue (make-queue))
        (visited-hashset (make-hash-table))
        (dot-instructions ""))
    (multiprocessing:enqueue queue root)
    (loop while (not (multiprocessing:queue-empty-p queue))
          for node = (multiprocessing:dequeue queue)
          for children = (gethash node graph)
          do               (loop for child in children
                                 do (progn
                                      (multiple-value-bind (_ visited-p) (gethash child visited-hashset)
                                        (when (not visited-p)
                                          (multiprocessing:enqueue queue child)
                                          (setf (gethash child visited-hashset) t))
                                        (setq dot-instructions (concatenate 'string dot-instructions
                                                                            (format nil "\"~A\" -> \"~A\"~%"
                                                                                    node
                                                                                    child)))))))
    (concatenate 'string "digraph {" dot-instructions "}")))

;; (defun main ()
;;   (select-organism :org-id 'meta)
;;   (output-graph-to-graphviz-dot (parse-ontology-graph (build-ontology-graph 'PWY0-1321)) 'PWY0-1321))

;; (format t "~A" (main))
