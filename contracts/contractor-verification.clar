;; Inspection Scheduling Contract
;; Manages regular condition assessments

(define-data-var last-inspection-id uint u0)

(define-map inspections
  { inspection-id: uint }
  {
    asset-id: uint,
    scheduled-date: uint,
    inspector: principal,
    status: uint, ;; 1=Scheduled, 2=Completed, 3=Cancelled
    findings: (string-utf8 500),
    completion-date: uint
  }
)

(define-map asset-inspections
  { asset-id: uint }
  { inspection-ids: (list 20 uint) }
)

(define-read-only (get-inspection (inspection-id uint))
  (map-get? inspections { inspection-id: inspection-id })
)

(define-read-only (get-asset-inspections (asset-id uint))
  (default-to { inspection-ids: (list) }
    (map-get? asset-inspections { asset-id: asset-id }))
)

(define-public (schedule-inspection (asset-id uint) (scheduled-date uint))
  (let (
    (new-id (+ (var-get last-inspection-id) u1))
    (asset-inspections-data (get-asset-inspections asset-id))
  )
    (begin
      ;; Check if asset exists by calling the asset registration contract
      ;; In a real implementation, we would use contract-call? to the asset-registration contract

      (var-set last-inspection-id new-id)
      (map-set inspections
        { inspection-id: new-id }
        {
          asset-id: asset-id,
          scheduled-date: scheduled-date,
          inspector: tx-sender,
          status: u1, ;; Scheduled
          findings: u"",
          completion-date: u0
        }
      )

      ;; Update the asset-inspections map
      (map-set asset-inspections
        { asset-id: asset-id }
        {
          inspection-ids: (unwrap-panic
            (as-max-len?
              (append (get inspection-ids asset-inspections-data) new-id)
              u20
            )
          )
        }
      )

      (ok new-id)
    )
  )
)

(define-public (complete-inspection
                (inspection-id uint)
                (findings (string-utf8 500)))
  (let ((inspection (map-get? inspections { inspection-id: inspection-id })))
    (begin
      (asserts! (is-some inspection) (err u404)) ;; Inspection not found
      (asserts! (is-eq (get status (unwrap-panic inspection)) u1) (err u400)) ;; Not in scheduled state
      (asserts! (is-eq tx-sender (get inspector (unwrap-panic inspection))) (err u403)) ;; Not authorized

      (map-set inspections
        { inspection-id: inspection-id }
        (merge (unwrap-panic inspection)
          {
            status: u2, ;; Completed
            findings: findings,
            completion-date: block-height
          }
        )
      )
      (ok true)
    )
  )
)

(define-public (cancel-inspection (inspection-id uint))
  (let ((inspection (map-get? inspections { inspection-id: inspection-id })))
    (begin
      (asserts! (is-some inspection) (err u404)) ;; Inspection not found
      (asserts! (is-eq (get status (unwrap-panic inspection)) u1) (err u400)) ;; Not in scheduled state
      (asserts! (is-eq tx-sender (get inspector (unwrap-panic inspection))) (err u403)) ;; Not authorized

      (map-set inspections
        { inspection-id: inspection-id }
        (merge (unwrap-panic inspection) { status: u3 }) ;; Cancelled
      )
      (ok true)
    )
  )
)
