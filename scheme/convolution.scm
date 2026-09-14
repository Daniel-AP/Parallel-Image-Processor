#lang swindle

(provide convolve-region)

;; Domain: An image, a kernel and two region corners
;; Codomain: The processed region image

(define convolve-region
    (lambda (image kernel region-top-left region-bottom-right)
        (list
            (+ (- (car region-bottom-right) (car region-top-left)) 1)
            (+ (- (cadr region-bottom-right) (cadr region-top-left)) 1)
            (convolve-rows
                image
                kernel
                (car region-top-left)
                (car region-bottom-right)
                (cadr region-top-left)
                (cadr region-bottom-right)))))

;; Domain: An image, a kernel and region row limits
;; Codomain: Processed region rows

(define convolve-rows
    (lambda (image kernel left-column right-column row bottom-row)
        (cond
            ((> row bottom-row) '())
            (else
                (cons
                    (convolve-row
                        image
                        kernel
                        row
                        left-column
                        right-column)
                    (convolve-rows
                        image
                        kernel
                        left-column
                        right-column
                        (+ row 1)
                        bottom-row))))))

;; Domain: An image, a kernel and row column limits
;; Codomain: A processed row

(define convolve-row
    (lambda (image kernel row column right-column)
        (cond
            ((> column right-column) '())
            (else
                (cons
                    (convolve-pixel image kernel row column)
                    (convolve-row
                        image
                        kernel
                        row
                        (+ column 1)
                        right-column))))))

;; Domain: An image, a kernel and pixel coordinates
;; Codomain: A processed RGB pixel

(define convolve-pixel
    (lambda (image kernel row column)
        (clamp-pixel
            (convolve-kernel-rows
                image
                kernel
                row
                column
                (- (quotient (length kernel) 2))
                (quotient (length kernel) 2)
                '(0 0 0)))))

;; Domain: An image, kernel rows and an RGB accumulator
;; Codomain: A weighted RGB sum

(define convolve-kernel-rows
    (lambda (image kernel row column dy radius accumulator)
        (cond
            ((null? kernel) accumulator)
            (else
                (convolve-kernel-rows
                    image
                    (cdr kernel)
                    row
                    column
                    (+ dy 1)
                    radius
                    (convolve-kernel-row
                        image
                        (car kernel)
                        row
                        column
                        dy
                        (- radius)
                        radius
                        accumulator))))))

;; Domain: An image, a kernel row and an RGB accumulator
;; Codomain: A weighted RGB sum

(define convolve-kernel-row
    (lambda (image kernel-row row column dy dx radius accumulator)
        (cond
            ((null? kernel-row) accumulator)
            (else
                (convolve-kernel-row
                    image
                    (cdr kernel-row)
                    row
                    column
                    dy
                    (+ dx 1)
                    radius
                    (add-pixels
                        accumulator
                        (scale-pixel
                            (safe-pixel-at
                                image
                                (+ row dy)
                                (+ column dx))
                            (car kernel-row))))))))

;; Domain: An image and pixel coordinates
;; Codomain: An RGB pixel

(define safe-pixel-at
    (lambda (image row column)
        (list-ref
            (list-ref
                (caddr image)
                (min (max row 0) (- (cadr image) 1)))
            (min (max column 0) (- (car image) 1)))))

;; Domain: An RGB pixel and a kernel weight
;; Codomain: A weighted RGB pixel

(define scale-pixel
    (lambda (pixel weight)
        (list
            (* (car pixel) weight)
            (* (cadr pixel) weight)
            (* (caddr pixel) weight))))

;; Domain: Two numeric RGB pixels
;; Codomain: Their component sum

(define add-pixels
    (lambda (left right)
        (list
            (+ (car left) (car right))
            (+ (cadr left) (cadr right))
            (+ (caddr left) (caddr right)))))

;; Domain: A numeric RGB pixel
;; Codomain: An integer RGB pixel

(define clamp-pixel
    (lambda (pixel)
        (list
            (clamp-component (car pixel))
            (clamp-component (cadr pixel))
            (clamp-component (caddr pixel)))))

;; Domain: A numeric component
;; Codomain: An integer from 0 to 255

(define clamp-component
    (lambda (component)
        (min 255 (max 0 (round component)))))
