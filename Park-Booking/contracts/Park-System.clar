;; Smart Parking System Contract
;; A comprehensive on-chain parking management system

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SPOT_NOT_EXISTS (err u101))
(define-constant ERR_SPOT_OCCUPIED (err u102))
(define-constant ERR_SPOT_NOT_OCCUPIED (err u103))
(define-constant ERR_INVALID_PAYMENT (err u104))
(define-constant ERR_RESERVATION_EXISTS (err u105))
(define-constant ERR_RESERVATION_NOT_EXISTS (err u106))
(define-constant ERR_RESERVATION_EXPIRED (err u107))
(define-constant ERR_INSUFFICIENT_BALANCE (err u108))
(define-constant ERR_INVALID_TIME (err u109))
(define-constant ERR_SPOT_DISABLED (err u110))
(define-constant ERR_ALREADY_CHECKED_OUT (err u111))
(define-constant ERR_INVALID_SPOT_TYPE (err u112))
(define-constant ERR_INVALID_INPUT (err u113))

;; Parking spot types
(define-constant SPOT_TYPE_REGULAR u1)
(define-constant SPOT_TYPE_HANDICAP u2)
(define-constant SPOT_TYPE_ELECTRIC u3)
(define-constant SPOT_TYPE_VIP u4)

;; Data Variables
(define-data-var next-spot-id uint u1)
(define-data-var next-reservation-id uint u1)
(define-data-var contract-balance uint u0)
(define-data-var base-hourly-rate uint u1000000) ;; 1 STX in microSTX
(define-data-var penalty-rate uint u500000) ;; 0.5 STX penalty per hour
(define-data-var max-reservation-duration uint u86400) ;; 24 hours in seconds

;; Data Maps
(define-map parking-spots
  { spot-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    spot-type: uint,
    hourly-rate: uint,
    is-occupied: bool,
    is-active: bool,
    current-user: (optional principal),
    check-in-time: (optional uint),
    reservation-id: (optional uint)
  }
)

(define-map reservations
  { reservation-id: uint }
  {
    user: principal,
    spot-id: uint,
    start-time: uint,
    end-time: uint,
    total-cost: uint,
    is-active: bool,
    is-used: bool
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map parking-sessions
  { session-id: uint }
  {
    user: principal,
    spot-id: uint,
    check-in-time: uint,
    check-out-time: (optional uint),
    total-cost: uint,
    is-completed: bool
  }
)

(define-data-var next-session-id uint u1)

(define-map user-statistics
  { user: principal }
  {
    total-sessions: uint,
    total-spent: uint,
    total-penalties: uint,
    reputation-score: uint
  }
)

(define-map spot-statistics
  { spot-id: uint }
  {
    total-sessions: uint,
    total-revenue: uint,
    average-duration: uint,
    last-maintenance: uint
  }
)

;; Read-only functions

;; Get parking spot details
(define-read-only (get-parking-spot (spot-id uint))
  (map-get? parking-spots { spot-id: spot-id })
)

;; Get reservation details
(define-read-only (get-reservation (reservation-id uint))
  (map-get? reservations { reservation-id: reservation-id })
)

;; Get user balance
(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

;; Get current time (block height as proxy)
(define-read-only (get-current-time)
  block-height
)

;; Calculate parking cost
(define-read-only (calculate-parking-cost (spot-id uint) (duration uint))
  (match (map-get? parking-spots { spot-id: spot-id })
    spot-data (let
      (
        (hourly-rate (get hourly-rate spot-data))
        (hours (/ (+ duration u3599) u3600)) ;; Round up to nearest hour
      )
      (ok (* hours hourly-rate))
    )
    ERR_SPOT_NOT_EXISTS
  )
)

;; Check if spot is available for reservation
(define-read-only (is-spot-available (spot-id uint) (start-time uint) (end-time uint))
  (match (map-get? parking-spots { spot-id: spot-id })
    spot-data (and
      (get is-active spot-data)
      (not (get is-occupied spot-data))
      (is-none (get reservation-id spot-data))
    )
    false
  )
)

;; Get user statistics
(define-read-only (get-user-statistics (user principal))
  (map-get? user-statistics { user: user })
)

;; Get spot statistics
(define-read-only (get-spot-statistics (spot-id uint))
  (map-get? spot-statistics { spot-id: spot-id })
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

;; Get base rates
(define-read-only (get-base-hourly-rate)
  (var-get base-hourly-rate)
)

(define-read-only (get-penalty-rate)
  (var-get penalty-rate)
)

;; Private functions

;; Validate input parameters
(define-private (validate-spot-id (spot-id uint))
  (and (> spot-id u0) (<= spot-id u1000000))
)

(define-private (validate-reservation-id (reservation-id uint))
  (and (> reservation-id u0) (<= reservation-id u1000000))
)

(define-private (validate-location (location (string-ascii 100)))
  (and (> (len location) u0) (<= (len location) u100))
)

;; Update user statistics
(define-private (update-user-stats (user principal) (cost uint) (penalty uint))
  (let
    (
      (current-stats (default-to 
        { total-sessions: u0, total-spent: u0, total-penalties: u0, reputation-score: u100 }
        (map-get? user-statistics { user: user })
      ))
      (new-sessions (+ (get total-sessions current-stats) u1))
      (new-spent (+ (get total-spent current-stats) cost))
      (new-penalties (+ (get total-penalties current-stats) penalty))
      (reputation-adjustment (if (> penalty u0) u95 u105)) ;; Penalty reduces reputation
      (calculated-reputation (/ (* (get reputation-score current-stats) reputation-adjustment) u100))
      (new-reputation (if (> calculated-reputation u200) u200 calculated-reputation))
    )
    (map-set user-statistics { user: user }
      {
        total-sessions: new-sessions,
        total-spent: new-spent,
        total-penalties: new-penalties,
        reputation-score: new-reputation
      }
    )
  )
)

;; Update spot statistics
(define-private (update-spot-stats (validated-spot-id uint) (revenue uint) (duration uint))
  (let
    (
      (current-stats (default-to 
        { total-sessions: u0, total-revenue: u0, average-duration: u0, last-maintenance: u0 }
        (map-get? spot-statistics { spot-id: validated-spot-id })
      ))
      (new-sessions (+ (get total-sessions current-stats) u1))
      (new-revenue (+ (get total-revenue current-stats) revenue))
      (new-avg-duration (/ (+ (* (get average-duration current-stats) (get total-sessions current-stats)) duration) new-sessions))
    )
    (map-set spot-statistics { spot-id: validated-spot-id }
      {
        total-sessions: new-sessions,
        total-revenue: new-revenue,
        average-duration: new-avg-duration,
        last-maintenance: (get last-maintenance current-stats)
      }
    )
  )
)

;; Public functions

;; Add a new parking spot (only spot owners can add)
(define-public (add-parking-spot (location (string-ascii 100)) (spot-type uint) (hourly-rate uint))
  (let
    (
      (validated-spot-id (var-get next-spot-id))
    )
    ;; Validate inputs
    (asserts! (validate-location location) ERR_INVALID_INPUT)
    (asserts! (or (is-eq spot-type SPOT_TYPE_REGULAR)
                  (is-eq spot-type SPOT_TYPE_HANDICAP)
                  (is-eq spot-type SPOT_TYPE_ELECTRIC)
                  (is-eq spot-type SPOT_TYPE_VIP)) ERR_INVALID_SPOT_TYPE)
    (asserts! (> hourly-rate u0) ERR_INVALID_PAYMENT)
    
    (map-set parking-spots { spot-id: validated-spot-id }
      {
        owner: tx-sender,
        location: location,
        spot-type: spot-type,
        hourly-rate: hourly-rate,
        is-occupied: false,
        is-active: true,
        current-user: none,
        check-in-time: none,
        reservation-id: none
      }
    )
    
    (var-set next-spot-id (+ validated-spot-id u1))
    (ok validated-spot-id)
  )
)

;; Update parking spot (only owner)
(define-public (update-parking-spot (spot-id uint) (hourly-rate uint) (is-active bool))
  (begin
    ;; Validate inputs
    (asserts! (validate-spot-id spot-id) ERR_INVALID_INPUT)
    (asserts! (> hourly-rate u0) ERR_INVALID_PAYMENT)
    
    (match (map-get? parking-spots { spot-id: spot-id })
      spot-data (begin
        (asserts! (is-eq tx-sender (get owner spot-data)) ERR_UNAUTHORIZED)
        
        (map-set parking-spots { spot-id: spot-id }
          (merge spot-data { 
            hourly-rate: hourly-rate,
            is-active: is-active
          })
        )
        (ok true)
      )
      ERR_SPOT_NOT_EXISTS
    )
  )
)

;; Deposit funds to user balance
(define-public (deposit-funds (amount uint))
  (let
    (
      (current-balance (get-user-balance tx-sender))
    )
    (asserts! (> amount u0) ERR_INVALID_PAYMENT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update user balance
    (map-set user-balances { user: tx-sender }
      { balance: (+ current-balance amount) }
    )
    
    ;; Update contract balance
    (var-set contract-balance (+ (var-get contract-balance) amount))
    
    (ok true)
  )
)

;; Withdraw funds from user balance
(define-public (withdraw-funds (amount uint))
  (let
    (
      (current-balance (get-user-balance tx-sender))
    )
    (asserts! (<= amount current-balance) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_PAYMENT)
    
    ;; Update user balance
    (map-set user-balances { user: tx-sender }
      { balance: (- current-balance amount) }
    )
    
    ;; Update contract balance
    (var-set contract-balance (- (var-get contract-balance) amount))
    
    ;; Transfer STX from contract to user
    (as-contract (stx-transfer? amount tx-sender tx-sender))
  )
)

;; Make a reservation
(define-public (make-reservation (spot-id uint) (start-time uint) (duration uint))
  (let
    (
      (validated-reservation-id (var-get next-reservation-id))
      (end-time (+ start-time duration))
      (cost-result (calculate-parking-cost spot-id duration))
    )
    ;; Validate inputs
    (asserts! (validate-spot-id spot-id) ERR_INVALID_INPUT)
    (asserts! (<= duration (var-get max-reservation-duration)) ERR_INVALID_TIME)
    (asserts! (>= start-time (get-current-time)) ERR_INVALID_TIME)
    (asserts! (is-spot-available spot-id start-time end-time) ERR_SPOT_OCCUPIED)
    
    (match cost-result
      total-cost (begin
        (asserts! (>= (get-user-balance tx-sender) total-cost) ERR_INSUFFICIENT_BALANCE)
        
        ;; Deduct cost from user balance
        (map-set user-balances { user: tx-sender }
          { balance: (- (get-user-balance tx-sender) total-cost) }
        )
        
        ;; Create reservation
        (map-set reservations { reservation-id: validated-reservation-id }
          {
            user: tx-sender,
            spot-id: spot-id,
            start-time: start-time,
            end-time: end-time,
            total-cost: total-cost,
            is-active: true,
            is-used: false
          }
        )
        
        ;; Update spot with reservation
        (match (map-get? parking-spots { spot-id: spot-id })
          spot-data (map-set parking-spots { spot-id: spot-id }
            (merge spot-data { reservation-id: (some validated-reservation-id) })
          )
          false
        )
        
        (var-set next-reservation-id (+ validated-reservation-id u1))
        (ok validated-reservation-id)
      )
      error-code (err error-code)
    )
  )
)

;; Cancel reservation (with partial refund)
(define-public (cancel-reservation (reservation-id uint))
  (begin
    ;; Validate input
    (asserts! (validate-reservation-id reservation-id) ERR_INVALID_INPUT)
    
    (match (map-get? reservations { reservation-id: reservation-id })
      reservation (begin
        (asserts! (is-eq tx-sender (get user reservation)) ERR_UNAUTHORIZED)
        (asserts! (get is-active reservation) ERR_RESERVATION_NOT_EXISTS)
        (asserts! (not (get is-used reservation)) ERR_RESERVATION_NOT_EXISTS)
        
        (let
          (
            (current-time (get-current-time))
            (start-time (get start-time reservation))
            (total-cost (get total-cost reservation))
            (refund-amount (if (> start-time current-time)
                             (/ (* total-cost u80) u100) ;; 80% refund if cancelled before start
                             u0)) ;; No refund if cancelled after start
          )
          
          ;; Refund user
          (if (> refund-amount u0)
            (map-set user-balances { user: tx-sender }
              { balance: (+ (get-user-balance tx-sender) refund-amount) }
            )
            true
          )
          
          ;; Deactivate reservation
          (map-set reservations { reservation-id: reservation-id }
            (merge reservation { is-active: false })
          )
          
          ;; Clear reservation from spot
          (match (map-get? parking-spots { spot-id: (get spot-id reservation) })
            spot-data (map-set parking-spots { spot-id: (get spot-id reservation) }
              (merge spot-data { reservation-id: none })
            )
            false
          )
          
          (ok refund-amount)
        )
      )
      ERR_RESERVATION_NOT_EXISTS
    )
  )
)

;; Check into parking spot
(define-public (check-in (spot-id uint))
  (begin
    ;; Validate input
    (asserts! (validate-spot-id spot-id) ERR_INVALID_INPUT)
    
    (match (map-get? parking-spots { spot-id: spot-id })
      spot-data (begin
        (asserts! (get is-active spot-data) ERR_SPOT_DISABLED)
        (asserts! (not (get is-occupied spot-data)) ERR_SPOT_OCCUPIED)
        
        (let
          (
            (current-time (get-current-time))
            (validated-session-id (var-get next-session-id))
            (has-reservation (is-some (get reservation-id spot-data)))
          )
          
          ;; If spot has reservation, validate it
          (if has-reservation
            (match (get reservation-id spot-data)
              res-id (match (map-get? reservations { reservation-id: res-id })
                reservation (begin
                  (asserts! (is-eq tx-sender (get user reservation)) ERR_UNAUTHORIZED)
                  (asserts! (get is-active reservation) ERR_RESERVATION_EXPIRED)
                  (asserts! (<= (get start-time reservation) current-time) ERR_INVALID_TIME)
                  (asserts! (>= (get end-time reservation) current-time) ERR_RESERVATION_EXPIRED)
                  
                  ;; Mark reservation as used
                  (map-set reservations { reservation-id: res-id }
                    (merge reservation { is-used: true })
                  )
                  true
                )
                false
              )
              true
            )
            true
          )
          
          ;; Create parking session
          (map-set parking-sessions { session-id: validated-session-id }
            {
              user: tx-sender,
              spot-id: spot-id,
              check-in-time: current-time,
              check-out-time: none,
              total-cost: u0,
              is-completed: false
            }
          )
          
          ;; Update parking spot
          (map-set parking-spots { spot-id: spot-id }
            (merge spot-data {
              is-occupied: true,
              current-user: (some tx-sender),
              check-in-time: (some current-time)
            })
          )
          
          (var-set next-session-id (+ validated-session-id u1))
          (ok validated-session-id)
        )
      )
      ERR_SPOT_NOT_EXISTS
    )
  )
)

;; Check out of parking spot
(define-public (check-out (spot-id uint))
  (begin
    ;; Validate input
    (asserts! (validate-spot-id spot-id) ERR_INVALID_INPUT)
    
    (match (map-get? parking-spots { spot-id: spot-id })
      spot-data (begin
        (asserts! (get is-occupied spot-data) ERR_SPOT_NOT_OCCUPIED)
        (asserts! (is-eq (some tx-sender) (get current-user spot-data)) ERR_UNAUTHORIZED)
        
        (let
          (
            (current-time (get-current-time))
            (check-in-time (unwrap! (get check-in-time spot-data) ERR_INVALID_TIME))
            (duration (- current-time check-in-time))
            (cost-result (calculate-parking-cost spot-id duration))
            (spot-owner (get owner spot-data))
          )
          
          (match cost-result
            total-cost (begin
              (let
                (
                  (user-balance (get-user-balance tx-sender))
                  (penalty (if (> total-cost user-balance) 
                             (* (var-get penalty-rate) (/ (- total-cost user-balance) (get hourly-rate spot-data)))
                             u0))
                  (final-cost (+ total-cost penalty))
                  (owner-share (/ (* total-cost u90) u100)) ;; 90% to spot owner
                  (platform-share (- total-cost owner-share)) ;; 10% to platform
                )
                
                ;; Handle payment
                (if (>= user-balance final-cost)
                  (begin
                    ;; Sufficient balance - deduct from user
                    (map-set user-balances { user: tx-sender }
                      { balance: (- user-balance final-cost) }
                    )
                    
                    ;; Pay spot owner
                    (map-set user-balances { user: spot-owner }
                      { balance: (+ (get-user-balance spot-owner) owner-share) }
                    )
                  )
                  (begin
                    ;; Insufficient balance - deduct all available and record penalty
                    (map-set user-balances { user: tx-sender }
                      { balance: u0 }
                    )
                    
                    ;; Pay spot owner partial amount
                    (let ((partial-owner-share (/ (* user-balance u90) u100)))
                      (map-set user-balances { user: spot-owner }
                        { balance: (+ (get-user-balance spot-owner) partial-owner-share) }
                      )
                    )
                  )
                )
                
                ;; Update parking spot
                (map-set parking-spots { spot-id: spot-id }
                  (merge spot-data {
                    is-occupied: false,
                    current-user: none,
                    check-in-time: none,
                    reservation-id: none
                  })
                )
                
                ;; Update statistics
                (update-user-stats tx-sender final-cost penalty)
                (update-spot-stats spot-id total-cost duration)
                
                (ok { cost: final-cost, duration: duration, penalty: penalty })
              )
            )
            error-code (err error-code)
          )
        )
      )
      ERR_SPOT_NOT_EXISTS
    )
  )
)

;; Emergency unlock (contract owner only)
(define-public (emergency-unlock (spot-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    ;; Validate input
    (asserts! (validate-spot-id spot-id) ERR_INVALID_INPUT)
    
    (match (map-get? parking-spots { spot-id: spot-id })
      spot-data (begin
        (map-set parking-spots { spot-id: spot-id }
          (merge spot-data {
            is-occupied: false,
            current-user: none,
            check-in-time: none,
            reservation-id: none
          })
        )
        (ok true)
      )
      ERR_SPOT_NOT_EXISTS
    )
  )
)

;; Set base rates (contract owner only)
(define-public (set-base-rates (hourly-rate uint) (new-penalty-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> hourly-rate u0) ERR_INVALID_PAYMENT)
    (asserts! (> new-penalty-rate u0) ERR_INVALID_PAYMENT)
    
    (var-set base-hourly-rate hourly-rate)
    (var-set penalty-rate new-penalty-rate)
    (ok true)
  )
)

;; Set maximum reservation duration (contract owner only)
(define-public (set-max-reservation-duration (duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> duration u0) ERR_INVALID_TIME)
    
    (var-set max-reservation-duration duration)
    (ok true)
  )
)