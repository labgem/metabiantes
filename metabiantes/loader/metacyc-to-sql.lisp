;; Lisp loader for MetaCyc database
;;
;; Dump the database into a SQLite .sql dump file
;;
;; Usage: First, launch PathwayTools Lisp API with
;; $ pathway-tools -lisp
;; Then load this script with:
;; EC: (load "metacyc-to-sql")
;;
;; Alternatively, run
;; $ pathway-tools -lisp -eval '(load "metacyc-to-sql")'

;; For some help on pathway-tools lisp API, refer to
;; https://www.pathwaytools.com/api/
;;

(in-package 'ecocyc)

(select-organism :org-id 'meta)

;;
;; Generic SQL related functions
;;

(defun remove-double-suffix (text)
  "Remove 'd0' suffix from the string representation of a double."
  (if (< (length text) 3)
      text
      (let* ((prefix (subseq text 0 (- (length text) 2)))
             (suffix (subseq text (- (length text) 2) (length text))))
        (if (equalp suffix "d0")
            prefix
            text))))


(defun escape-double-quote (text)
  "Replace all double quote with double double quote in TEXT."
                                        ; this is the way SQL escape quotes
  (replace-regexp text "\"" "\"\""))


(defun escape-single-quote (text)
  "Replace all single quote with double single quote in TEXT."
  (replace-regexp text "'" "''"))


(defun format-sql-literal (value)
  "Return the VALUE if any, else the literal value \"NULL\"."
  (cond ((null value) "NULL")
        ((equal 'OCELOT-GFP::FRAME (type-of value)) (format-sql-literal (symbol-name (get-frame-name value))))
        ((numberp value) (remove-double-suffix (format nil "~D" value))) 
        ((stringp value) (format nil "'~A'" (escape-single-quote value)))
        ((listp value) (format nil "'~{~A~^ ~}'" value))
        ((equal 'symbol (type-of value)) (format-sql-literal (symbol-name value)))
        (t (format nil "'~A'" (escape-single-quote value)))))


(defun format-sql-column-from-slot-on-frame (frame slots)
  (map '(vector * (length slots)) #'(lambda (slot) (get-slot-value frame slot)) slots))


(defun format-sql-boolean (value)
  (if value
      "TRUE"
      "FALSE"
      ))


(defun create-index (table column)
  (format nil "CREATE UNIQUE INDEX IF NOT EXISTS idx_~A_~A ON ~A (~A);~%"
          table
          column
          table
          column))


(defun format-frame (frame)
  (cond ((stringp frame) frame)
        ((equal 'OCELOT-GFP::FRAME (type-of frame))
         (symbol-name (get-frame-name frame)))
        (t (symbol-name frame))))

;;
;; Dump the MetaCyc database
;; 

;; First step: load all chemicals in a table

;; Chemicals is the parent class of Polypeptides, Compounds-And-Elements, and more
;; It is the class linked as substrate in a reaction.


(defun all-chemicals ()
  (get-class-all-instances '|Chemicals|))

(defun get-substrate-name (substrate)
  (format-frame substrate))


(defun dump-substrates ()
  (format nil "INSERT INTO substrate (name) ~%VALUES ~A;~%"
          (format nil "~{('~A')~^,~% ~}" ;; join rows by (...),\n, as  
                  (loop for substrate in (all-substrates (all-rxns :all))
                        collect (get-substrate-name substrate)))))


;; Also dump the chemical compounds and their attributes

(defun all-compounds ()
  (get-class-all-instances '|Compounds-And-Elements|))


(defun format-compound-column (compound)
  (format nil "('~A', ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A)"
          (symbol-name (get-frame-name compound)) ; name
          "NULL" ; type TODO
          (format-sql-literal (get-slot-value compound 'comment)) ; comment
          (format-sql-literal (get-slot-value compound 'atomic-number)) ; atomic number
          (format-sql-literal (if (listp (get-slot-value compound 'atom-charges))
                                  (car (get-slot-value compound 'atom-charges))
                                  nil)) ; atom charges
          (format-sql-literal (get-slot-value compound 'smiles)) ; SMILES
          (format-sql-literal (get-slot-value compound 'molecular-weight)) ; molecular weight
          (format-sql-literal (get-slot-value compound 'monoisotopic-mw)) ; monoisotopic mass
          (format-sql-literal  (get-slot-value compound 'gibbs-0))
          ))


(defun dump-compounds ()
  (format nil "INSERT INTO compound (name, type, comment, atomic_number, atom_charges, smiles, molecular_weight, monoisotopic_mw, gibbs_free_energy) ~%VALUES ~A;~%"
          (format nil "~{~A~^,~% ~}" ;; join rows by (...),\n, as  
                  (loop for compound in (all-compounds)
                        collect (format-compound-column compound))
                  )))


;; Second step is to load all reference monomer, complex and enzymes
;;
;; First, let's consider the polypeptide
;;


(defun format-polypeptide-type (polypeptide)
  "Return 'complex' if the polypeptide is a protein complex, otherwise, return 'monomer'."
  (if (complex-p polypeptide)
      "complex"
      "monomer"))


(defun format-polypeptide-insertion (polypeptide)
  "Format INSERT INTO instruction for a polypeptide."
  (format nil "INSERT INTO polypeptide (name, type, comment, experimental_molecular_weight, molecular_weight, molecular_weight_sequence, half_life, gene, neidhardt_spot_number, atom_charges, isoelectric_point) ~%VALUES ~% (~A);~%"
  ;(format nil "INSERT INTO polypeptide (name, type, comment, experimental_molecular_weight, molecular_weight, molecular_weight_sequence, half_life, gene, atom_charges, isoelectric_point) ~%VALUES ~% (~A);~%"
          (format nil "~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A"
                  (format-sql-literal (symbol-name (get-frame-name polypeptide)))
                  (format-sql-literal (format-polypeptide-type polypeptide))
                  (format-sql-literal (get-slot-value polypeptide 'comment))
                  (format-sql-literal (get-slot-value polypeptide 'experimental-molecular-weight-exp))
                  (format-sql-literal (get-slot-value polypeptide 'molecular-weight-exp))
                  (format-sql-literal (get-slot-value polypeptide 'molecular-weight))
                  (format-sql-literal (get-slot-value polypeptide 'half-life))
                  (format-sql-literal (get-slot-value polypeptide 'gene))
                  (format-sql-literal (if (listp (get-slot-value polypeptide 'neidhardt-spot-number))
                                          (car (get-slot-value polypeptide 'neidhardt-spot-number))
                                          nil))
                  (format-sql-literal (if (listp (get-slot-value polypeptide 'atom-charges))
                                          (car (get-slot-value polypeptide 'atom-charges))
                                          nil))
                  (format-sql-literal (get-slot-value polypeptide 'pi)))))


(defun all-polypeptide ()
  (get-class-all-instances '|Proteins|))


(defun dump-polypeptides ()
  "Format INSERT INTO instruction for all polypeptide."
  (format nil "~{~A~^~%~}"
          (loop for polypeptide in (all-polypeptide)
                collect (format-polypeptide-insertion polypeptide))))


(defun insert-into-by-foreign-key (table-name table-one key-one table-one-key-name table-two key-two table-two-key-name)
  "Create an INSERT INTO instruction for the insertion of a relation in table-name
   with simply the value ID1, ID2 where ID1 is the ID of the row with name TABLE-ONE-KEY-NAME in table TABLE-ONE, and similarly for ID2."
  (format nil "INSERT INTO ~A (~A, ~A) VALUES ~% ((SELECT id FROM ~A WHERE name = '~A'), (SELECT id FROM ~A WHERE name = '~A'));"
          table-name
          key-one
          key-two
          table-one
          table-one-key-name
          table-two
          table-two-key-name))


;; Deal with protein complexes
;;
;; (all-protein-complexes) returns the list of protein complexes

(defun format-complex-insertion (complex-name component-name coefficient)
  "Create one INSERT INTO instruction for a protein complex"
  (format nil "INSERT INTO polypeptide_complex_component (complex_id, component_id, coefficient)
VALUES ((SELECT id FROM polypeptide WHERE name = '~A'), (SELECT id FROM polypeptide WHERE name = '~A'), ~D);~%"
          complex-name
          component-name
          coefficient))


(defun complex-insertion (complex)
  "Create all INSERT INTO instruction for a protein complex"
  (multiple-value-bind (components coefficients) (components-of-protein complex 1)
    (format nil "~{~A~^~%~}"
            (loop for i from 0 to (- (length components) 2)
                  for component = (nth i components)
                  for coefficient = (nth i coefficients)
                  collect (format-complex-insertion
                           (get-frame-name complex)
                           (get-frame-name component)
                           coefficient)))))


(defun dump-complexes ()
  (format nil "~{~A~^~%~}"
          (loop for complex in (all-protein-complexes)
                collect (complex-insertion complex))))


;; Deal with reactions, enzyme and reaction substrate

(defun format-enzyme-reaction-relation (reaction enzyme)
  "Create an INSERT INTO instruction for a relation between an enzyme (Protein) and a reaction,
meaning: enzyme ENZYME catalyzes reaction REACTION"
  (format nil "INSERT INTO enzymatic_reaction (reaction_id, enzyme_id)
VALUES ((SELECT id FROM reaction WHERE name = '~A'), (SELECT id FROM polypeptide WHERE name = '~A'));~%"
          (get-frame-name reaction)
          (get-frame-name enzyme)))


(defun get-reaction-type (reaction)
  (cond ((reaction-type? reaction :small-molecule) "small-molecule"
         (reaction-type? reaction :transport) "transport")))



(defun reaction-insertion (reaction)
  (format nil "INSERT INTO reaction (name, type, comment, spontaneous, ec_number, gibbs_free_energy, physiologically_relevant, reaction_balance_status, reaction_physiological_direction)
VALUES ('~A', ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A);~%"
          (get-frame-name reaction)
          (format-sql-literal (get-reaction-type reaction))
          (format-sql-literal (get-slot-value reaction 'comment))
          (format-sql-boolean (get-slot-value reaction 'spontaneous?))
          (format-sql-literal (get-slot-value reaction 'ec-number))
          (format-sql-literal (get-slot-value reaction 'gibbs-0)) 
          (format-sql-boolean (get-slot-value reaction 'physiologically-relevant))
          (format-sql-boolean (get-slot-value reaction 'reaction-balance-status))
          (format-sql-literal (get-slot-value reaction 'reaction-physiological-direction))))


(defun format-one-reaction-substrate-insertion (reaction substrate direction)
  (format nil "INSERT INTO reaction_substrate (reaction_id, substrate_id, reaction_side) VALUES
((SELECT id FROM reaction WHERE name = '~A'), (SELECT id FROM substrate WHERE name = '~A'), '~A');~%"
          (get-frame-name reaction)
          (get-substrate-name substrate)
          direction
          ))


(defun format-reaction-substrate-insertion (reaction direction)
  (let ((substrates (get-slot-value reaction direction)))
    (if (listp substrates)
        (format nil "~{~A~^~}"
                (loop for substrate in substrates
                      collect (format-one-reaction-substrate-insertion
                               reaction
                               substrate
                               direction)))
        (format-one-reaction-substrate-insertion
         reaction
         substrates
         direction))))


(defun reaction-substrate-insertion (reaction)
  (concatenate 'string
               (format-reaction-substrate-insertion reaction 'left)
               (format-reaction-substrate-insertion reaction 'right)))


(defun dump-reaction (reaction)
  (concatenate 'string
               (reaction-insertion reaction)
               (reaction-substrate-insertion reaction)))


(defun dump-reactions ()
  (concatenate 'string
               (format nil "~{~A~}"
                       (loop for reaction in (all-rxns :all)
                             collect (dump-reaction reaction)))))

;; Then, deal with the enzyme catalyzing the reactions

(defun format-enzyme-insertion (reaction enzyme)
  (format nil "INSERT INTO reaction_enzyme (reaction_id, enzyme_id)
VALUES ((SELECT id FROM reaction WHERE name = '~A'), (SELECT id FROM polypeptide WHERE name = '~A'));"
          (get-frame-name reaction)
          (get-frame-name enzyme)))


(defun dump-enzymes ()
  (format nil "~{~A~^~%~}~%"
          (loop for reaction in (all-rxns :enzyme)
                collect
                (format nil "~{~A~^~%~}~%"
                        (loop for enzyme in (enzymes-of-reaction reaction)
                              collect 
                              (format-enzyme-insertion reaction enzyme))))))

;; Finally, deal with the pathways

(defun format-pathway-insertion (pathway)
  (format nil "INSERT INTO pathway (name) VALUES ('~A');"
          (get-frame-name pathway)))


(defun format-pathway-variant (pathway variant)
  (insert-into-by-foreign-key "pathway_variant" "pathway" pathway "pathway_id" "pathway" variant "variant_id"))


(defun format-pathway-variants (pathway variants)
  (if (listp variants)
      (format nil "INSERT INTO pathway_variant (pathway_id, variant_id) VALUES ~% ~{~A~^,~%~};~%"
              (loop for variant in variants
                    collect (format nil "((SELECT id FROM pathway WHERE name = '~A'), (SELECT id FROM pathway WHERE name = '~A'))"
                                    (symbol-name (get-frame-name pathway))
                                    (symbol-name (get-frame-name variant)))))
      (format-pathway-variant pathway variants))) ; variants is a single string

(defun format-pathway-sub-pathway (pathway variant)
  (insert-into-by-foreign-key
   "pathway_sub_pathway"
   "pathway"
   "super_pathway_id"
   (symbol-name (get-frame-name pathway))
   "pathway"
   "sub_pathway_id"
   (symbol-name (get-frame-name variant))
   ))


(defun format-pathway-sub-pathways (pathway sub-pathways)
  (if (listp sub-pathways)
      (format nil "INSERT INTO pathway_sub_pathway (super_pathway_id, sub_pathway_id) VALUES ~% ~{~A~^,~%~};~%"
              (loop for sub-pathway in sub-pathways
                    collect (format nil "((SELECT id FROM pathway WHERE name = '~A'), (SELECT id FROM pathway WHERE name = '~A'))"
                                    (get-frame-name pathway)
                                    (get-frame-name sub-pathway))))
      (format-pathway-sub-pathway pathway sub-pathways))) ; sub-pathways is a single string

(defun extract-taxonomic-id-number (taxonomic-range)
  (replace-regexp "TAX-" "" (symbol-name (get-frame-name taxonomic-range))))

(defun format-pathway-taxonomic-range-insertion (pathway)
  (let ((range (get-slot-value pathway 'taxonomic-range)))
    (if (not (null range))
        (format nil "INSERT INTO pathway_taxonomic_range (pathway_id, taxon_id) VALUES
((SELECT id FROM pathway WHERE name = '~A'), '~D');~%"
                (get-frame-name pathway)
                (extract-taxonomic-id-number range))
        "")))

(defun format-pathway-species-insertion (pathway)
  (format nil "INSERT INTO pathway_species (pathway_id, species_id)"))

(defun format-pathway-graph (pathway)
  "TODO"
  )

(defun format-one-pathway-key-reaction-insertion (pathway-name reaction-name)
  (insert-into-by-foreign-key
   "pathway_key_reaction"
   "pathway"
   "pathway_id"
   pathway-name
   "reaction"
   "reaction_id"
   reaction-name))


(defun format-pathway-key-reaction-insertion (pathway)
  (let ((key-reactions (get-slot-value pathway 'key-reactions)))
    (cond ((null key-reactions) "")
          ((listp key-reactions) (format nil "~{~A~}"
                                        (loop for reaction in key-reactions
                                              collect (format-one-pathway-key-reaction-insertion (format-frame pathway) (format-frame reaction)))))
          (t (format-one-pathway-key-reaction-insertion (format-frame pathway) (format-frame key-reactions))))))


(defun format-one-pathway-reaction-insertion (pathway-name reaction-name)
  (insert-into-by-foreign-key
   "pathway_reaction"
   "pathway"
   "pathway_id"
   pathway-name
   "reaction"
   "reaction_id"
   reaction-name))


(defun format-pathway-reactions-insertion (pathway)
  (let ((reactions (get-slot-value pathway 'reactions))
        (cond ((null reactions) "")
              ((listp reactions) (format nil "~{~A~}"
                                         (loop for reaction in reactions
                                               collect (format-one-pathway-reaction-insertion pathway reaction))))
              (t (format-one-pathway-reaction-insertion pathway reactions))))))


(defun dump-pathway (pathway)
  (concatenate 'string
               (format-pathway-insertion pathway)
               (format-pathway-key-reaction-insertion pathway)
                                        ; (format-pathway-species-insertion pathway)
               ;;(format-pathway-taxonomic-range-insertion pathway)
               ;;(format-pathway-reactions-insertion pathway)
               ;; TODO (format-pathway-graph pathway)
               ))


(defun dump-pathways ()
  (concatenate 'string
                                        ; First, dump all pathway names
               (format nil "~{~A~^~%~}~%"
                       (loop for pathway in (all-pathways)
                             collect (dump-pathway pathway)))
                                        ; Then, dump all pathway variants
               (format nil "~{~A~^~%~}~%"
                       (loop for pathway in (all-pathways)
                             for variants = (variants-of-pathway pathway)
                             when (not (null variants))
                               collect (format-pathway-variants pathway variants)))
                                        ; Continue with super-pathways
               (format nil "~{~A~^~%~}~%"
                       (loop for pathway in (all-pathways)
                             for sub-pathways = (get-slot-value pathway 'sub-pathways)
                             when (not (null sub-pathways))
                               collect (format-pathway-sub-pathways pathway sub-pathways)))
               ))

(defun dump-all ()
  (concatenate 'string
               (dump-substrates)
               (dump-compounds)
               (dump-polypeptides)
               (dump-complexes)
               (dump-reactions)
             ;  (dump-enzymes)
             ;  (dump-pathways)
              ))

(defun write-to-file (file content)
  (with-open-file (stream file
                          :direction :output ;; write to disk
                          :if-exists :supersede ;; overwrite
                          :if-does-not-exist :create)
    (write-sequence content stream)))


(defun main ()
 (write-to-file "dump.sql" (dump-all)))


(main)
