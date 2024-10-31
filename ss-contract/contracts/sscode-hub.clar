;; Title: Social Token Marketplace
;; Version: 0.1
;; Description: Basic token implementation with core functionality

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-token (err u103))

;; Data Maps
(define-map tokens 
  { token-id: uint }
  { name: (string-ascii 32), symbol: (string-ascii 10), total-supply: uint, owner: principal }
)

(define-map balances 
  { token-id: uint, owner: principal } 
  { balance: uint }
)

;; Variables
(define-data-var last-token-id uint u0)

;; Read-Only Functions
(define-read-only (get-token-details (token-id uint))
  (match (map-get? tokens { token-id: token-id })
    entry (ok entry)
    (err err-invalid-token)
  )
)

(define-read-only (get-balance (token-id uint) (owner principal))
  (default-to 
    { balance: u0 }
    (map-get? balances { token-id: token-id, owner: owner })
  )
)

;; Public Functions
(define-public (create-token (name (string-ascii 32)) (symbol (string-ascii 10)) (initial-supply uint))
  (let
    (
      (new-token-id (+ (var-get last-token-id) u1))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> initial-supply u0) err-invalid-amount)
    (map-set tokens
      { token-id: new-token-id }
      { name: name, symbol: symbol, total-supply: initial-supply, owner: tx-sender }
    )
    (map-set balances
      { token-id: new-token-id, owner: tx-sender }
      { balance: initial-supply }
    )
    (var-set last-token-id new-token-id)
    (ok new-token-id)
  )
)
