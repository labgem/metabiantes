;; Lisp loader for MetaCyc database
;;
;; Dump the database into a SQLite .sql dump file
;;
;; Usage: First, launch PathwayTools Lisp API
;; Then load this script with:
;; EC: (load "metacyc-to-sql")

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
  (map '(vector * (length slots)) #'(lambda (slot) (get-slot-value frame slot))))

;; First step: load all substrate compounds
(defun all-compounds ()
  (get-class-all-instances '|Compounds-And-Elements|))

(defun format-compound-column (compound)
  (format nil "('~A', ~A, ~A)"
          (get-frame-name compound) ; name
          "NULL" ; type TODO
          ;; (format-sql-literal (get-slot-value compound 'comment)) ; comment
          ;; (format-sql-literal (get-slot-value compound 'atomic-number)) ; atomic number
          ;; (format-sql-literal (get-slot-value compound 'atom-charges)) ; atom charges
          ;; (format-sql-literal (get-slot-value compound 'smiles)) ; SMILES
          ;; (format-sql-literal (get-slot-value compound 'molecular-weight)) ; molecular weight
          ;; (format-sql-literal (get-slot-value compound 'monoisotopic-mw)) ; monoisotopic mass
          ;; (format-sql-literal  (get-slot-value compound 'gibbs-0))
          ;;        (format-sql-literal (get-slot-value compound 'pka2))           ; pKa
          (format-sql-column-from-slot-on-frame compound '(
                                                           comment
                                                           atomic-number
                                                           atom-charges
                                                           slimes
                                                           molecular-weight
                                                           monoisotopic-mw
                                                           gibbs-0
                                                           pka2))))


(defun dump-compounds ()
  (format nil "INSERT INTO compound (name, type, comment, atomic_number, atom_charges, smiles, molecular_weight, monoisotopic_mw, gibbs_free_energy, pka2) ~%VALUES ~A;~%"
          (format nil "~{~A~^,~% ~}" ;; join rows by (...),\n, as  
                  (loop for compound in (all-compounds)
                        collect (format-compound-column compound))
                  )))


;; Second step is to load all reference monomer, complex and enzymes
;;
;; First, let's consider the polypeptide

(defun format-polypeptide-type (polypeptide)
  "Return 'complex' if the polypeptide is a protein complex, otherwise, return 'monomer'."
  (if (is-complex-polypeptide polypeptide))

  
  (defun polypeptide-insertion (polypeptide)
    (format nil "INSERT INTO polypeptide (name, type, comment, experimental_molecular_weight, molecular_weight, molecular_weight_sequence, half_life, gene, neidhardt_spot_number, atom_charges, isoelectric_point) ~%VALUES ~% (~A);~%"
            (format nil "'~A', ~A, ~A"
                    (get-frame-name polypeptide)
                    (format-polypeptide-type polypeptide)
                    (format-sql-column-from-slot-on-frame
                     polypeptide
                     '(comment molecular-weight-exp molecular-weight half-life gene neidhardt-spot-number atom-charges pi)))))


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

  
  (defun dump-one-reaction (reaction)
    (format nil "INSERT INTO reaction (name, type, comment, )")
    )

  ;; Deal with protein complexes

  (defun complex-component (complex)
    (get-slot-value value ))

  (defun complex-insertion (complex)
    "Create a INSERT INTO instruction for a protein complex"
    (format nil "INSERT INTO complex_component ()")

    (defun write-to-file (file content)
      (with-open-file (stream file
                              :direction :output ;; write to disk
                              :if-exists :supersede ;; overwrite
                              :if-does-not-exist :create)
        (write-sequence content stream)))


    (defun main ()
      (write-to-file "dump.sql" (dump-compounds)))
 
    (main)
