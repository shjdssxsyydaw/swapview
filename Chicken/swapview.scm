(use srfi-1 srfi-13 data-structures utils posix)

(include "format/format.scm")
(import format)

(define-syntax while
  (syntax-rules ()
    ((while test body ...)
     (let loop ()
       (when test
         body ...
         (loop))))))

(define (filesize size)
  (let lp ((units '(B KiB MiB GiB TiB))
           (size size))
    (if (and (> size 1100) (not (null? units)))
        (lp (cdr units) (/ size 1024))
        (if (eq? (car units) 'B)
            (conc size "B")
            (format #f "~,1f~a" size (car units))))))

(define (getSwapFor pid)
  (condition-case
      (let* ((port (open-input-file (format #f "/proc/~a/cmdline" pid)))
             (rawcomm (string-map (lambda (x) (if (char=? x #\nul) #\space x))
                                  (read-all port)))
             (comm (if (> (string-length rawcomm) 0)
                       (substring rawcomm 0 (- (string-length rawcomm) 1))
                       ""))
             (smaps (open-input-file (format #f "/proc/~a/smaps" pid)))
             (s 0.0))
        (let ((line (read-line smaps)))
          (while (not (eof-object? line))
            (if (string=? (substring line 0 5) "Swap:")
                (set! s (+ s (string->number (cadr (reverse (string-split line )))))))
            (set! line (read-line smaps))))
        (list pid (* 1024 s) comm))
    ((exn file) (list pid 0 ""))))

(define (getSwap)
  (sort
   (filter (lambda (x) (> (list-ref x 1) 0))
           (map (lambda (x) (getSwapFor (string->number x)))
                (filter (lambda (x) (string->number x))
                        (directory "/proc"))))
   (lambda (a b) (< (list-ref a 1) (list-ref b 1)))))

(define (main)
  (let* ((results (getSwap))
         (FORMATSTR "~5@a ~9@a ~@a~%")
         (total 0))
    (format #t FORMATSTR "PID" "SWAP" "COMMAND")
    (map
     (lambda (item)
       (set! total (+ total (list-ref item 1)))
       (format #t FORMATSTR
               (list-ref item 0)
               (filesize (list-ref item 1))
               (list-ref item 2)))
     results)
    (format #t "Total: ~8@a~%" (filesize total))))

(main)
