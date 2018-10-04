with import ./lisp.nix { a = null; }; eval
(defun fib (n)
  (defun fib2 (a b n)
    (iff (lt n 2) b
      (def (next (plus a b))
      (fib2 b next (minus n 1))))
  (fib2 0 1 n))
(fib 60))
