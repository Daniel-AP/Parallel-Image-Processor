#lang swindle

(require "convolution.scm")

(provide apply-gaussian)

;; Domain: A Gaussian request and an image
;; Codomain: A processed region image

(define apply-gaussian
    (lambda (request image)
        (convolve-region
            image
            (gaussian-kernel
                (cadr (cadddr request))
                (caddr (cadddr request)))
            (car (cddddr request))
            (cadr (cddddr request)))))

;; Domain: An odd kernel size of at least 3
;; Codomain: A nonnegative integer

(define kernel-radius
    (lambda (kernel-size)
        (quotient (- kernel-size 1) 2)))

;; Domain: Horizontal offset, vertical offset and sigma
;; Codomain: A positive number

(define gaussian-weight
    (lambda (x y sigma)
        (exp
            (/
                (- (+ (* x x) (* y y)))
                (* 2 sigma sigma)))))

;; Domain: An odd kernel size and positive sigma
;; Codomain: A normalized kernel

(define gaussian-kernel
    (lambda (kernel-size sigma)
        (normalize-kernel
            (build-kernel-rows
                (- (kernel-radius kernel-size))
                (kernel-radius kernel-size)
                sigma)
            (kernel-sum
                (build-kernel-rows
                    (- (kernel-radius kernel-size))
                    (kernel-radius kernel-size)
                    sigma)))))

;; Domain: Vertical offset, radius and sigma
;; Codomain: Kernel rows

(define build-kernel-rows
    (lambda (y radius sigma)
        (cond
            ((> y radius) '())
            (else
                (cons
                    (build-kernel-row
                        (- radius)
                        y
                        radius
                        sigma)
                    (build-kernel-rows
                        (+ y 1)
                        radius
                        sigma))))))

;; Domain: Horizontal offset, vertical offset, radius and sigma
;; Codomain: A kernel row

(define build-kernel-row
    (lambda (x y radius sigma)
        (cond
            ((> x radius) '())
            (else
                (cons
                    (gaussian-weight x y sigma)
                    (build-kernel-row
                        (+ x 1)
                        y
                        radius
                        sigma))))))

;; Domain: A raw kernel
;; Codomain: A positive number

(define kernel-sum
    (lambda (kernel)
        (apply + (apply append kernel))))

;; Domain: A raw kernel and a positive total
;; Codomain: A normalized kernel

(define normalize-kernel
    (lambda (kernel total)
        (cond
            ((null? kernel) '())
            (else
                (cons
                    (normalize-row (car kernel) total)
                    (normalize-kernel (cdr kernel) total))))))

;; Domain: A kernel row and a positive total
;; Codomain: A normalized row

(define normalize-row
    (lambda (row total)
        (cond
            ((null? row) '())
            (else
                (cons
                    (/ (car row) total)
                    (normalize-row (cdr row) total))))))
