;; Contractor Verification Contract
;; Validates qualified service providers

(define-map contractors
  { contractor: principal }
  {
    name: (string-utf8 100),
    specialties: (list 5 uint), ;; 1=Roads, 2=Bridges, 3=Parks, 4=Buildings, 5=Utilities
    license-number: (string-utf8 50),
    verified: bool,
    rating: uint, ;; 0-100
    verification-expiry: uint
  }
)

;; Admins who can verify contractors
(define-map admins
  { admin: principal }
  { active: bool }
)

;; Initialize contract admin
(define-data-var contract-owner principal tx-sender)

(define-read-only (get-contractor (contractor principal))
  (map-get? contractors { contractor: contractor })
)

(define-read-only (is-admin (address principal))
  (default-to false (get active (map-get? admins { admin: address })))
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-public (register-contractor
                (name (string-utf8 100))
                (specialties (list 5 uint))
                (license-number (string-utf8 50)))
  (begin
    ;; Validate specialties
    (asserts! (fold check-specialty-valid specialties true) (err u1))

    (map-set contractors
      { contractor: tx-sender }
      {
        name: name,
        specialties: specialties,
        license-number: license-number,
        verified: false,
        rating: u0,
        verification-expiry: u0
      }
    )
    (ok true)
  )
)

(define-private (check-specialty-valid (specialty uint) (valid bool))
  (and valid (and (>= specialty u1) (<= specialty u5)))
)

(define-public (verify-contractor
                (contractor principal)
                (expiry-block uint))
  (let ((contractor-data (map-get? contractors { contractor: contractor })))
    (begin
      (asserts! (is-admin tx-sender) (err u403)) ;; Not an admin
      (asserts! (is-some contractor-data) (err u404)) ;; Contractor not found
      (asserts! (> expiry-block block-height) (err u2)) ;; Invalid expiry

      (map-set contractors
        { contractor: contractor }
        (merge (unwrap-panic contractor-data)
          {
            verified: true,
            verification-expiry: expiry-block
          }
        )
      )
      (ok true)
    )
  )
)

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403)) ;; Not contract owner
    (map-set admins { admin: new-admin } { active: true })
    (ok true)
  )
)

(define-public (remove-admin (admin-to-remove principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403)) ;; Not contract owner
    (map-delete admins { admin: admin-to-remove })
    (ok true)
  )
)

(define-public (update-contractor-rating
                (contractor principal)
                (new-rating uint))
  (let ((contractor-data (map-get? contractors { contractor: contractor })))
    (begin
      (asserts! (is-admin tx-sender) (err u403)) ;; Not an admin
      (asserts! (is-some contractor-data) (err u404)) ;; Contractor not found
      (asserts! (<= new-rating u100) (err u2)) ;; Rating must be 0-100

      (map-set contractors
        { contractor: contractor }
        (merge (unwrap-panic contractor-data) { rating: new-rating })
      )
      (ok true)
    )
  )
)
