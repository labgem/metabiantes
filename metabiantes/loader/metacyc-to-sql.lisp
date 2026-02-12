;; Lisp SQL dumper for MetaCyc database
;;
;; Dump the database into a SQL dump file
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

(load "flatten-ontology-graph")

;;
;; Generic SQL related functions
;;

(defun remove-double-suffix (text)
  "Remove 'd0' suffix from the string representation of a double precision float."
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
                                        ; ((listp value) (format nil "'~{~A~^ ~}'" value))
        ((symbolp value) (format-sql-literal (symbol-name value)))
        (t (format nil "'~A'" (escape-single-quote value)))))


(defun format-list-of-lines (lines)
  "Join a list of string with a line break."
  (format nil "~{~A~^~%~}~%" lines))

(defun format-sql-boolean (value)
  "Format a Lisp Boolean as a SQL Boolean."
  (if value
      "TRUE"
      "FALSE"
      ))


(defun create-index (table column)
  "Format a SQL instruction to create an index on a column."
  (format nil "CREATE UNIQUE INDEX IF NOT EXISTS idx_~A_~A ON ~A (~A);~%"
          table
          column
          table
          column))

(defun format-frame (frame)
  (cond ((stringp frame) frame)
        ((equal 'OCELOT-GFP::FRAME (type-of frame))
         (symbol-name (get-frame-name frame)))
        ((symbolp frame) (symbol-name frame))
        (t (progn
           (message "Error: format-frame type not handled")
           ()
           ))))

;;
;; Dump the MetaCyc database
;; 

;; First step: load all chemicals in a table

;; Chemicals is the parent class of Polypeptides, Compounds-And-Elements, and more
;; It is the class linked as substrate in a reaction.

(defun all-chemicals ()
  "List instances of class 'Chemicals' from Ocelot database."
  (get-class-all-instances '|Chemicals|))


(defun dump-substrates ()
  (format nil "INSERT INTO substrate (name) ~%VALUES ~A;~%"
          (format nil "~{('~A')~^,~% ~}" ;; join rows by (...),\n, as  
                  (loop for substrate in (all-substrates (all-rxns :all))
                        collect (format-frame substrate)))))


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


(defun all-polypeptides ()
  "List instances of class 'Proteins' from the Ocelot database."
  (get-class-all-instances '|Proteins|))


(defun dump-polypeptides ()
  "Format INSERT INTO instruction for all polypeptide."
  (format-list-of-lines
   (loop for polypeptide in (all-polypeptides)
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
  "Create one INSERT INTO instruction for a protein complex."
  (format nil "INSERT INTO polypeptide_complex_component (complex_id, component_id, coefficient)
VALUES ((SELECT id FROM polypeptide WHERE name = '~A'), (SELECT id FROM polypeptide WHERE name = '~A'), ~D);~%"
          complex-name
          component-name
          coefficient))


(defun complex-insertion (complex)
  "Create all INSERT INTO instruction for a protein complex COMPLEX."
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
  "Dump all complexes."
  (format-list-of-lines
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
  "Format the REACTION type (either \"small-molecule\" or \"transport\".)"
  (cond ((reaction-type? reaction :small-molecule) "small-molecule"
         (reaction-type? reaction :transport) "transport")))


(defun reaction-insertion (reaction)
  "Format an INSERT INTO instruction for a reaction REACTION."
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


(defun format-one-reaction-substrate-insertion (reaction substrate side)
  "Format an INSERT INTO instruction for the SUBSTRATE of a REACTION, on reaction side (LEFT or RIGHT)."
  (format nil "INSERT INTO reaction_substrate (reaction_id, substrate_id, reaction_side) VALUES
((SELECT id FROM reaction WHERE name = '~A'), (SELECT id FROM substrate WHERE name = '~A'), '~A');~%"
          (get-frame-name reaction)
          (format-frame substrate)
          side
          ))


(defun format-reaction-substrate-insertion (reaction direction)
  "Format an INSERT INTO instruction for "
  (let ((substrates (get-slot-value reaction direction)))
    (if (listp substrates)
        (format-list-of-lines
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
  "Format INSERT INTO instructions for all reaction substrate on left and right reaction sides." 
  (concatenate 'string
               (format-reaction-substrate-insertion reaction 'left)
               (format-reaction-substrate-insertion reaction 'right)))


(defun dump-reaction (reaction)
  "Dump a reaction."
  (concatenate 'string
               (reaction-insertion reaction)
               (reaction-substrate-insertion reaction)))


(defun dump-reactions ()
  "Dump all reactions."
  (concatenate 'string
               (format-list-of-lines
                (loop for reaction in (all-rxns :all)
                      collect (dump-reaction reaction)))))

;; Then, deal with the enzyme catalyzing the reactions

(defun format-enzyme-insertion (reaction enzyme)
  "Format an INSERT INTO instruction for an ENZYME catalyzing a REACTION."
  (format nil "INSERT INTO reaction_enzyme (reaction_id, enzyme_id)
VALUES ((SELECT id FROM reaction WHERE name = '~A'), (SELECT id FROM polypeptide WHERE name = '~A'));"
          (get-frame-name reaction)
          (get-frame-name enzyme)))


(defun dump-enzymes ()
  "Dump all enzymes."
  (format-list-of-lines
   (loop for reaction in (all-rxns :enzyme)
         collect
         (format-list-of-lines
          (loop for enzyme in (enzymes-of-reaction reaction)
                collect 
                (format-enzyme-insertion reaction enzyme))))))

;; Finally, deal with the pathways

; TODO
;(defun get-pathway-type (pathway)
;  (cond (())))

(defun format-pathway-insertion (pathway)
  "Format an INSERT INTO instruction for a pathway."
  (format nil "INSERT INTO pathway (name) VALUES ('~A');~%"
          (get-frame-name pathway)))

(defun format-pathway-variant (pathway variant)
  "Format an INSERT INTO for a VARIANT pathway of pathway PATHWAY."
  (insert-into-by-foreign-key "pathway_variant" "pathway" pathway "pathway_id" "pathway" variant "variant_id"))


(defun format-pathway-variants (pathway variants)
"Format all INSERT INTO for every VARIANTS of PATHWAY."
  (if (listp variants)
      (format nil "INSERT INTO pathway_variant (pathway_id, variant_id) VALUES ~% ~{~A~^,~%~};~%"
              (loop for variant in variants
                    collect (format nil "((SELECT id FROM pathway WHERE name = '~A'), (SELECT id FROM pathway WHERE name = '~A'))"
                                    (symbol-name (get-frame-name pathway))
                                    (symbol-name (get-frame-name variant)))))
      (format-pathway-variant pathway variants))) ; variants is a single string


(defun format-pathway-sub-pathway (pathway subpathway)
  "Format an INSERT INTO instruction for a SUBPATHWAY  of a PATHWAY"
  (insert-into-by-foreign-key
   "pathway_sub_pathway"
   "pathway"
   "super_pathway_id"
   (symbol-name (get-frame-name pathway))
   "pathway"
   "sub_pathway_id"
   (symbol-name (get-frame-name subpathway))
   ))


(defun format-pathway-sub-pathways (pathway sub-pathways)
  "Format all INSERT INTO instruction for SUB-PATHWAYS of a PATHWAY."
  (if (listp sub-pathways)
      (format nil "INSERT INTO pathway_sub_pathway (super_pathway_id, sub_pathway_id) VALUES ~% ~{~A~^,~%~};~%"
              (loop for sub-pathway in sub-pathways
                    collect (format nil "((SELECT id FROM pathway WHERE name = '~A'), (SELECT id FROM pathway WHERE name = '~A'))"
                                    (get-frame-name pathway)
                                    (get-frame-name sub-pathway))))
      (format-pathway-sub-pathway pathway sub-pathways))) ; sub-pathways is a single string

(defun extract-taxonomic-id-number (taxonomic-frame)
  "Extract the integer value of a taxonomic ID from a Tax-ID object TAXONOMIC-FRAME.
It will keep only frame with name starting by TAX-, expected to be a taxonomic Id of the NCBI-Taxonomy (not garanteed)."
  (let ((taxon (symbol-name (get-frame-name taxonomic-frame))))
    (if (excl:match-regexp "TAX-" taxon)
        (parse-integer
         (replace-regexp taxon
                    "TAX-"
                    ""))
        nil)))

(defun format-one-pathway-taxonomic-range-insertion (pathway tax-id)
  "Format an INSERT INTO instruction for a PATHWAY taxonomic range TAX-ID."
  (format nil "INSERT INTO pathway_taxonomic_range (pathway_id, taxon_id) VALUES
((SELECT id FROM pathway WHERE name = '~A'), ~D);~%"
          (get-frame-name pathway)
          (format-sql-literal (extract-taxonomic-id-number tax-id))))

(defun format-all-pathway-taxonomic-range-insertion (pathway)
  "Format all taxonomic ranges of PATHWAY."
  (let ((tax-id (get-slot-values pathway 'taxonomic-range)))
    (cond ((null tax-id) "")
          ((listp tax-id) 
           (format-list-of-lines (loop for id in tax-id
                                       collect (format-one-pathway-taxonomic-range-insertion pathway id))))
          (t (format-one-pathway-taxonomic-range-insertion pathway tax-id)))))


(defun format-one-pathway-species-insertion (pathway tax-id)
  "Format an INSERT INTO instruction for the species where a pathway has been described."
  (let ((id (extract-taxonomic-id-number tax-id)))
    (if (not (null id))
        (format nil "INSERT INTO pathway_species (pathway_id, species_id) VALUES
((SELECT id FROM pathway WHERE name = '~A'), ~D);~%"
                (get-frame-name pathway)
                (format-sql-literal id))
        ""
        )))

(defun format-all-pathway-species-insertion (pathway)
  "Format all species of PATHWAY."
  (let ((tax-id (get-slot-values pathway 'species)))
    (cond ((null tax-id) "")
          ((listp tax-id) 
           (format-list-of-lines (loop for id in tax-id
                                       collect (format-one-pathway-species-insertion pathway id))))
          (t (format-one-pathway-species-insertion pathway tax-id)))))

(defun format-one-pathway-key-reaction-insertion (pathway-name reaction-name)
  "Format an INSERT INTO instruction for a key reaction REACTION-NAME OF pathway PATHWAY-NAME."
  (insert-into-by-foreign-key
   "pathway_key_reaction"
   "pathway"
   "pathway_id"
   pathway-name
   "reaction"
   "reaction_id"
   reaction-name))


(defun format-all-pathway-key-reaction-insertion (pathway)
  "Format all INSERT INTO instructions for key reactions of a PATHWAY."
  (let ((key-reactions (get-slot-values pathway 'key-reactions)))
    (cond ((null key-reactions) "")
          ((listp key-reactions) (format-list-of-lines
                                  (loop for reaction in key-reactions
                                        collect (format-one-pathway-key-reaction-insertion
                                                 (format-frame pathway)
                                                 (format-frame reaction)))))
          (t (format-one-pathway-key-reaction-insertion
              (format-frame pathway)
              (format-frame key-reactions))))))


(defun any (list)
  "True if any item of the LIST is True."
  (if (null list)
      nil
      (if (listp list)
          (or (car list) (any (cdr list)))
          list)))

(defun all (list)
  "True if all item of the LIST is True, or the list is empty."
  (if (null list)
      t
      (if (listp list)
          (and (car list) (all (cdr list)))
          list)))

(defun is-reaction (frame)
  "Check if a FRAME is an instance of a subclass of Reactions or an instance of Reactions."
  (any (loop for super-class in (get-instance-all-types frame)
             for super-class-name = (get-frame-name super-class)
             collect (equal '|Reactions| super-class-name))))

(defun format-one-pathway-reaction-insertion (pathway reaction direction)
  "Format one INSERT INTO instruction for a REACTION of a PATHWAY."
  (if (is-reaction reaction)
      (format nil "INSERT INTO pathway_reaction (pathway_id, reaction_id, reaction_direction)
VALUES ((SELECT id FROM pathway WHERE name = '~A'), (SELECT id FROM reaction WHERE name = '~A'), '~A');"
              (get-frame-name pathway)
              (get-frame-name reaction)
              direction)
      "")) ; do not dump this reaction-pathway relation when reaction is not a member of reaction class

(defun format-pathway-reaction-direction (pathway reaction)
  ; TODO
  
  )

(defun format-pathway-reactions-insertion (pathway)
  "Format all pathway reactions insertion of PATHWAY."
  (let ((reactions (reactions-of-pathway pathway)))
    (cond ((null reactions) "")
          ((listp reactions) (format-list-of-lines
                              (loop for reaction in reactions
                                    collect (format-one-pathway-reaction-insertion
                                             pathway
                                             reaction
                                             (format-pathway-reaction-direction pathway reaction)))))
          (t
           (format-one-pathway-reaction-insertion pathway
                                                  reactions)))))

(defun dump-one-pathway (pathway)
  "Dump one pathway (pathway, key reactions, taxonomic-range, reactions)."
  (concatenate 'string
               (format-pathway-insertion pathway)
               (format-all-pathway-key-reaction-insertion pathway)
               (format-all-pathway-species-insertion pathway)
               (format-all-pathway-taxonomic-range-insertion pathway)
               (format-pathway-reactions-insertion pathway)
                                        ; TODO (format-pathway-graph pathway)
               ))


(defun format-pathway-ontology-insertion (pathway path depth pathway_class)
  "Format an INSERT INTO instruction for an item in the ontology of a PATHWAY."
  (format nil "INSERT INTO pathway_ontology (pathway_id, path, depth, pathway_class)
VALUES ((SELECT id FROM pathway WHERE name = ~A), ~A, ~A, ~A);"
          (format-sql-literal (format-frame pathway))
          (format-sql-literal path)
          (format-sql-literal depth)
          (format-sql-literal (format-frame pathway_class))))


(defun dump-pathway-ontology (pathway)
  "Dump a flattened ontology directed acyclic graph for the PATHWAY."
  (format-list-of-lines
   (loop for ontology-level-list in (flatten-ontology-graph (build-ontology-graph pathway)
                                                            (get-frame-name pathway))
         for pathway = (nth 0 ontology-level-list)
         for depth = (nth 1 ontology-level-list)
         for path-enumeration = (nth 2 ontology-level-list)
         for pathway_class = (nth 3 ontology-level-list)
         collect (format-pathway-ontology-insertion pathway path-enumeration depth pathway_class))))

(defun group-by-pathway-variant-groups (pathways)
  "Make a hashtable with group id to variants id for pathway variant groups."
  (let ((group-count 0)
        (variant-to-variant-group (make-hash-table))
        (variant-group-to-variants (make-hash-table)))
    (loop for pathway in pathways
          do (progn
               (multiple-value-bind
                     (variant-group variant-group-exists)
                   (gethash pathway variant-to-variant-group)
                 (when (not variant-group-exists)
                   (setq group-count (+ 1 group-count))
                   (setq variant-group group-count))
                 (loop for variant in (variants-of-pathway pathway)
                           do (progn
                                (setf (gethash variant variant-to-variant-group) variant-group) ; associate this variant to the variant-group
                                (setf (gethash variant-group variant-group-to-variants)
                                      (cons variant (gethash variant-group variant-group-to-variants))) ; append the variant to the variant group
                        ))
                     ))
              )
    variant-group-to-variants))

(defun format-pathway-variant-group (group-id variant-id)
  (format nil "INSERT INTO pathway_variant_group (variant_group_id, variant_id)
VALUES (~A, (SELECT id FROM pathway WHERE name = ~A));"
          (format-sql-literal group-id)
          (format-sql-literal (format-frame variant-id))))

(defun dump-variants-by-group (variant-group-to-variants)
  "Format INSERT INTO instructions from a hash-table with key group id and values list of variant pathway identifiers."
  (let ((instructions ()))
    (maphash #'(lambda (key value)
                 (loop for variant in value
                       do (setq instructions
                                (cons (format-pathway-variant-group key variant)
                                      instructions))))
             variant-group-to-variants)
    instructions))

(defun dump-pathways ()
  "Dump all pathways."
  (concatenate 'string
                                        ; First, dump all pathway names
               (format-list-of-lines
                (loop for pathway in (all-pathways)
                      collect (dump-one-pathway pathway)))
                                        ; Then, dump all pathway variants
               (format-list-of-lines
                (loop for pathway in (all-pathways)
                      for variants = (variants-of-pathway pathway)
                      when (not (null variants))
                        collect (format-pathway-variants pathway variants)))
                                        ; An alternative way of representing a pathway variant, as a pathway variant group
               (format-list-of-lines
                (dump-variants-by-group (group-by-pathway-variant-groups (all-pathways))))
                                        ; Continue with super-pathways
               (format-list-of-lines
                (loop for pathway in (all-pathways)
                      for sub-pathways = (get-slot-values pathway 'sub-pathways)
                      when (not (null sub-pathways))
                        collect (format-pathway-sub-pathways pathway sub-pathways)))
                                        ; Finally, dump all pathway flattened ontology dags
               (format-list-of-lines
                (loop for pathway in (all-pathways)
                     collect (dump-pathway-ontology pathway)))
               ))

(defun dump-all ()
  "Dump all MetaCyc database as SQL (according to the schema having effectively only a selected subset of the information)."
  (concatenate 'string
              (dump-substrates)
              (dump-compounds)
              (dump-polypeptides)
              (dump-complexes)
              (dump-reactions)
              (dump-enzymes)
              (dump-pathways)))

(defun write-to-file (file content)
  "Write a string CONTENT into a file with filename FILE."
  (with-open-file (stream file
                          :direction :output ;; write to disk
                          :if-exists :supersede ;; overwrite
                          :if-does-not-exist :create)
    (write-sequence content stream)))


(defun main ()
  (write-to-file "dump.sql" (dump-all)))


; (main)

