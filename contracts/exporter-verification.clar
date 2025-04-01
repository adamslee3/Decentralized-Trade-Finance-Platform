;; Exporter Verification Contract
;; This contract validates seller credentials and history

(define-data-var admin principal tx-sender)

;; Data structure for exporter information
(define-map exporters
  { exporter-id: (string-ascii 64) }
  {
    principal: principal,
    name: (string-ascii 256),
    country: (string-ascii 64),
    verification-status: (string-ascii 16),
    verification-date: uint,
    rating: uint,
    total-transactions: uint
  }
)

;; Data structure for transaction history
(define-map transaction-history
  { exporter-id: (string-ascii 64), transaction-id: (string-ascii 64) }
  {
    buyer: principal,
    amount: uint,
    date: uint,
    status: (string-ascii 16),
    rating: uint
  }
)

;; Register a new exporter
(define-public (register-exporter (exporter-id (string-ascii 64)) (name (string-ascii 256)) (country (string-ascii 64)))
  (let ((caller tx-sender))
    (if (map-insert exporters
          { exporter-id: exporter-id }
          {
            principal: caller,
            name: name,
            country: country,
            verification-status: "pending",
            verification-date: u0,
            rating: u0,
            total-transactions: u0
          })
        (ok true)
        (err u1))))

;; Verify an exporter (admin only)
(define-public (verify-exporter (exporter-id (string-ascii 64)) (status (string-ascii 16)))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (match (map-get? exporters { exporter-id: exporter-id })
        exporter-data (begin
          (map-set exporters
            { exporter-id: exporter-id }
            (merge exporter-data {
              verification-status: status,
              verification-date: (unwrap-panic (get-block-info? time u0))
            }))
          (ok true))
        (err u2))
      (err u3))))

;; Add transaction to history
(define-public (add-transaction
    (exporter-id (string-ascii 64))
    (transaction-id (string-ascii 64))
    (buyer principal)
    (amount uint))
  (let ((caller tx-sender)
        (current-time (unwrap-panic (get-block-info? time u0))))
    (match (map-get? exporters { exporter-id: exporter-id })
      exporter-data
        (if (is-eq caller (get principal exporter-data))
          (begin
            (map-set transaction-history
              { exporter-id: exporter-id, transaction-id: transaction-id }
              {
                buyer: buyer,
                amount: amount,
                date: current-time,
                status: "completed",
                rating: u0
              })
            (map-set exporters
              { exporter-id: exporter-id }
              (merge exporter-data {
                total-transactions: (+ (get total-transactions exporter-data) u1)
              }))
            (ok true))
          (err u4))
      (err u5))))

;; Rate a transaction
(define-public (rate-transaction (exporter-id (string-ascii 64)) (transaction-id (string-ascii 64)) (rating uint))
  (let ((caller tx-sender))
    (match (map-get? transaction-history { exporter-id: exporter-id, transaction-id: transaction-id })
      tx-data
        (if (is-eq caller (get buyer tx-data))
          (begin
            (map-set transaction-history
              { exporter-id: exporter-id, transaction-id: transaction-id }
              (merge tx-data { rating: rating }))
            (ok true))
          (err u6))
      (err u7))))

;; Get exporter information
(define-read-only (get-exporter-info (exporter-id (string-ascii 64)))
  (map-get? exporters { exporter-id: exporter-id }))

;; Get transaction details
(define-read-only (get-transaction (exporter-id (string-ascii 64)) (transaction-id (string-ascii 64)))
  (map-get? transaction-history { exporter-id: exporter-id, transaction-id: transaction-id }))

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (let ((caller tx-sender))
    (if (is-eq caller (var-get admin))
      (begin
        (var-set admin new-admin)
        (ok true))
      (err u8))))

