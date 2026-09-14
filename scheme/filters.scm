#lang swindle

(require "gaussian_blur.scm"
    "grayscale.scm")

(provide apply-filter)

;; Domain: A valid request and an image
;; Codomain: A processed region image

(define apply-filter
    (lambda (request image)
        (cond
            ((eq? (car (cadddr request)) 'gaussian)
                (apply-gaussian request image))
            ((eq? (car (cadddr request)) 'grayscale)
                (apply-grayscale request image)))))
