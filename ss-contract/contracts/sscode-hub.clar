;; Title: Social Token Marketplace
;; Version: 1.2
;; Description: A non-custodial social token marketplace smart contract with added security checks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-token (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-invalid-price (err u105))
(define-constant err-order-not-found (err u106))
(define-constant err-insufficient-liquidity (err u107))
(define-constant err-not-authorized (err u108))
(define-constant err-paused (err u109))
(define-constant err-invalid-string (err u110))
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

(define-map liquidity-pools
  { token-id: uint }
  { total-liquidity: uint, price: uint }
)

(define-map governance-settings
  { setting-id: (string-ascii 32) }
  { value: (string-utf8 256) }
)

;; Variables
(define-data-var last-token-id uint u0)
(define-data-var last-order-id uint u0)
(define-data-var contract-paused bool false)

;; Private Functions

(define-private (validate-string (str (string-ascii 32)))
  (and (> (len str) u0) (<= (len str) u32))
)

(define-private (validate-symbol (sym (string-ascii 10)))
  (and (> (len sym) u0) (<= (len sym) u10))
)

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

(define-read-only (get-liquidity-pool (token-id uint))
  (default-to
    { total-liquidity: u0, price: u0 }
    (map-get? liquidity-pools { token-id: token-id })
  )
)

;; Public Functions

;; Create new social token
(define-public (create-token (name (string-ascii 32)) (symbol (string-ascii 10)) (initial-supply uint))
  (let
    (
      (new-token-id (+ (var-get last-token-id) u1))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (validate-string name) err-invalid-string)
    (asserts! (validate-symbol symbol) err-invalid-string)
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
    (print { type: "token-created", token-id: new-token-id, name: name, symbol: symbol, supply: initial-supply })
    (ok new-token-id)
  )
)

;; Mint tokens
(define-public (mint-tokens (token-id uint) (amount uint))
  (let
    (
      (token (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token))
      (current-supply (get total-supply token))
      (token-owner (get owner token))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
    (asserts! (> amount u0) err-invalid-amount)
    (map-set tokens
      { token-id: token-id }
      (merge token { total-supply: (+ current-supply amount) })
    )
    (map-set balances
      { token-id: token-id, owner: tx-sender }
      { balance: (+ (get balance (get-balance token-id tx-sender)) amount) }
    )
    (print { type: "tokens-minted", token-id: token-id, amount: amount, recipient: tx-sender })
    (ok true)
  )
)

;; Transfer tokens
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
    (print { type: "transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient })
    (ok true)
  )
)

;; Create sell order
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
    (print { type: "sell-order-created", order-id: new-order-id, token-id: token-id, amount: amount, price: price, seller: tx-sender })
    (ok new-order-id)
  )
)

;; Create buy order
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
    (print { type: "buy-order-created", order-id: new-order-id, token-id: token-id, amount: amount, price: price, buyer: tx-sender })
    (ok new-order-id)
  )
)

;; Execute order
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
    (asserts! (not (var-get contract-paused)) err-paused)
    (asserts! (validate-order-id order-id) err-order-not-found)
    (if (is-eq order-type "sell")
      (execute-sell-order order-id token-id amount price seller tx-sender)
      (execute-buy-order order-id token-id amount price seller tx-sender)
    )
  )
)

;; Add liquidity
(define-public (add-liquidity (token-id uint) (amount uint))
  (let
    (
      (token (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token))
      (current-pool (get-liquidity-pool token-id))
      (current-liquidity (get total-liquidity current-pool))
      (current-price (get price current-pool))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (not (var-get contract-paused)) err-paused)
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
    (print { type: "liquidity-added", token-id: token-id, amount: amount, provider: tx-sender })
    (ok true)
  )
)

;; Remove liquidity
(define-public (remove-liquidity (token-id uint) (amount uint))
  (let
    (
      (current-pool (get-liquidity-pool token-id))
      (current-liquidity (get total-liquidity current-pool))
      (current-price (get price current-pool))
    )
    (asserts! (validate-token-id token-id) err-invalid-token)
    (asserts! (not (var-get contract-paused)) err-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= current-liquidity amount) err-insufficient-liquidity)
    (map-set liquidity-pools
      { token-id: token-id }
      { total-liquidity: (- current-liquidity amount), price: (calculate-new-price current-price current-liquidity amount false) }
    )
    (map-set balances
      { token-id: token-id, owner: tx-sender }
      { balance: (+ (get balance (get-balance token-id tx-sender)) amount) }
    )
    (print { type: "liquidity-removed", token-id: token-id, amount: amount, provider: tx-sender })
    (ok true)
  )
)

;; Private Functions

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
    (print { type: "order-executed", order-id: order-id, token-id: token-id, amount: amount, price: price, seller: seller, buyer: buyer })
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
    (print { type: "order-executed", order-id: order-id, token-id: token-id, amount: amount, price: price, seller: seller, buyer: buyer })
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
