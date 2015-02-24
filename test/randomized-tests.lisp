(in-package :check-it-test)

(in-root-suite)

(defsuite* randomized-tests)

(deftest test-generator ()
  (is (every #'identity
       (mapcar (lambda (x y) (subtypep (type-of x) y))
               (generate (generator (tuple (real) (integer) (list (integer)))))
               '(single-float integer
                 #-abcl (or cons null)
                 #+abcl t ;; ridiculous
                 )))))

;;;; Shrink results of generators

(deftest test-int-generate-shrink ()
  (let ((generator (generator (guard #'positive-integer-p (integer)))))
    (loop for i from 0 to 100
       do
         (is (= (shrink (generate generator) (constantly nil)) 0)))))

(deftest test-struct-generate-shrink ()
  (let ((generator (generator (struct a-struct
                                      #+(or abcl allegro) make-a-struct
                                      :a-slot (integer)
                                      :another-slot (integer))))
        (test-struct (make-a-struct :a-slot 0 :another-slot 0)))
    (loop for i from 1 to 10
       do
         (is (equalp (shrink (generate generator) (constantly nil))
                     test-struct)))))

;;;; Shrink generators themselves

(deftest test-tuple-generator-shrink ()
  (let ((generator (generator (tuple (integer) (integer) (integer)))))
    (loop for i from 1 to 10
       do
         (progn
           (generate generator)
           (is (equal (shrink generator (constantly nil))
                      (list 0 0 0))))))
  (let ((generator (generator (tuple
                               (guard #'greater-than-5 (integer))
                               (guard #'greater-than-5 (integer))
                               (guard #'greater-than-5 (integer))))))
    (loop for i from 1 to 10
       do
         (progn
           (generate generator)
           (is (every (lambda (x) (= (abs x) 6))
                      (shrink generator #'tuple-tester)))))))

(deftest test-list-generator-shrink ()
  (let ((generator (generator
                    (guard (lambda (l) (> (length l) 5))
                           (list
                            (guard #'greater-than-5
                                   (integer)))))))
    (loop for i from 1 to 10
         do
         (progn
           (generate generator)
           (shrink generator #'list-tester)
           (is (and (= (length (cached-value generator)) 6)
                    (every (lambda (x) (= (abs x) 6)) (cached-value generator))))))))

(deftest test-struct-generator-shrink ()
  (let ((generator (generator (struct a-struct
                                      #+(or abcl allegro) make-a-struct
                                      :a-slot (guard #'greater-than-5 (integer))
                                      :another-slot (guard #'greater-than-5 (integer))))))
    (loop for i from 1 to 10
       do
         (progn
           (generate generator)
           (shrink generator (lambda (x)
                               (or (< (abs (a-struct-a-slot x)) 5)
                                   (< (abs (a-struct-another-slot x)) 5))))
           (is (and (= (abs (a-struct-a-slot (cached-value generator))) 6)
                    (= (abs (a-struct-another-slot (cached-value generator))) 6)))))))