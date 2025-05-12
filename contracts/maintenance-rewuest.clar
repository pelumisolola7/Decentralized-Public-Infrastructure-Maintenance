;; Maintenance Request Contract
;; Tracks identified repair needs

(define-data-var last-request-id uint u0)

(define-map maintenance-requests
  { request-id: uint }
  {
    asset-id: uint,
    description: (string-utf8 500),
    priority: uint, ;; 1=Low, 2=Medium, 3=High, 4=Critical
    status: uint, ;; 1=Open, 2=Assigned, 3=Completed, 4=Cancelled
    requester: principal,
    assigned-contractor: (optional principal),
    created-at: uint,
    completed-at: uint
  }
)

(define-map asset-requests
  { asset-id: uint }
  { request-ids: (list 50 uint) }
)

(define-read-only (get-maintenance-request (request-id uint))
  (map-get? maintenance-requests { request-id: request-id })
)

(define-read-only (get-asset-requests (asset-id uint))
  (default-to { request-ids: (list) }
    (map-get? asset-requests { asset-id: asset-id }))
)

(define-public (create-maintenance-request
                (asset-id uint)
                (description (string-utf8 500))
                (priority uint))
  (let (
    (new-id (+ (var-get last-request-id) u1))
    (asset-requests-data (get-asset-requests asset-id))
  )
    (begin
      (asserts! (and (>= priority u1) (<= priority u4)) (err u1)) ;; Valid priority

      (var-set last-request-id new-id)
      (map-set maintenance-requests
        { request-id: new-id }
        {
          asset-id: asset-id,
          description: description,
          priority: priority,
          status: u1, ;; Open
          requester: tx-sender,
          assigned-contractor: none,
          created-at: block-height,
          completed-at: u0
        }
      )

      ;; Update the asset-requests map
      (map-set asset-requests
        { asset-id: asset-id }
        {
          request-ids: (unwrap-panic
            (as-max-len?
              (append (get request-ids asset-requests-data) new-id)
              u50
            )
          )
        }
      )

      (ok new-id)
    )
  )
)

(define-public (assign-maintenance-request
                (request-id uint)
                (contractor principal))
  (let ((request (map-get? maintenance-requests { request-id: request-id })))
    (begin
      (asserts! (is-some request) (err u404)) ;; Request not found
      (asserts! (is-eq (get status (unwrap-panic request)) u1) (err u400)) ;; Not in open state

      ;; In a real implementation, we would check if the contractor is verified
      ;; using contract-call? to the contractor-verification contract

      (map-set maintenance-requests
        { request-id: request-id }
        (merge (unwrap-panic request)
          {
            status: u2, ;; Assigned
            assigned-contractor: (some contractor)
          }
        )
      )
      (ok true)
    )
  )
)

(define-public (complete-maintenance-request (request-id uint))
  (let ((request (map-get? maintenance-requests { request-id: request-id })))
    (begin
      (asserts! (is-some request) (err u404)) ;; Request not found
      (asserts! (is-eq (get status (unwrap-panic request)) u2) (err u400)) ;; Not in assigned state
      (asserts! (is-eq tx-sender (unwrap-panic (get assigned-contractor (unwrap-panic request)))) (err u403)) ;; Not authorized

      (map-set maintenance-requests
        { request-id: request-id }
        (merge (unwrap-panic request)
          {
            status: u3, ;; Completed
            completed-at: block-height
          }
        )
      )
      (ok true)
    )
  )
)

(define-public (cancel-maintenance-request (request-id uint))
  (let ((request (map-get? maintenance-requests { request-id: request-id })))
    (begin
      (asserts! (is-some request) (err u404)) ;; Request not found
      (asserts! (or
                  (is-eq (get status (unwrap-panic request)) u1)
                  (is-eq (get status (unwrap-panic request)) u2)
                ) (err u400)) ;; Must be open or assigned
      (asserts! (is-eq tx-sender (get requester (unwrap-panic request))) (err u403)) ;; Not authorized

      (map-set maintenance-requests
        { request-id: request-id }
        (merge (unwrap-panic request) { status: u4 }) ;; Cancelled
      )
      (ok true)
    )
  )
)
