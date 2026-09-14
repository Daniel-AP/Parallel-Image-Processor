#lang swindle

(require "erlang_bridge.scm"
    "ppm.scm"
    "filters.scm")

;; Domain: No input
;; Codomain: No return

(define main
    (lambda ()
        (run-worker
            (parse-request
                (vector->list
                    (current-command-line-arguments))))))

;; Domain: A valid request
;; Codomain: No return

(define run-worker
    (lambda (request)
        (write-region
            (cadr request)
            (apply-filter
                request
                (read-region (car request))))
        (write-success (caddr request))))

(main)
