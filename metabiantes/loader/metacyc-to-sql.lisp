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


(in-package 'ecocyc)

(select-organism :org-id 'meta)

(defun remove-double-suffix (text)
  "Remove 'd0' suffix from the string representation of a double"
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
  "Return the value if any, else the literal value \"NULL\"."
  (cond ((null value) "NULL")
        ((numberp value) (remove-double-suffix (format nil "~D" value))) 
        ((stringp value) (format nil "'~A'" (escape-single-quote value)))
        ((listp value) (format nil "'~{~A~^ ~}'" value))
        (t (format nil "'~A'" (escape-single-quote value)))))


(defun format-sql-literals (values)
  (format nil "~{~A,^,}" (map '(vector * (length values)) #'format-sql-literal values)))


(defun format-sql-column-from-slot-on-frame (frame slots)
  (map '(vector * (length slots)) #'(lambda (slot) (get-slot-value frame slot)) slots))


(defun format-sql-boolean (value)
  (if value
      "TRUE"
      "FALSE"
      ))

;; First step: load all substrate chemicals

(defun all-chemicals ()
  (get-class-all-instances '|Chemicals|))


(defun format-chemical-column (chemical)
  (format nil "('~A', ~A, ~A)"
          (symbol-name (get-frame-name chemical)) ; name
          "NULL" ; type TODO
          (format-sql-literal (get-slot-value chemical 'comment)) ; comment
    ))


(defun dump-chemicals ()
  (format nil "INSERT INTO chemical (name, type, comment) ~%VALUES ~A;~%"
          (format nil "~{~A~^,~% ~}" ;; join rows by (...),\n, as  
                  (loop for chemical in (all-chemicals)
                        collect (format-chemical-column chemical))
                  )))


;; Also dump the chemical compounds (this however, might be completely useless)

(defun all-compounds ()
  (get-class-all-instances '|Compounds-And-Elements|))


(defun format-compound-column (compound)
  (format nil "('~A', ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A)"
          (symbol-name (get-frame-name compound)) ; name
          "NULL" ; type TODO
          (format-sql-literal (get-slot-value compound 'comment)) ; comment
          (format-sql-literal (get-slot-value compound 'atomic-number)) ; atomic number
          (format-sql-literal (get-slot-value compound 'atom-charges)) ; atom charges
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


(defun format-polypeptide-type (polypeptide)
  "Return 'complex' if the polypeptide is a protein complex, otherwise, return 'monomer'."
  (if (complex-p polypeptide)
      "complex"
      "monomer"))


(defun format-polypeptide-insertion (polypeptide)
  "Format INSERT INTO instruction for a polypeptide."
  (format nil "INSERT INTO polypeptide (name, type, comment, experimental_molecular_weight, molecular_weight, molecular_weight_sequence, half_life, gene, neidhardt_spot_number, atom_charges, isoelectric_point) ~%VALUES ~% (~A);~%"
          (format nil "~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A"
                  (format-sql-literal (symbol-name (get-frame-name polypeptide)))
                  (format-sql-literal (format-polypeptide-type polypeptide))
                  (format-sql-literal (get-slot-value polypeptide 'comment))
                  (format-sql-literal (get-slot-value polypeptide 'experimental-molecular-weight-exp))
                  (format-sql-literal (get-slot-value polypeptide 'molecular-weight-exp))
                  (format-sql-literal (get-slot-value polypeptide 'molecular-weight))
                  (format-sql-literal (get-slot-value polypeptide 'half-life))
                  (format-sql-literal (symbol-name (get-frame-name (get-slot-value polypeptide 'gene))))
                  (format-sql-literal (get-slot-value polypeptide 'neidhardt-spot-number))
                  (format-sql-literal (get-slot-value polypeptide 'atom-charges))
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
  (format nil "INSERT INTO ~A (~A, ~A) values ~% ((SELECT id FROM ~A WHERE name = '~A'), (SELECT id FROM ~A WHERE name = '~A'));"
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
  (format nil "INSERT INTO reaction (name, type, comment, gibbs_free_energy, physiologically_relevant, reaction_balance_status, reaction_physiological_direction)
VALUES ('~A', ~A, ~A, ~A, ~A, ~A, ~A);~%"
          (get-frame-name reaction)
          (format-sql-literal (get-reaction-type reaction))
          (format-sql-literal (get-slot-value reaction 'comment))
          (format-sql-literal (symbol-name (get-slot-value reaction 'ec-number)))
          (format-sql-literal (get-slot-value reaction 'gibbs-0)) 
          (format-sql-boolean (get-slot-value reaction 'physiologically-relevant))
          (format-sql-boolean (get-slot-value reaction 'reaction-balance-status))
          (format-sql-literal (get-slot-value reaction 'reaction-physiological-direction))))


(defun format-one-reaction-substrate-insertion (reaction substrate direction)
  (format nil "INSERT INTO reaction_substrate (reaction_id, substrate_id, reaction_side) VALUES
((SELECT id FROM reaction WHERE name = '~A'), (SELECT id FROM chemical WHERE name = '~A'), '~A');~%"
          (symbol-name (get-frame-name reaction))
          (symbol-name (get-frame-name substrate))
          direction
          ;; TODO: I did not take into account any stoechiometric coefficient
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
  (format nil "INSERT INTO pathway (name) VALUES ('~A')"
          (get-frame-name pathway)))

(defun format-variant-insertion (pathway)
  (if ))

(defun dump-pathway (pathway)
  (format-pathway-insertion (pathway)))

(defun dump-all ()
  (concatenate 'string
            (dump-chemicals)
            (dump-compounds)
            (dump-polypeptides)
            (dump-complexes)
            (dump-reactions)
            (dump-enzymes)
            ;(dump-pathways)
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
