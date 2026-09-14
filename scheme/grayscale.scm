#lang swindle

(provide apply-grayscale)

;; Domain: A grayscale request and an image
;; Codomain: A processed region image

(define apply-grayscale
    (lambda (request image)
        (list
            (+ (- (car (cadr (cddddr request)))
                  (car (car (cddddr request))))
               1)
            (+ (- (cadr (cadr (cddddr request)))
                  (cadr (car (cddddr request))))
               1)
            (grayscale-rows
                (caddr image)
                0
                (cadr (car (cddddr request)))
                (cadr (cadr (cddddr request)))
                (car (car (cddddr request)))
                (car (cadr (cddddr request)))))))

;; Domain: Image rows, a row index and region limits
;; Codomain: Grayscale region rows

(define grayscale-rows
    (lambda (rows row top-row bottom-row left-column right-column)
        (cond
            ((> row bottom-row) '())
            ((< row top-row)
                (grayscale-rows
                    (cdr rows)
                    (+ row 1)
                    top-row
                    bottom-row
                    left-column
                    right-column))
            (else
                (cons
                    (grayscale-row
                        (car rows)
                        0
                        left-column
                        right-column)
                    (grayscale-rows
                        (cdr rows)
                        (+ row 1)
                        top-row
                        bottom-row
                        left-column
                        right-column))))))

;; Domain: RGB pixels, a column index and region limits
;; Codomain: A grayscale region row

(define grayscale-row
    (lambda (pixels column left-column right-column)
        (cond
            ((> column right-column) '())
            ((< column left-column)
                (grayscale-row
                    (cdr pixels)
                    (+ column 1)
                    left-column
                    right-column))
            (else
                (cons
                    (grayscale-pixel (car pixels))
                    (grayscale-row
                        (cdr pixels)
                        (+ column 1)
                        left-column
                        right-column))))))

;; Domain: An RGB pixel
;; Codomain: A grayscale RGB pixel

(define grayscale-pixel
    (lambda (pixel)
        (list
            (round
                (+ (* (car pixel) 0.299)
                   (* (cadr pixel) 0.587)
                   (* (caddr pixel) 0.114)))
            (round
                (+ (* (car pixel) 0.299)
                   (* (cadr pixel) 0.587)
                   (* (caddr pixel) 0.114)))
            (round
                (+ (* (car pixel) 0.299)
                   (* (cadr pixel) 0.587)
                   (* (caddr pixel) 0.114))))))
