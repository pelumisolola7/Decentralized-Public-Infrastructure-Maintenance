;; Asset Registration Contract
;; Records details of public infrastructure assets

(define-data-var last-asset-id uint u0)

;; Asset types: 1=Road, 2=Bridge, 3=Park, 4=Building, 5=Utility
(define-map assets
  { asset-id: uint }
  {
    asset-type: uint,
    location: (string-utf8 100),
    installation-date: uint,
    last-maintenance: uint,
    status: uint, ;; 1=Good, 2=Fair, 3=Poor, 4=Critical
    owner: principal
  }
)

(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

(define-read-only (get-last-asset-id)
  (var-get last-asset-id)
)

(define-public (register-asset
                (asset-type uint)
                (location (string-utf8 100))
                (installation-date uint))
  (let ((new-id (+ (var-get last-asset-id) u1)))
    (begin
      (asserts! (and (>= asset-type u1) (<= asset-type u5)) (err u1)) ;; Valid asset type
      (var-set last-asset-id new-id)
      (map-set assets
        { asset-id: new-id }
        {
          asset-type: asset-type,
          location: location,
          installation-date: installation-date,
          last-maintenance: u0,
          status: u1, ;; Default to "Good"
          owner: tx-sender
        }
      )
      (ok new-id)
    )
  )
)

(define-public (update-asset-status (asset-id uint) (new-status uint))
  (let ((asset (map-get? assets { asset-id: asset-id })))
    (begin
      (asserts! (is-some asset) (err u404)) ;; Asset not found
      (asserts! (and (>= new-status u1) (<= new-status u4)) (err u2)) ;; Valid status
      (asserts! (is-eq tx-sender (get owner (unwrap-panic asset))) (err u403)) ;; Not authorized
      (map-set assets
        { asset-id: asset-id }
        (merge (unwrap-panic asset) { status: new-status })
      )
      (ok true)
    )
  )
)

(define-public (update-last-maintenance (asset-id uint) (maintenance-date uint))
  (let ((asset (map-get? assets { asset-id: asset-id })))
    (begin
      (asserts! (is-some asset) (err u404)) ;; Asset not found
      (asserts! (is-eq tx-sender (get owner (unwrap-panic asset))) (err u403)) ;; Not authorized
      (map-set assets
        { asset-id: asset-id }
        (merge (unwrap-panic asset) { last-maintenance: maintenance-date })
      )
      (ok true)
    )
  )
)
