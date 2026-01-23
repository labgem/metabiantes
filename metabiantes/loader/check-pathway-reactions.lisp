
(load "metacyc-to-sql")

(defun count-if-reaction (reaction-list)
  (count-if #'is-reaction reaction-list))

(defun count-reaction-in-reaction-list (pathway)
  (let ((reaction-list (get-slot-value pathway 'reaction-list)))
    (cond ((listp reaction-list) (count-if-reaction reaction-list))
          ((null reaction-list) 0)
          (t (if (is-reaction reaction-list)
                 1
                 0)))))

(defun sum (list)
  (cond ((null list) 0)
        ((listp list) (+ (car list) (sum (cdr list))))))

(defun count-pathway-reaction (pathways)
  (sum (map 'list #'count-reaction-in-reaction-list pathways)))

(defun main ()
  (format t "~D" (count-pathway-reaction (all-pathways))))

(main)
