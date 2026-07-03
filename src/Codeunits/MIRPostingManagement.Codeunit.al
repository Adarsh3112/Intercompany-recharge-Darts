codeunit 50103 "MIR Posting Management"
{
    // MIR Posting Management
    // ----------------------
    // Posts an Approved MIR Recharge Header by:
    //   1. CheckNotAlreadyPosted     — blocks duplicate posting by inspecting the
    //                              MIR Recharge Ledger Entry table for any prior
    //                              row keyed by this Header's Document No.
    //   2. Status guard           — refuses anything but Status::Approved.
    //   3. GetJournalTemplateAndBatch — auto-creates the MIR Setup singleton and
    //                              reads the configured IC Journal Template/Batch.
    //   4. BuildICOutboxLines     — per allocation line on the request, writes one
    //                              partner-side IC Outbox Jnl. Line (debit) plus
    //                              ensures the matching IC Outbox Transaction
    //                              (the envelope row) per allocation line. The
    //                              tables are keyed by (Transaction No., IC Partner
    //                              Code, Transaction Source, Line No.) — note there
    //                              is NO Journal Template / Batch / Posting Date on
    //                              table 415 itself; those live on the parent
    //                              IC Outbox Transaction.
    //   5. InsertBalancingCreditLine — one credit row against the IC Journal Batch's
    //                              Bal. Account No. so sum(Amount) for the Document
    //                              No. = 0. Posted under the first partner header so
    //                              the FK keys remain valid.
    //   6. InsertLedgerEntries    — one row per allocation line in MIR Recharge
    //                              Ledger Entry, capturing Document No., Partner
    //                              Code, Amount, Amount LCY, Currency Code, Posting
    //                              Date, GL Account, Target IC GL Acc., and the
    //                              audit metadata (Posted By, Posted At, etc.). The
    //                              next duplicate-post attempt will see these rows.
    //   7. StatusMgt.SetPosted    — only the Status Mgt codeunit is allowed to mutate
    //                              MIR Recharge Header.Status per existing convention.
    //
    // The codeunit contains ZERO calls to ChangeCompany(). Cross-company communication
    // happens through the IC Outbox table — BC's native intercompany channel that the
    // platform's IC Outbox processor delivers to the partner company.

    var
        NotApprovedErr: Label 'MIR Recharge Request %1 cannot be posted because its status is %2. Only Approved requests can be posted.', Comment = '%1 = document number, %2 = current status';
        AlreadyPostedErr: Label 'MIR Recharge Request %1 has already been posted. Duplicate posting is not allowed. Reverse the existing posting before posting again.', Comment = '%1 = document number';
        SetupTemplateMissingErr: Label 'Configure ''%1'' on the MIR Setup page before posting MIR Recharge Request %2.', Comment = '%1 = field caption, %2 = document number';
        SetupBatchMissingErr: Label 'Configure ''%1'' on the MIR Setup page before posting MIR Recharge Request %2.', Comment = '%1 = field caption, %2 = document number';
        BalAccountMissingErr: Label 'The Gen. Journal Batch ''%1'' / ''%2'' has no Bal. Account No. configured. Set a Bal. Account No. on the batch (or configure a different IC Journal Batch on the MIR Setup page) before posting MIR Recharge Request %3.', Comment = '%1 = template, %2 = batch, %3 = document number';
        NoLinesErr: Label 'MIR Recharge Request %1 has no allocation lines with a positive Calculated Amount. Add at least one line with a non-zero amount before posting.', Comment = '%1 = document number';

    /// <summary>
    /// Post an Approved MIR Recharge Header. Generates balanced IC Outbox journal
    /// lines, records one immutable MIR Recharge Ledger Entry row per allocation
    /// line, and flips the Header status to Posted via the Status Mgt codeunit.
    /// Duplicate calls on the same Header are blocked with a hard Error before any
    /// side effect occurs.
    /// </summary>
    procedure PostRechargeRequest(var Header: Record "MIR Recharge Header")
    var
        StatusMgt: Codeunit "MIR Recharge Status Mgt";
        TemplateName: Code[10];
        BatchName: Code[10];
        GLAccountNo: Code[20];
        TotalDebit: Decimal;
        ICDocumentNo: Code[20];
        TransactionNo: Integer;
        FirstPartner: Code[20];
    begin
        // (1) Duplicate-post guard. MUST run before any IC Outbox or Ledger write
        // AND before the status guard, so that a re-submission of an already-posted
        // Header surfaces the 'already been posted' message regardless of whether the
        // in-memory Status still reads Approved or has been refreshed to Posted.
        CheckNotAlreadyPosted(Header."No.");

        // (2) Status guard. StatusMgt.SetPosted re-checks this, but failing here gives
        // a clearer user error and avoids partial work if a non-Approved doc is passed.
        if Header.Status <> Header.Status::Approved then
            Error(NotApprovedErr, Header."No.", Header.Status);

        // (3) Setup load + TestField equivalent.
        GetJournalTemplateAndBatch(Header, TemplateName, BatchName, GLAccountNo);

        // The IC Document No. ties the IC Outbox rows to the Header. Use the Header No.
        // verbatim so auditors can correlate without a lookup.
        ICDocumentNo := Header."No.";

        // Allocate a single fresh IC Transaction No. for this whole post.
        TransactionNo := GetNextICTransactionNo();

        // (4) Build per-line debit rows in IC Outbox Jnl. Line plus the per-partner
        //     IC Outbox Transaction headers that own them.
        BuildICOutboxLines(Header, ICDocumentNo, TransactionNo, TotalDebit, FirstPartner);

        // (5) Single balancing credit row so sum(Amount) for the Document No. = 0.
        InsertBalancingCreditLine(Header, TemplateName, BatchName, ICDocumentNo, TransactionNo, FirstPartner, TotalDebit);

        // (6) Audit rows — one per allocation line. Insert(true) so AutoIncrement
        // assigns Entry No. The next duplicate-post attempt will hit these rows in
        // CheckNotAlreadyPosted via the DocumentNo secondary key.
        InsertLedgerEntries(Header, TemplateName, BatchName, ICDocumentNo, GLAccountNo);

        // (7) Delegate the status mutation. Only the Status Mgt codeunit is allowed
        // to change MIR Recharge Header.Status — established codebase convention.
        StatusMgt.SetPosted(Header);
    end;

    local procedure CheckNotAlreadyPosted(RequestNo: Code[20])
    var
        LedgerEntry: Record "MIR Recharge Ledger Entry";
    begin
        // Document No. on the ledger row equals the source Header No., so a single
        // SetRange + IsEmpty against the DocumentNo secondary key is enough to detect
        // any prior posting attempt for the same request.
        LedgerEntry.SetRange("Document No.", RequestNo);
        if not LedgerEntry.IsEmpty() then
            Error(AlreadyPostedErr, RequestNo);
    end;

    local procedure GetJournalTemplateAndBatch(Header: Record "MIR Recharge Header"; var TemplateName: Code[10]; var BatchName: Code[10]; var GLAccountNo: Code[20])
    var
        MIRSetup: Record "MIR Setup";
        GenJournalBatch: Record "Gen. Journal Batch";
    begin
        // GetSetup() auto-creates the singleton if missing so first-time posting does
        // not fail with "record not found" — the user instead gets a clear message that
        // the template/batch fields need to be configured.
        MIRSetup.GetSetup();

        if MIRSetup."IC Journal Template" = '' then
            Error(SetupTemplateMissingErr, MIRSetup.FieldCaption("IC Journal Template"), Header."No.");
        if MIRSetup."IC Journal Batch" = '' then
            Error(SetupBatchMissingErr, MIRSetup.FieldCaption("IC Journal Batch"), Header."No.");

        TemplateName := MIRSetup."IC Journal Template";
        BatchName := MIRSetup."IC Journal Batch";

        // The local G/L account that the recharge debit posts against on the source
        // side. We surface the configured Bal. Account No. on the IC Journal Batch as
        // the canonical "GL Account" for the audit row so the ledger entry tells the
        // full story (source side and target side both visible).
        GLAccountNo := '';
        if GenJournalBatch.Get(TemplateName, BatchName) then
            GLAccountNo := GenJournalBatch."Bal. Account No.";
    end;

    local procedure BuildICOutboxLines(var Header: Record "MIR Recharge Header"; ICDocumentNo: Code[20]; TransactionNo: Integer; var TotalDebit: Decimal; var FirstPartner: Code[20])
    var
        Line: Record "MIR Recharge Line";
        ICOutboxLine: Record "IC Outbox Jnl. Line";
        NextLineNo: Integer;
        LineCount: Integer;
    begin
        TotalDebit := 0;
        NextLineNo := 10000;
        LineCount := 0;
        FirstPartner := '';

        Line.SetRange("Document No.", Header."No.");
        Line.SetCurrentKey("Document No.", "Line No.");
        if Line.FindSet() then
            repeat
                if Line."Calculated Amount" > 0 then begin
                    // Ensure the IC Outbox Transaction header for this partner exists.
                    // BC's IC Outbox processor uses this row as the envelope for the
                    // child journal lines that belong to the same (Transaction No.,
                    // IC Partner Code, Transaction Source, Document Type) tuple.
                    EnsureICOutboxTransaction(TransactionNo, Line."Target Partner", ICDocumentNo, Header."Posting Date", Line."Target IC GL Acc.");

                    if FirstPartner = '' then
                        FirstPartner := Line."Target Partner";

                    ICOutboxLine.Init();
                    ICOutboxLine."Transaction No." := TransactionNo;
                    ICOutboxLine."IC Partner Code" := Line."Target Partner";
                    ICOutboxLine."Transaction Source" := ICOutboxLine."Transaction Source"::"Created by Current Company";
                    ICOutboxLine."Line No." := NextLineNo;
                    ICOutboxLine."Document No." := ICDocumentNo;
                    ICOutboxLine."Account Type" := ICOutboxLine."Account Type"::"G/L Account";
                    ICOutboxLine."Account No." := Line."Target IC GL Acc.";
                    ICOutboxLine."Currency Code" := Header."Currency Code";
                    ICOutboxLine.Amount := Line."Calculated Amount";
                    ICOutboxLine.Description := CopyStr(Header.Description, 1, MaxStrLen(ICOutboxLine.Description));
                    ICOutboxLine.Insert(true);

                    TotalDebit += Line."Calculated Amount";
                    NextLineNo += 10000;
                    LineCount += 1;
                end;
            until Line.Next() = 0;

        if LineCount = 0 then
            Error(NoLinesErr, Header."No.");
    end;

    local procedure EnsureICOutboxTransaction(TransactionNo: Integer; PartnerCode: Code[20]; ICDocumentNo: Code[20]; PostingDate: Date; ICAccountNo: Code[20])
    var
        ICOutboxTransaction: Record "IC Outbox Transaction";
    begin
        // The IC Outbox Transaction is keyed by
        //   (Transaction No., IC Partner Code, Transaction Source, Document Type)
        // — one row per partner is sufficient for an Invoice-type intercompany
        // recharge. Skip the insert if the row already exists so a request that
        // allocates multiple lines to the same partner only produces one header.
        if ICOutboxTransaction.Get(TransactionNo, PartnerCode, ICOutboxTransaction."Transaction Source"::"Created by Current Company", ICOutboxTransaction."Document Type"::Invoice) then
            exit;

        ICOutboxTransaction.Init();
        ICOutboxTransaction."Transaction No." := TransactionNo;
        ICOutboxTransaction."IC Partner Code" := PartnerCode;
        ICOutboxTransaction."Transaction Source" := ICOutboxTransaction."Transaction Source"::"Created by Current Company";
        ICOutboxTransaction."IC Source Type" := ICOutboxTransaction."IC Source Type"::Journal;
        ICOutboxTransaction."Document Type" := ICOutboxTransaction."Document Type"::Invoice;
        ICOutboxTransaction."Document No." := ICDocumentNo;
        ICOutboxTransaction."Posting Date" := PostingDate;
        ICOutboxTransaction."Document Date" := PostingDate;
        ICOutboxTransaction."IC Account Type" := ICOutboxTransaction."IC Account Type"::"G/L Account";
        ICOutboxTransaction."IC Account No." := ICAccountNo;
        ICOutboxTransaction.Insert(true);
    end;

    local procedure InsertBalancingCreditLine(Header: Record "MIR Recharge Header"; TemplateName: Code[10]; BatchName: Code[10]; ICDocumentNo: Code[20]; TransactionNo: Integer; FirstPartner: Code[20]; TotalDebit: Decimal)
    var
        ICOutboxLine: Record "IC Outbox Jnl. Line";
        GenJournalBatch: Record "Gen. Journal Batch";
        NextLineNo: Integer;
    begin
        // Read the configured batch to discover the Bal. Account on which the credit
        // posting offsets the partner-side debits. Without a Bal. Account the journal
        // would not balance, so this is a hard prerequisite that the user must address
        // on the Gen. Journal Batch page.
        GenJournalBatch.Get(TemplateName, BatchName);
        if GenJournalBatch."Bal. Account No." = '' then
            Error(BalAccountMissingErr, TemplateName, BatchName, Header."No.");

        // Append the credit line at the end of the journal under the first partner's
        // IC Outbox Transaction so the (Transaction No., IC Partner Code, Transaction
        // Source, Line No.) PK remains unique. We pick the largest existing Line No.
        // for this Transaction No. + Partner and add 10000 — the standard BC idiom.
        ICOutboxLine.SetRange("Transaction No.", TransactionNo);
        ICOutboxLine.SetRange("IC Partner Code", FirstPartner);
        ICOutboxLine.SetRange("Transaction Source", ICOutboxLine."Transaction Source"::"Created by Current Company");
        if ICOutboxLine.FindLast() then
            NextLineNo := ICOutboxLine."Line No." + 10000
        else
            NextLineNo := 10000;

        ICOutboxLine.Init();
        ICOutboxLine."Transaction No." := TransactionNo;
        ICOutboxLine."IC Partner Code" := FirstPartner;
        ICOutboxLine."Transaction Source" := ICOutboxLine."Transaction Source"::"Created by Current Company";
        ICOutboxLine."Line No." := NextLineNo;
        ICOutboxLine."Document No." := ICDocumentNo;
        // The balancing leg is a local G/L Account posting — Account Type is therefore
        // "G/L Account" regardless of the batch's Bal. Account Type option value, which
        // may not map 1:1 onto the IC Outbox Jnl. Line option set. The Bal. Account No.
        // from the batch is the actual ledger account that absorbs the offset.
        ICOutboxLine."Account Type" := ICOutboxLine."Account Type"::"G/L Account";
        ICOutboxLine."Account No." := GenJournalBatch."Bal. Account No.";
        ICOutboxLine."Currency Code" := Header."Currency Code";
        // Credit row carries the negated sum so debits + credit = 0 for the Doc No.
        ICOutboxLine.Amount := -TotalDebit;
        ICOutboxLine.Description := CopyStr(Header.Description, 1, MaxStrLen(ICOutboxLine.Description));
        ICOutboxLine.Insert(true);
    end;

    local procedure InsertLedgerEntries(Header: Record "MIR Recharge Header"; TemplateName: Code[10]; BatchName: Code[10]; ICDocumentNo: Code[20]; GLAccountNo: Code[20])
    var
        Line: Record "MIR Recharge Line";
        LedgerEntry: Record "MIR Recharge Ledger Entry";
        ExchangeRate: Decimal;
        AmountLCY: Decimal;
    begin
        // Pre-compute the FX rate once per post. For LCY postings the helper returns
        // 1; for foreign currency it reads the standard BC Currency Exchange Rate at
        // the Header's Posting Date.
        ExchangeRate := GetExchangeRate(Header."Currency Code", Header."Posting Date");

        Line.SetRange("Document No.", Header."No.");
        Line.SetCurrentKey("Document No.", "Line No.");
        if Line.FindSet() then
            repeat
                // Only write a ledger row for lines that actually contributed to the
                // posting — this mirrors the BuildICOutboxLines filter so the ledger
                // and the IC Outbox stay in lockstep.
                if Line."Calculated Amount" > 0 then begin
                    AmountLCY := Round(Line."Calculated Amount" * ExchangeRate, 0.01);

                    LedgerEntry.Init();
                    // Entry No. is AutoIncrement; do not assign it manually.
                    LedgerEntry."Document No." := Header."No.";
                    LedgerEntry."Partner Code" := Line."Target Partner";
                    LedgerEntry.Amount := Line."Calculated Amount";
                    LedgerEntry."Amount LCY" := AmountLCY;
                    LedgerEntry."Currency Code" := Header."Currency Code";
                    LedgerEntry."Posting Date" := Header."Posting Date";
                    LedgerEntry."GL Account" := GLAccountNo;
                    LedgerEntry."Target IC GL Acc." := Line."Target IC GL Acc.";
                    LedgerEntry."Posted By" := CopyStr(UserId(), 1, MaxStrLen(LedgerEntry."Posted By"));
                    LedgerEntry."Posted At" := CurrentDateTime();
                    LedgerEntry."IC Document No." := ICDocumentNo;
                    LedgerEntry."Journal Template Name" := TemplateName;
                    LedgerEntry."Journal Batch Name" := BatchName;
                    // Insert(true) so AutoIncrement assigns Entry No. and the table's
                    // OnInsert (if any) runs — note the OnModify / OnDelete immutability
                    // triggers do NOT fire on Insert, which is the only legitimate write.
                    LedgerEntry.Insert(true);
                end;
            until Line.Next() = 0;
    end;

    local procedure GetExchangeRate(CurrencyCode: Code[10]; PostingDate: Date): Decimal
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        ExchAmount: Decimal;
    begin
        // LCY postings: the conversion is a no-op. Return 1 so AmountLCY = Amount.
        if CurrencyCode = '' then
            exit(1);

        // Foreign currency: use the standard BC Currency Exchange Rate machinery.
        // ExchangeRate (LCY per FCY) = "Relational Exch. Rate Amount" / "Exchange Rate Amount".
        // We look up the most recent rate row at or before PostingDate, mirroring how
        // the platform's Currency Exchange Rate codeunit resolves a rate.
        CurrencyExchangeRate.SetRange("Currency Code", CurrencyCode);
        CurrencyExchangeRate.SetRange("Starting Date", 0D, PostingDate);
        if CurrencyExchangeRate.FindLast() then
            if CurrencyExchangeRate."Exchange Rate Amount" <> 0 then begin
                ExchAmount := CurrencyExchangeRate."Relational Exch. Rate Amount" / CurrencyExchangeRate."Exchange Rate Amount";
                exit(ExchAmount);
            end;

        // No rate configured: fall back to 1 rather than blocking the post. The
        // resulting AmountLCY equals Amount, which is a documented degenerate case
        // an auditor can detect by comparing Currency Code <> '' with Amount = LCY.
        exit(1);
    end;

    local procedure GetNextICTransactionNo(): Integer
    var
        ICOutboxTransaction: Record "IC Outbox Transaction";
        HandledICOutboxTrans: Record "Handled IC Outbox Trans.";
        Candidate: Integer;
    begin
        // Allocate the next free IC Transaction No. by inspecting both the active
        // outbox and the handled-outbox archive — Transaction No. is a strictly
        // monotonic counter across the lifetime of the company and the platform
        // re-uses it when reconciling against the partner's inbox.
        Candidate := 0;
        if ICOutboxTransaction.FindLast() then
            Candidate := ICOutboxTransaction."Transaction No.";
        if HandledICOutboxTrans.FindLast() then
            if HandledICOutboxTrans."Transaction No." > Candidate then
                Candidate := HandledICOutboxTrans."Transaction No.";
        exit(Candidate + 1);
    end;
}
