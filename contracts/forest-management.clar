;; Forest Management Contract
;; Records sustainable forestry practices

;; Data variables
(define-data-var forest-counter uint u0)
(define-data-var plan-counter uint u0)

;; Data maps
(define-map forests
  { id: uint }
  {
    name: (string-ascii 64),
    location: (string-ascii 64),
    area: uint,
    owner: principal,
    active: bool
  }
)

(define-map management-plans
  { id: uint }
  {
    forest-id: uint,
    start-date: uint,
    end-date: uint,
    allowable-cut: uint,
    approved: bool
  }
)

(define-map forest-managers
  { address: principal }
  { active: bool }
)

;; Initialize contract
(define-public (initialize)
  (begin
    (map-set forest-managers { address: tx-sender } { active: true })
    (ok true)
  )
)

;; Check if address is forest manager
(define-read-only (is-manager (address principal))
  (default-to false (get active (map-get? forest-managers { address: address })))
)

;; Add a forest manager
(define-public (add-manager (address principal))
  (begin
    ;; Only managers can add managers
    (asserts! (is-manager tx-sender) (err u403))

    (map-set forest-managers
      { address: address }
      { active: true }
    )

    (ok true)
  )
)

;; Register a forest
(define-public (register-forest (name (string-ascii 64)) (location (string-ascii 64)) (area uint))
  (let ((new-id (+ (var-get forest-counter) u1)))
    ;; Only managers can register forests
    (asserts! (is-manager tx-sender) (err u403))

    ;; Update counter
    (var-set forest-counter new-id)

    ;; Store forest data
    (map-set forests
      { id: new-id }
      {
        name: name,
        location: location,
        area: area,
        owner: tx-sender,
        active: true
      }
    )

    (ok new-id)
  )
)

;; Create management plan
(define-public (create-plan (forest-id uint) (start-date uint) (end-date uint) (allowable-cut uint))
  (let ((new-id (+ (var-get plan-counter) u1))
        (forest (map-get? forests { id: forest-id })))

    ;; Forest must exist
    (asserts! (is-some forest) (err u404))

    ;; Only forest owner or manager can create plan
    (asserts! (or
                (is-eq tx-sender (get owner (unwrap-panic forest)))
                (is-manager tx-sender))
              (err u403))

    ;; End date must be after start date
    (asserts! (> end-date start-date) (err u400))

    ;; Update counter
    (var-set plan-counter new-id)

    ;; Store plan data
    (map-set management-plans
      { id: new-id }
      {
        forest-id: forest-id,
        start-date: start-date,
        end-date: end-date,
        allowable-cut: allowable-cut,
        approved: false
      }
    )

    (ok new-id)
  )
)

;; Approve management plan
(define-public (approve-plan (plan-id uint))
  (let ((plan (map-get? management-plans { id: plan-id })))

    ;; Plan must exist
    (asserts! (is-some plan) (err u404))

    ;; Only managers can approve plans
    (asserts! (is-manager tx-sender) (err u403))

    ;; Store updated plan
    (map-set management-plans
      { id: plan-id }
      (merge (unwrap-panic plan) { approved: true })
    )

    (ok true)
  )
)

;; Get forest details
(define-read-only (get-forest (forest-id uint))
  (map-get? forests { id: forest-id })
)

;; Get plan details
(define-read-only (get-plan (plan-id uint))
  (map-get? management-plans { id: plan-id })
)

;; Check if plan is approved
(define-read-only (is-plan-approved (plan-id uint))
  (default-to false (get approved (map-get? management-plans { id: plan-id })))
)

