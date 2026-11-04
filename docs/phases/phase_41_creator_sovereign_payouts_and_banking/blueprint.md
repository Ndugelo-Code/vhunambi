# Phase 41: Creator Sovereign Royalty Payouts & Banking KYC Sheet
## Architectural Blueprint

### Executive Summary
Phase 41 closes the final high-severity creator monetization defect identified in `FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md` (§5.7). 
In previous releases, when creators earned royalties from beat licensing or track tips (such as the default R1,420.00 earned on their profile), tapping "Cash Out Royalties" presented an incomplete dialog that passed raw method names (e.g. `"Ozow"`, `"Capitec Pay"`) without collecting real bank accounts, branch codes, or account holder names.

Phase 41 introduces the **`PayoutDetailsSheet`**: a production-grade, African-fintech modal supporting South Africa's top banking institutions and instant mobile payment rails, complete with field validation, recipient credential persistence in `CreatorWalletState`, and real-time confirmation notifications in `notificationsProvider`.

---

### Geometry & Interaction Specifications
1. **Modal Geometry**:
   - Pushed via `showModalBottomSheet` with `isScrollControlled: true` and `backgroundColor: Colors.transparent`.
   - Max height constrained to `85vh` with drag-handle pill (`44×4dp`) and `AppRadius.cardBorder` rounded top corners.
   - Dynamic surface coloring via `AppColors.surfaceModalOf(context)`.

2. **Supported Payout Channels**:
   - **EFT Direct**: Standard Bank, FNB, Capitec Bank, Nedbank, Absa Bank, TymeBank.
   - **Capitec Pay**: Mobile phone number linked to Capitec app with instant R-value clearance.
   - **Ozow Instant EFT**: Bank selection + account holder clearance.

3. **Validation & State Persistence**:
   - Account Number: 8–11 numeric digits with real-time numeric keyboard formatting.
   - Branch Code: 6-digit universal clearing code (e.g., `470010` for Capitec, `250655` for FNB, `051001` for Standard Bank) auto-filled based on selected bank.
   - Dispatches a structured `NotificationEntity` into `notificationsProvider` on successful initiation.

