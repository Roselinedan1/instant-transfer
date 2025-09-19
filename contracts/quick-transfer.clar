;; instant-transfer
;; A decentralized secure transfer protocol for rapid STX transactions

;; Error definitions
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TRANSFER-FAILED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-TRANSFER-LIMIT (err u103))
(define-constant ERR-COOLING-PERIOD (err u104))

;; Transfer status constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-CANCELLED u3)

;; Configuration variables
(define-data-var platform-fee-bps uint u50) ;; Default 0.5% platform fee
(define-data-var max-transfer-limit uint u10000000) ;; Maximum transfer amount (100 STX)
(define-data-var cooling-period uint u144) ;; ~24 hours in blocks
(define-data-var contract-owner principal tx-sender)

;; Transfers tracking map
(define-map instant-transfers
  { transfer-id: uint }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    status: uint,
    created-at: uint,
    confirmed-at: (optional uint)
  }
)

;; Transfer ID counter
(define-data-var transfer-id-counter uint u1)

;; Private helper functions

;; Generate a unique transfer ID
(define-private (generate-transfer-id)
  (let ((current-id (var-get transfer-id-counter)))
    (var-set transfer-id-counter (+ current-id u1))
    current-id
  )
)

;; Validate transfer limits
(define-private (validate-transfer-amount (amount uint))
  (and 
    (> amount u0) 
    (<= amount (var-get max-transfer-limit))
  )
)

;; Platform fee calculation
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-bps)) u10000)
)

;; Check contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Read-only functions

;; Get transfer details
(define-read-only (get-transfer (transfer-id uint))
  (map-get? instant-transfers { transfer-id: transfer-id })
)

;; Public functions

;; Initiate a new transfer
(define-public (create-transfer 
  (recipient principal)
  (amount uint)
)
  (let (
    (transfer-id (generate-transfer-id))
    (platform-fee (calculate-platform-fee amount))
    (net-transfer (- amount platform-fee))
  )
    ;; Validate transfer
    (asserts! (validate-transfer-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq tx-sender recipient)) ERR-NOT-AUTHORIZED)

    ;; Transfer platform fee and lock funds
    (try! (stx-transfer? platform-fee tx-sender (var-get contract-owner)))
    (try! (stx-transfer? net-transfer tx-sender (as-contract tx-sender)))

    ;; Record transfer
    (map-set instant-transfers
      { transfer-id: transfer-id }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: net-transfer,
        status: STATUS-PENDING,
        created-at: block-height,
        confirmed-at: none
      }
    )

    (ok transfer-id)
  )
)

;; Confirm and complete a transfer
(define-public (confirm-transfer (transfer-id uint))
  (let (
    (transfer (unwrap! (map-get? instant-transfers { transfer-id: transfer-id }) ERR-TRANSFER-FAILED))
  )
    ;; Validate confirmation
    (asserts! (is-eq tx-sender (get recipient transfer)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status transfer) STATUS-PENDING) ERR-TRANSFER-FAILED)
    (asserts! 
      (>= (- block-height (get created-at transfer)) (var-get cooling-period)) 
      ERR-COOLING-PERIOD
    )

    ;; Transfer funds to recipient
    (as-contract 
      (try! (stx-transfer? (get amount transfer) tx-sender (get recipient transfer)))
    )

    ;; Update transfer status
    (map-set instant-transfers
      { transfer-id: transfer-id }
      (merge transfer {
        status: STATUS-COMPLETED,
        confirmed-at: (some block-height)
      })
    )

    (ok true)
  )
)

;; Cancel a pending transfer
(define-public (cancel-transfer (transfer-id uint))
  (let (
    (transfer (unwrap! (map-get? instant-transfers { transfer-id: transfer-id }) ERR-TRANSFER-FAILED))
  )
    ;; Only sender can cancel
    (asserts! (is-eq tx-sender (get sender transfer)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status transfer) STATUS-PENDING) ERR-TRANSFER-FAILED)

    ;; Refund sender
    (as-contract 
      (try! (stx-transfer? (get amount transfer) tx-sender (get sender transfer)))
    )

    ;; Update transfer status
    (map-set instant-transfers
      { transfer-id: transfer-id }
      (merge transfer {
        status: STATUS-CANCELLED
      })
    )

    (ok true)
  )
)

;; Administrative functions

;; Update platform fee
(define-public (update-platform-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-INVALID-AMOUNT) ;; Max 10%
    (var-set platform-fee-bps new-fee-bps)
    (ok true)
  )
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)