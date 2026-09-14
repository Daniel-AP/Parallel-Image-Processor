#lang swindle

(require racket/file
    racket/string)

(provide read-region
    write-region)

;; Domain: A PPM file path
;; Codomain: An image

(define read-region
    (lambda (path)
        (parse-tokens
            (string-split (file->string path)))))

;; Domain: A PPM file path and an image
;; Codomain: No return

(define write-region
    (lambda (path image)
        (call-with-output-file
            path
            (lambda (output)
                (display
                    (string-append
                        "P3\n"
                        (number->string (car image))
                        " "
                        (number->string (cadr image))
                        "\n255\n"
                        (string-join
                            (map pixel-to-text (apply append (caddr image)))
                            "\n")
                        "\n")
                    output)))))

;; Domain: Valid PPM tokens
;; Codomain: An image

(define parse-tokens
    (lambda (tokens)
        (list
            (string->number (cadr tokens))
            (string->number (caddr tokens))
            (group-rows
                (group-pixels
                    (map string->number (cddddr tokens)))
                (string->number (cadr tokens))))))

;; Domain: Valid RGB components
;; Codomain: Pixels

(define group-pixels
    (lambda (components)
        (cond
            ((null? components) '())
            (else
                (cons
                    (list
                        (car components)
                        (cadr components)
                        (caddr components))
                    (group-pixels (cdddr components)))))))

;; Domain: Pixels and a row width
;; Codomain: Rows

(define group-rows
    (lambda (pixels width)
        (cond
            ((null? pixels) '())
            (else
                (cons
                    (take-row pixels width)
                    (group-rows
                        (skip-row pixels width)
                        width))))))

;; Domain: Pixels and a row width
;; Codomain: The first row of pixels

(define take-row
    (lambda (pixels width)
        (cond
            ((zero? width) '())
            (else
                (cons
                    (car pixels)
                    (take-row
                        (cdr pixels)
                        (- width 1)))))))

;; Domain: Pixels and a row width
;; Codomain: The pixels after the first row

(define skip-row
    (lambda (pixels width)
        (cond
            ((zero? width) pixels)
            (else
                (skip-row
                    (cdr pixels)
                    (- width 1))))))

;; Domain: An RGB pixel
;; Codomain: PPM pixel content

(define pixel-to-text
    (lambda (pixel)
        (string-append
            (number->string (inexact->exact (car pixel)))
            " "
            (number->string (inexact->exact (cadr pixel)))
            " "
            (number->string (inexact->exact (caddr pixel))))))
