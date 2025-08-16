;; This contract facilitates secure, milestone-based escrow agreements for services.
;; It allows a client to deposit STX into an escrow, which is then released to a
;; service provider upon mutual confirmation of milestone completion. A trusted arbiter
;; is assigned to resolve any disputes.

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
(define-constant ERR-MILESTONE-SUM-MISMATCH (err u111))
(define-constant ERR-INVALID-SPLIT (err u112))
(define-constant ERR-ZERO-AMOUNT (err u113))
(define-constant ERR-TOO-MANY-MILESTONES (err u114))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-MILESTONES u20)

;; --- Data Structures ---
(define-map escrows uint {
    client: principal,
    provider: principal,
    arbiter: principal,
    total-amount: uint,
    status: (string-ascii 10), ;; "pending", "funded", "disputed", "completed", "cancelled"
    balance: uint,
    milestones-count: uint
})

(define-map milestones { escrow-id: uint, milestone-id: uint } {
    description: (string-utf8 256),
    amount: uint,
    paid: bool
})

(define-data-var last-escrow-id uint u0)

;; --- Helper Functions ---

;; @desc Calculates the sum of a list of amounts
;; @param amounts List of uint amounts
;; @returns Total sum
(define-private (sum-list (amounts (list 20 uint)))
    (fold + amounts u0)
)

;; @desc Validates that milestone amounts and descriptions have the same length
;; @param amounts List of milestone amounts
;; @param descriptions List of milestone descriptions
;; @returns Boolean indicating if lengths match
(define-private (validate-milestone-data (amounts (list 20 uint)) (descriptions (list 20 (string-utf8 256))))
    (is-eq (len amounts) (len descriptions))
)

;; @desc Adds milestones to the contract storage
;; @param escrow-id The escrow ID
;; @param amounts List of milestone amounts
;; @param descriptions List of milestone descriptions
;; @param start-index Starting milestone index
;; @returns Boolean success
(define-private (add-milestones (escrow-id uint) (amounts (list 20 uint)) (descriptions (list 20 (string-utf8 256))) (start-index uint))
    (let
        (
            (milestone-pairs (zip amounts descriptions))
        )
        (fold add-single-milestone milestone-pairs { escrow-id: escrow-id, index: start-index })
        true
    )
)

;; @desc Adds a single milestone
;; @param milestone-data Tuple containing amount and description
;; @param state Current state with escrow-id and index
;; @returns Updated state
(define-private (add-single-milestone (milestone-data { amount: uint, description: (string-utf8 256) }) (state { escrow-id: uint, index: uint }))
    (let
        (
            (escrow-id (get escrow-id state))
            (current-index (get index state))
        )
        (map-set milestones 
            { escrow-id: escrow-id, milestone-id: current-index }
            { 
                description: (get description milestone-data), 
                amount: (get amount milestone-data), 
                paid: false 
            }
        )
        { escrow-id: escrow-id, index: (+ current-index u1) }
    )
)

;; @desc Checks if all milestones are paid for an escrow
;; @param escrow-id The escrow ID
;; @param milestone-count Total number of milestones
;; @returns Boolean indicating if all are paid
(define-private (all-milestones-paid (escrow-id uint) (milestone-count uint))
    (check-milestones-paid-recursive escrow-id u1 milestone-count)
)

;; @desc Recursively checks if milestones are paid
;; @param escrow-id The escrow ID
;; @param current-milestone Current milestone being checked
;; @param max-milestone Maximum milestone to check
;; @returns Boolean indicating if all checked milestones are paid
(define-private (check-milestones-paid-recursive (escrow-id uint) (current-milestone uint) (max-milestone uint))
    (if (<= current-milestone max-milestone)
        (let
            (
                (milestone-opt (map-get? milestones { escrow-id: escrow-id, milestone-id: current-milestone }))
            )
            (match milestone-opt
                milestone (if (get paid milestone)
                            (check-milestones-paid-recursive escrow-id (+ current-milestone u1) max-milestone)
                            false)
                false
            )
        )
        true
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
(define-public (create-escrow 
    (provider principal) 
    (arbiter principal) 
    (total-amount uint) 
    (milestone-amounts (list 20 uint)) 
    (milestone-descriptions (list 20 (string-utf8 256))))
    (let
        (
            (escrow-id (+ (var-get last-escrow-id) u1))
            (client tx-sender)
            (milestone-count (len milestone-amounts))
            (sum-milestones (sum-list milestone-amounts))
        )
        ;; Input validation
        (asserts! (not (is-eq client provider)) ERR-INVALID-PRINCIPALS)
        (asserts! (not (is-eq client arbiter)) ERR-INVALID-PRINCIPALS)
        (asserts! (not (is-eq provider arbiter)) ERR-INVALID-PRINCIPALS)
        (asserts! (> milestone-count u0) ERR-NO-MILESTONES)
        (asserts! (<= milestone-count MAX-MILESTONES) ERR-TOO-MANY-MILESTONES)
        (asserts! (> total-amount u0) ERR-ZERO-AMOUNT)
        (asserts! (is-eq sum-milestones total-amount) ERR-MILESTONE-SUM-MISMATCH)
        (asserts! (validate-milestone-data milestone-amounts milestone-descriptions) ERR-MILESTONE-SUM-MISMATCH)

        ;; Create escrow entry
        (map-set escrows escrow-id {
            client: client,
            provider: provider,
            arbiter: arbiter,
            total-amount: total-amount,
            status: "pending",
            balance: u0,
            milestones-count: milestone-count
        })

        ;; Add milestones
        (add-milestones escrow-id milestone-amounts milestone-descriptions u1)

        (var-set last-escrow-id escrow-id)
        (print { event: "create-escrow", escrow-id: escrow-id, client: client, provider: provider, total-amount: total-amount })
        (ok escrow-id)
    )
)

;; @desc The client deposits the total STX amount into the escrow contract.
;; @param escrow-id The ID of the escrow to fund.
;; @returns A boolean response indicating success.
(define-public (fund-escrow (escrow-id uint))
    (let
        (
            (escrow-opt (map-get? escrows escrow-id))
        )
        (match escrow-opt
            escrow
            (let
                (
                    (total-amount (get total-amount escrow))
                    (client (get client escrow))
                    (status (get status escrow))
                )
                (asserts! (is-eq tx-sender client) ERR-UNAUTHORIZED)
                (asserts! (is-eq status "pending") ERR-INVALID-STATUS)

                (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

                (map-set escrows escrow-id (merge escrow { status: "funded", balance: total-amount }))
                (print { event: "fund-escrow", escrow-id: escrow-id, amount: total-amount })
                (ok true)
            )
            ERR-ESCROW-NOT-FOUND
        )
    )
)

;; @desc Releases funds for a completed milestone. Only the client can approve this.
;; @param escrow-id The ID of the escrow.
;; @param milestone-id The ID of the milestone to release funds for.
;; @returns A boolean response indicating success.
(define-public (release-milestone-payment (escrow-id uint) (milestone-id uint))
    (let
        (
            (escrow-opt (map-get? escrows escrow-id))
            (milestone-opt (map-get? milestones { escrow-id: escrow-id, milestone-id: milestone-id }))
        )
        (match escrow-opt
            escrow
            (match milestone-opt
                milestone
                (let
                    (
                        (client (get client escrow))
                        (provider (get provider escrow))
                        (amount (get amount milestone))
                        (current-balance (get balance escrow))
                        (milestone-count (get milestones-count escrow))
                        (new-balance (- current-balance amount))
                    )
                    (asserts! (is-eq tx-sender client) ERR-UNAUTHORIZED)
                    (asserts! (is-eq (get status escrow) "funded") ERR-INVALID-STATUS)
                    (asserts! (not (get paid milestone)) ERR-MILESTONE-ALREADY-PAID)
                    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)

                    (try! (as-contract (stx-transfer? amount tx-sender provider)))

                    (map-set milestones { escrow-id: escrow-id, milestone-id: milestone-id } 
                        (merge milestone { paid: true }))

                    (let
                        (
                            (updated-escrow (merge escrow { balance: new-balance }))
                        )
                        (if (and (is-eq new-balance u0) (all-milestones-paid escrow-id milestone-count))
                            (begin
                                (map-set escrows escrow-id (merge updated-escrow { status: "completed" }))
                                (print { event: "complete-escrow", escrow-id: escrow-id })
                            )
                            (map-set escrows escrow-id updated-escrow)
                        )
                    )

                    (print { event: "release-milestone", escrow-id: escrow-id, milestone-id: milestone-id, amount: amount })
                    (ok true)
                )
                ERR-MILESTONE-NOT-FOUND
            )
            ERR-ESCROW-NOT-FOUND
        )
    )
)

;; @desc Cancels the escrow before it is completed. Can only be called by the client
;; if no funds have been released, or by the arbiter in a dispute.
;; @param escrow-id The ID of the escrow to cancel.
;; @returns A boolean response indicating success.
(define-public (cancel-escrow (escrow-id uint))
    (let
        (
            (escrow-opt (map-get? escrows escrow-id))
        )
        (match escrow-opt
            escrow
            (let
                (
                    (client (get client escrow))
                    (arbiter (get arbiter escrow))
                    (status (get status escrow))
                    (balance (get balance escrow))
                )
                (asserts! (or (is-eq tx-sender client) (is-eq tx-sender arbiter)) ERR-UNAUTHORIZED)
                (asserts! (or (is-eq status "funded") (is-eq status "disputed") (is-eq status "pending")) ERR-INVALID-STATUS)

                (if (> balance u0)
                    (try! (as-contract (stx-transfer? balance tx-sender client)))
                    true
                )

                (map-set escrows escrow-id (merge escrow { status: "cancelled", balance: u0 }))
                (print { event: "cancel-escrow", escrow-id: escrow-id, refund: balance })
                (ok true)
            )
            ERR-ESCROW-NOT-FOUND
        )
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
            (escrow-opt (map-get? escrows escrow-id))
        )
        (match escrow-opt
            escrow
            (let
                (
                    (balance (get balance escrow))
                    (client (get client escrow))
                    (provider (get provider escrow))
                    (arbiter (get arbiter escrow))
                )
                (asserts! (is-eq tx-sender arbiter) ERR-UNAUTHORIZED)
                (asserts! (is-eq (get status escrow) "disputed") ERR-INVALID-STATUS)
                (asserts! (is-eq (+ amount-to-client amount-to-provider) balance) ERR-INVALID-SPLIT)

                (if (> amount-to-client u0)
                    (try! (as-contract (stx-transfer? amount-to-client tx-sender client)))
                    true
                )
                (if (> amount-to-provider u0)
                    (try! (as-contract (stx-transfer? amount-to-provider tx-sender provider)))
                    true
                )

                (map-set escrows escrow-id (merge escrow { status: "completed", balance: u0 }))
                (print { event: "resolve-dispute", escrow-id: escrow-id, to-client: amount-to-client, to-provider: amount-to-provider })
                (ok true)
            )
            ERR-ESCROW-NOT-FOUND
        )
    )
)

;; @desc Marks an escrow as disputed. Can be called by client or provider.
;; @param escrow-id The ID of the escrow.
;; @returns A boolean response indicating success.
(define-public (raise-dispute (escrow-id uint))
    (let
        (
            (escrow-opt (map-get? escrows escrow-id))
        )
        (match escrow-opt
            escrow
            (let
                (
                    (client (get client escrow))
                    (provider (get provider escrow))
                    (status (get status escrow))
                )
                (asserts! (or (is-eq tx-sender client) (is-eq tx-sender provider)) ERR-UNAUTHORIZED)
                (asserts! (is-eq status "funded") ERR-INVALID-STATUS)

                (map-set escrows escrow-id (merge escrow { status: "disputed" }))
                (print { event: "raise-dispute", escrow-id: escrow-id, by: tx-sender })
                (ok true)
            )
            ERR-ESCROW-NOT-FOUND
        )
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

;; @desc Gets all milestone details for an escrow (up to MAX_MILESTONES).
;; @param escrow-id The ID of the escrow.
;; @returns List of milestone details.
(define-read-only (get-escrow-milestones (escrow-id uint))
    (let
        (
            (escrow-opt (map-get? escrows escrow-id))
        )
        (match escrow-opt
            escrow
            (let
                (
                    (milestone-count (get milestones-count escrow))
                )
                (some (get-milestones-recursive escrow-id u1 milestone-count (list)))
            )
            none
        )
    )
)

;; @desc Recursively gets milestone details.
;; @param escrow-id The escrow ID.
;; @param current Current milestone index.
;; @param max Maximum milestone index.
;; @param acc Accumulator list.
;; @returns List of milestone details.
(define-private (get-milestones-recursive (escrow-id uint) (current uint) (max uint) (acc (list 20 (optional { description: (string-utf8 256), amount: uint, paid: bool }))))
    (if (<= current max)
        (let
            (
                (milestone-opt (map-get? milestones { escrow-id: escrow-id, milestone-id: current }))
                (updated-acc (unwrap! (as-max-len? (append acc milestone-opt) u20) acc))
            )
            (get-milestones-recursive escrow-id (+ current u1) max updated-acc)
        )
        acc
    )
)

;; @desc Gets the contract balance
;; @returns Current STX balance held by the contract
(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)