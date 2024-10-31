;; Title: Social Token Marketplace
;; Version: 0.4
;; Description: Added order execution functionality

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-token (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-order-not-found (err u106))
(define-constant err-not-authorized (err u108))
(define-constant err-invalid-recipient (err u111))

;; Data Maps
(define-map tokens 
  { token-id: uint }
  { name: (string-ascii 32), symbol: (string-ascii 10), total-supply: uint, owner: principal }
)

(define-map balances 
  { token-id: uint, owner: principal } 
  { balance: uint }
)

(define-map orders
  { order-id: uint }
  { token-id: uint, amount: uint, price: uint, seller: principal, order-type: (string-ascii 4) }
)

;; Variables
(define-data-var last-token-id uint u0)
(define-data-var last-order-id uint u0)

;; Private Functions
(define-private (validate-token-id (token-id uint))
  (is-some (map-get? tokens { token-id: token-id }))
)

(define-private (validate-recipient (recipient principal))
  (and 
    (not (is-eq recipient tx-sender))
    (not (is-eq recipient contract-owner))
  )
)

(define-private (validate-order-id (order-id uint))
  (is-some (map-get? orders { order-id: order-id }))
)

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

(define-read-only (get-order (order-id uint))
  (match (map-get? orders { order-id: order-id })
    entry (ok entry)
    (err err-order-not-found)
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

(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
  (let
    (
      (sender-balance (get balance (get-balance token-id sender)))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (validate-recipient recipient) err-invalid-recipient)
    (asserts! (is-eq tx-sender sender) err-not-authorized)
    (asserts! (>= sender-balance amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    (map-set balances
      { token-id: token-id, owner: sender }
      { balance: (- sender-balance amount) }
    )
    (map-set balances
      { token-id: token-id, owner: recipient }
      { balance: (+ (get balance (get-balance token-id recipient)) amount) }
    )
    (ok true)
  )
)

(define-public (create-sell-order (token-id uint) (amount uint) (price uint))
  (let
    (
      (seller-balance (get balance (get-balance token-id tx-sender)))
      (new-order-id (+ (var-get last-order-id) u1))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (>= seller-balance amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> price u0) err-invalid-price)
    (map-set orders
      { order-id: new-order-id }
      { token-id: token-id, amount: amount, price: price, seller: tx-sender, order-type: "sell" }
    )
    (var-set last-order-id new-order-id)
    (ok new-order-id)
  )
)

(define-public (create-buy-order (token-id uint) (amount uint) (price uint))
  (let
    (
      (new-order-id (+ (var-get last-order-id) u1))
      (total-cost (* amount price))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) err-insufficient-balance)
    (map-set orders
      { order-id: new-order-id }
      { token-id: token-id, amount: amount, price: price, seller: tx-sender, order-type: "buy" }
    )
    (var-set last-order-id new-order-id)
    (ok new-order-id)
  )
)

(define-public (execute-order (order-id uint))
  (let
    (
      (order (unwrap! (map-get? orders { order-id: order-id }) err-order-not-found))
      (token-id (get token-id order))
      (amount (get amount order))
      (price (get price order))
      (seller (get seller order))
      (order-type (get order-type order))
    )
    (asserts! (validate-order-id order-id) err-order-not-found)
    (if (is-eq order-type "sell")
      (execute-sell-order order-id token-id amount price seller tx-sender)
      (execute-buy-order order-id token-id amount price seller tx-sender)
    )
  )
)

(define-private (execute-sell-order (order-id uint) (token-id uint) (amount uint) (price uint) (seller principal) (buyer principal))
  (let
    (
      (total-cost (* amount price))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (validate-order-id order-id) err-order-not-found)
    (asserts! (>= (stx-get-balance buyer) total-cost) err-insufficient-balance)
    (try! (stx-transfer? total-cost buyer seller))
    (try! (transfer token-id amount seller buyer))
    (map-delete orders { order-id: order-id })
    (ok true)
  )
)

(define-private (execute-buy-order (order-id uint) (token-id uint) (amount uint) (price uint) (buyer principal) (seller principal))
  (let
    (
      (total-cost (* amount price))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (validate-order-id order-id) err-order-not-found)
    (asserts! (>= (get balance (get-balance token-id seller)) amount) err-insufficient-balance)
    (try! (stx-transfer? total-cost buyer seller))
    (try! (transfer token-id amount seller buyer))
    (map-delete orders { order-id: order-id })
    (ok true)
  )
)

(define-map liquidity-pools
  { token-id: uint }
  { total-liquidity: uint, price: uint }
)

(define-read-only (get-liquidity-pool (token-id uint))
  (default-to
    { total-liquidity: u0, price: u0 }
    (map-get? liquidity-pools { token-id: token-id })
  )
)

(define-public (add-liquidity (token-id uint) (amount uint))
  (let
    (
      (token (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token))
      (current-pool (get-liquidity-pool token-id))
      (current-liquidity (get total-liquidity current-pool))
      (current-price (get price current-pool))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get balance (get-balance token-id tx-sender)) amount) err-insufficient-balance)
    (map-set liquidity-pools
      { token-id: token-id }
      { total-liquidity: (+ current-liquidity amount), price: (calculate-new-price current-price current-liquidity amount true) }
    )
    (map-set balances
      { token-id: token-id, owner: tx-sender }
      { balance: (- (get balance (get-balance token-id tx-sender)) amount) }
    )
    (ok true)
  )
)

(define-private (calculate-new-price (current-price uint) (current-liquidity uint) (liquidity-change uint) (is-adding bool))
  (let
    (
      (new-liquidity (if is-adding
                        (+ current-liquidity liquidity-change)
                        (if (> current-liquidity liquidity-change)
                            (- current-liquidity liquidity-change)
                            u0)))
    )
    (if (> new-liquidity u0)
      (/ (* current-price current-liquidity) new-liquidity)
      u0
    )
  )
)
