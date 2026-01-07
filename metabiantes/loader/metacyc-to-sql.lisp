;; Lisp loader for MetaCyc database
;;
;; Dump the database into a SQLite .sql dump file
;;
;; Usage: First, launch PathwayTools Lisp API
;; Then load this script with:
;; EC: (load "metacyc-to-sql.lisp")


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
  "Replace all \" with a antislash \" in TEXT."
  (replace-regexp text "\"" "\"\""))

(defun escape-single-quote (text)
  "Replace all \" with a antislash \" in TEXT."
  (replace-regexp text "'" "''"))

(defun format-sql-literal (value)
  "Return the value if any, else the literal value \"NULL\"."
  (cond ((null value) "NULL")
         ((numberp value) (remove-double-suffix (format nil "~D" value))) 
         ((stringp value) (format nil "'~A'" (escape-single-quote value)))
         ((listp value) (format nil "'~{~A~^ ~}'" value))
         (t (format nil "'~A'" value))))

;; First step: load all substrate compounds
(defun all-compounds ()
  (get-class-all-instances '|Compounds-And-Elements|))


(defun format-compound-column (compound)
  (format nil "('~A', ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A, ~A)"
          (get-frame-name compound) ; name
          "NULL" ; type TODO
          (format-sql-literal (get-slot-value compound 'comment)) ; comment
          (format-sql-literal (get-slot-value compound 'atomic-number)) ; atomic number
          (format-sql-literal (get-slot-value compound 'atom-charges)) ; atom charges
          (format-sql-literal (get-slot-value compound 'smiles)) ; SMILES
          (format-sql-literal (get-slot-value compound 'molecular-weight)) ; molecular weight
          (format-sql-literal (get-slot-value compound 'monoisotopic-mw)) ; monoisotopic mass
          (format-sql-literal  (get-slot-value compound 'gibbs-0))
          (format-sql-literal (get-slot-value compound 'pka2))           ; pKa
          ))

(defun dump-compounds ()
  (format nil "INSERT INTO compound (name, type, comment, atomic_number, atom_charges, smiles, molecular_weight, monoisotopic_mw, gibbs_free_energy, pka2) ~%VALUES ~A;~%"
          (format nil "~{~A~^,~% ~}" ;; join rows by (...),\n, as  
                  (loop for compound in (all-compounds)
                        collect (format-compound-column compound))
                        )))



(defun write-to-file (file content)
  (with-open-file (stream file
                          :direction :output ;; write to disk
                          :if-exists :supersede ;; overwrite
                          :if-does-not-exist :create)
    (write-sequence content stream)))

(defun main ()
  (write-to-file "dump.sql" (dump-compounds)))

(main)
