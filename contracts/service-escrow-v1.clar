;; This contract facilitates secure, milestone-based escrow agreements for services.
;; It allows a client to deposit STX into an escrow, which is then released to a
;; service provider upon mutual confirmation of milestone completion. A trusted arbiter
;; is assigned to resolve any disputes.

;; --- Trait Definitions ---
(impl-trait 'STX0000000000000000000000000000000000000000.sip-010-trait-ft-standard.ft-trait)

;; --- Constants and Errors ---
(define-constant ERR-ESCROW-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-ALREADY-FUNDED (err u104))
(define-constant ERR-MILESTONE-NOT-FOUND (err u105))
(define-constant ERR-MILESTONE-ALREADY-PAID (err u106))
(define-constant ERR-ESCROW-CANCELLED (err u107))
(define-constant ERR-ESCROW-COMPLETED (err u108))
(define-constant ERR-NO-MILESTONES (err u109))
(define-constant ERR-INVALID-PRINCIPALS (err u110))

(define-constant CONTRACT-OWNER tx-sender)

;; --- Data Structures ---
(define-map escrows uint {
    client: principal,
    provider: principal,
    arbiter: principal,
    total-amount: uint,
    status: (string-ascii 10), ;; "pending", "funded", "disputed", "completed", "cancelled"
    balance: uint
})

(define-map milestones (tuple uint uint) {
    description: (string-utf8 256),
    amount: uint,
    paid: bool
})

(define-data-var last-escrow-id uint u0)

;; --- SIP-010 Trait Implementation (for contract balance) ---
(define-read-only (get-name)
    (ok "Clarity Escrow Token")
)

(define-read-only (get-symbol)
    (ok "CET")
)

(define-read-only (get-decimals)
    (ok u6)
)

(define-read-only (get-balance (user principal))
    (ok (stx-get-balance user))
)

(define-read-only (get-total-supply)
    (ok u0) ;; Not a fungible token in the traditional sense
)

(define-read-only (get-token-uri)
    (ok none)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
        (try! (stx-transfer? amount sender recipient))
        (print memo)
        (ok true)
    )
)

;; --- Core Escrow Functions ---

;; @desc Creates a new escrow agreement.
;; @param provider The principal of the service provider.
;; @param arbiter The principal of the trusted arbiter.
;; @param total-amount The total amount of STX for the project.
;; @param milestone-amounts A list of amounts for each milestone.
;; @param milestone-descriptions A list of descriptions for each milestone.
;; @returns A response with the ID of the newly created escrow.
(define-public (create-escrow (provider principal) (arbiter principal) (total-amount uint) (milestone-amounts (list 20 uint)) (milestone-descriptions (list 20 (string-utf8 256))))
    (begin
        (asserts! (not (is-eq tx-sender provider)) ERR-INVALID-PRINCIPALS)
        (asserts! (> (len milestone-amounts) u0) ERR-NO-MILESTONES)
        (let
            (
                (escrow-id (+ (var-get last-escrow-id) u1))
                (client tx-sender)
                (sum-milestones (fold + milestone-amounts u0))
            )
            (asserts! (is-eq sum-milestones total-amount) (err u111)) ;; ERR-MILESTONE-SUM-MISMATCH

            (map-set escrows escrow-id {
                client: client,
                provider: provider,
                arbiter: arbiter,
                total-amount: total-amount,
                status: "pending",
                balance: u0
            })

            (fold (lambda (entry idx)
                (map-set milestones
                    { escrow-id: escrow-id, milestone-id: idx }
                    { description: (unwrap! (element-at milestone-descriptions (- idx u1)) (err u0)), amount: entry, paid: false }
                )
                (+ idx u1)
            ) milestone-amounts u1)

            (var-set last-escrow-id escrow-id)
            (print { event: "create-escrow", escrow-id: escrow-id, client: client, provider: provider })
            (ok escrow-id)
        )
    )
)

;; @desc The client deposits the total STX amount into the escrow contract.
;; @param escrow-id The ID of the escrow to fund.
;; @returns A boolean response indicating success.
(define-public (fund-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
            (total-amount (get total-amount escrow))
        )
        (asserts! (is-eq tx-sender (get client escrow)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status escrow) "pending") ERR-INVALID-STATUS)

        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

        (map-set escrows escrow-id (merge escrow { status: "funded", balance: total-amount }))
        (print { event: "fund-escrow", escrow-id: escrow-id, amount: total-amount })
        (ok true)
    )
)

;; @desc Releases funds for a completed milestone. Only the client can approve this.
;; @param escrow-id The ID of the escrow.
;; @param milestone-id The ID of the milestone to release funds for.
;; @returns A boolean response indicating success.
(define-public (release-milestone-payment (escrow-id uint) (milestone-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
            (milestone (unwrap! (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
            (client (get client escrow))
            (provider (get provider escrow))
            (amount (get amount milestone))
            (current-balance (get balance escrow))
        )
        (asserts! (is-eq tx-sender client) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status escrow) "funded") ERR-INVALID-STATUS)
        (asserts! (not (get paid milestone)) ERR-MILESTONE-ALREADY-PAID)
        (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)

        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) provider)))

        (map-set milestones { escrow-id: escrow-id, milestone-id: milestone-id } (merge milestone { paid: true }))
        (map-set escrows escrow-id (merge escrow { balance: (- current-balance amount) }))

        (print { event: "release-milestone", escrow-id: escrow-id, milestone-id: milestone-id, amount: amount })

        ;; Check if all milestones are paid to complete the escrow
        (if (is-eq u0 (- current-balance amount))
            (begin
                (map-set escrows escrow-id (merge escrow { status: "completed", balance: u0 }))
                (print { event: "complete-escrow", escrow-id: escrow-id })
            )
            true
        )

        (ok true)
    )
)

;; @desc Cancels the escrow before it is completed. Can only be called by the client
;; if no funds have been released, or by the arbiter in a dispute.
;; @param escrow-id The ID of the escrow to cancel.
;; @returns A boolean response indicating success.
(define-public (cancel-escrow (escrow-id uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
            (client (get client escrow))
            (status (get status escrow))
            (balance (get balance escrow))
        )
        (asserts! (or (is-eq tx-sender client) (is-eq tx-sender (get arbiter escrow))) ERR-UNAUTHORIZED)
        (asserts! (or (is-eq status "funded") (is-eq status "disputed")) ERR-INVALID-STATUS)

        (if (> balance u0)
            (try! (as-contract (stx-transfer? balance (as-contract tx-sender) client)))
            (print { event: "cancel-no-refund", escrow-id: escrow-id })
        )

        (map-set escrows escrow-id (merge escrow { status: "cancelled", balance: u0 }))
        (print { event: "cancel-escrow", escrow-id: escrow-id, refund: balance })
        (ok true)
    )
)

;; @desc The arbiter resolves a dispute, splitting funds between client and provider.
;; @param escrow-id The ID of the disputed escrow.
;; @param amount-to-client The amount to refund to the client.
;; @param amount-to-provider The amount to pay the provider.
;; @returns A boolean response indicating success.
(define-public (resolve-dispute (escrow-id uint) (amount-to-client uint) (amount-to-provider uint))
    (let
        (
            (escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND))
            (balance (get balance escrow))
        )
        (asserts! (is-eq tx-sender (get arbiter escrow)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status escrow) "disputed") ERR-INVALID-STATUS)
        (asserts! (is-eq (+ amount-to-client amount-to-provider) balance) (err u112)) ;; ERR-INVALID-SPLIT

        (if (> amount-to-client u0)
            (try! (as-contract (stx-transfer? amount-to-client (as-contract tx-sender) (get client escrow))))
            true
        )
        (if (> amount-to-provider u0)
            (try! (as-contract (stx-transfer? amount-to-provider (as-contract tx-sender) (get provider escrow))))
            true
        )

        (map-set escrows escrow-id (merge escrow { status: "completed", balance: u0 }))
        (print { event: "resolve-dispute", escrow-id: escrow-id, to-client: amount-to-client, to-provider: amount-to-provider })
        (ok true)
    )
)

;; @desc Marks an escrow as disputed. Can be called by client or provider.
;; @param escrow-id The ID of the escrow.
;; @returns A boolean response indicating success.
(define-public (raise-dispute (escrow-id uint))
    (let
        ((escrow (unwrap! (map-get? escrows escrow-id) ERR-ESCROW-NOT-FOUND)))
        (asserts! (or (is-eq tx-sender (get client escrow)) (is-eq tx-sender (get provider escrow))) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status escrow) "funded") ERR-INVALID-STATUS)
        (map-set escrows escrow-id (merge escrow { status: "disputed" }))
        (print { event: "raise-dispute", escrow-id: escrow-id, by: tx-sender })
        (ok true)
    )
)


;; --- Read-Only Functions ---

;; @desc Retrieves the details of a specific escrow.
;; @param escrow-id The ID of the escrow.
;; @returns An optional escrow object.
(define-read-only (get-escrow-details (escrow-id uint))
    (map-get? escrows escrow-id)
)

;; @desc Retrieves the details of a specific milestone.
;; @param escrow-id The ID of the escrow.
;; @param milestone-id The ID of the milestone.
;; @returns An optional milestone object.
(define-read-only (get-milestone-details (escrow-id uint) (milestone-id uint))
    (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id })
)

;; @desc Returns the current ID counter for escrows.
;; @returns The last escrow ID used.
(define-read-only (get-last-escrow-id)
  (var-get last-escrow-id)
)