;; Shipping Documentation Contract
;; This contract tracks bills of lading and certificates

(define-data-var admin principal tx-sender)

;; Data structure for shipping documents
(define-map shipping-documents
  { document-id: (string-ascii 64) }
  {
    document-type: (string-ascii 32),
    issuer: principal,
    owner: principal,
    related-trade: (string-ascii 64),
    issue-date: uint,
    expiry-date: uint,
    status: (string-ascii 16),
    metadata: (string-ascii 256),
    verification-hash: (buff 32)
  }
)

;; Data structure for document transfers
(define-map document-transfers
  { document-id: (string-ascii 64), transfer-id: (string-ascii 64) }
  {
    from: principal,
    to: principal,
    timestamp: uint,
    status: (string-ascii 16)
  }
)

;; Issue a new shipping document
(define-public (issue-document
    (document-id (string-ascii 64))
    (document-type (string-ascii 32))
    (owner principal)
    (related-trade (string-ascii 64))
    (expiry-date uint)
    (metadata (string-ascii 256))
    (verification-hash (buff 32)))
  (let ((caller tx-sender)
        (current-time (unwrap-panic (get-block-info? time u0))))
    (if (map-insert shipping-documents
          { document-id: document-id }
          {
            document-type: document-type,
            issuer: caller,
            owner: owner,
            related-trade: related-trade,
            issue-date: current-time,
            expiry-date: expiry-date,
            status: "active",
            metadata: metadata,
            verification-hash: verification-hash
          })
        (ok true)
        (err u1))))

;; Transfer document ownership
(define-public (transfer-document (document-id (string-ascii 64)) (transfer-id (string-ascii 64)) (new-owner principal))
  (let ((caller tx-sender)
        (current-time (unwrap-panic (get-block-info? time u0))))
    (match (map-get? shipping-documents { document-id: document-id })
      doc-data
        (if (is-eq caller (get owner doc-data))
          (begin
            (map-set shipping-documents
              { document-id: document-id }
              (merge doc-data { owner: new-owner }))
            (map-insert document-transfers
              { document-id: document-id, transfer-id: transfer-id }
              {
                from: caller,
                to: new-owner,
                timestamp: current-time,
                status: "completed"
              })
            (ok true))
          (err u2))
      (err u3))))

;; Verify document authenticity
(define-public (verify-document (document-id (string-ascii 64)) (hash-to-verify (buff 32)))
  (match (map-get? shipping-documents { document-id: document-id })
    doc-data
      (ok (is-eq (get verification-hash doc-data) hash-to-verify))
    (err u4)))

;; Update document status
(define-public (update-document-status (document-id (string-ascii 64)) (new-status (string-ascii 16)))
  (let ((caller tx-sender))
    (match (map-get? shipping-documents { document-id: document-id })
      doc-data
        (if (or (is-eq caller (get issuer doc-data)) (is-eq caller (get owner doc-data)))
          (begin
            (map-set shipping-documents
              { document-id: document-id }
              (merge doc-data { status: new-status }))
            (ok true))
          (err u5))
      (err u6))))

;; Get document details
(define-read-only (get-document (document-id (string-ascii 64)))
  (map-get? shipping-documents { document-id: document-id }))

;; Get transfer history
(define-read-only (get-transfer (document-id (string-ascii 64)) (transfer-id (string-ascii 64)))
  (map-get? document-transfers { document-id: document-id, transfer-id: transfer-id }))

;; Check if document is expired
(define-read-only (is-document-expired (document-id (string-ascii 64)))
  (match (map-get? shipping-documents { document-id: document-id })
    doc-data
      (let ((current-time (unwrap-panic (get-block-info? time u0)))
            (expiry (get expiry-date doc-data)))
        (> current-time expiry))
    false))

