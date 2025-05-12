;; Work Verification Contract
;; Records completed maintenance activities

(define-data-var last-work-id uint u0)

(define-map work-records
  { work-id: uint }
  {
    request-id: uint,
    asset-id: uint,
    contractor: principal,
    description: (string-utf8 500),
    start-date: uint,
    completion-date: uint,
    cost: uint,
    verified: bool,
    verifier: (optional principal),
    verification-date: uint
  }
)

(define-map asset-work-records
  { asset-id: uint }
  { work-ids: (list 50 uint) }
)

(define-map request-work-records
  { request-id: uint }
  { work-id: (optional uint) }
)

(define-read-only (get-work-record (work-id uint))
  (map-get? work-records { work-id: work-id })
)

(define-read-only (get-asset-work-records (asset-id uint))
  (default-to { work-ids: (list) }
    (map-get? asset-work-records { asset-id: asset-id }))
)

(define-read-only (get-request-work-record (request-id uint))
  (default-to { work-id: none }
    (map-get? request-work-records { request-id: request-id }))
)

(define-public (record-work
                (request-id uint)
                (asset-id uint)
                (description (string-utf8 500))
                (start-date uint)
                (completion-date uint)
                (cost uint))
  (let (
    (new-id (+ (var-get last-work-id) u1))
    (asset-records (get-asset-work-records asset-id))
    (request-record (get-request-work-record request-id))
  )
    (begin
      ;; In a real implementation, we would check if the request exists and is assigned to this contractor
      ;; using contract-call? to the maintenance-request contract

      (asserts! (is-none (get work-id request-record)) (err u1)) ;; Work already recorded for this request
      (asserts! (<= start-date completion-date) (err u2)) ;; Invalid dates

      (var-set last-work-id new-id)
      (map-set work-records
        { work-id: new-id }
        {
          request-id: request-id,
          asset-id: asset-id,
          contractor: tx-sender,
          description: description,
          start-date: start-date,
          completion-date: completion-date,
          cost: cost,
          verified: false,
          verifier: none,
          verification-date: u0
        }
      )

      ;; Update the asset-work-records map
      (map-set asset-work-records
        { asset-id: asset-id }
        {
          work-ids: (unwrap-panic
            (as-max-len?
              (append (get work-ids asset-records) new-id)
              u50
            )
          )
        }
      )

      ;; Update the request-work-records map
      (map-set request-work-records
        { request-id: request-id }
        { work-id: (some new-id) }
      )

      (ok new-id)
    )
  )
)

(define-public (verify-work (work-id uint))
  (let ((work (map-get? work-records { work-id: work-id })))
    (begin
      (asserts! (is-some work) (err u404)) ;; Work not found
      (asserts! (not (get verified (unwrap-panic work))) (err u400)) ;; Already verified

      ;; In a real implementation, we would check if the verifier is authorized
      ;; This could be an admin or the asset owner

      (map-set work-records
        { work-id: work-id }
        (merge (unwrap-panic work)
          {
            verified: true,
            verifier: (some tx-sender),
            verification-date: block-height
          }
        )
      )

      ;; In a real implementation, we would also update the asset's last maintenance date
      ;; using contract-call? to the asset-registration contract

      (ok true)
    )
  )
)

(define-public (update-work-record
                (work-id uint)
                (description (string-utf8 500))
                (cost uint))
  (let ((work (map-get? work-records { work-id: work-id })))
    (begin
      (asserts! (is-some work) (err u404)) ;; Work not found
      (asserts! (is-eq tx-sender (get contractor (unwrap-panic work))) (err u403)) ;; Not authorized
      (asserts! (not (get verified (unwrap-panic work))) (err u400)) ;; Already verified

      (map-set work-records
        { work-id: work-id }
        (merge (unwrap-panic work)
          {
            description: description,
            cost: cost
          }
        )
      )
      (ok true)
    )
  )
)
