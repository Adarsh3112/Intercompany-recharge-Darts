codeunit 50101 "IC Recharge Post Management"
{
    /// <summary>
    /// Main posting entry point.  Called from ICRechargeRequestHeader.AdvanceStatus()
    /// when the document transitions from Approved to Posted.
    ///
    /// Steps performed:
    ///   1. Duplicate-posting guard — raises an error if the Posted flag is already TRUE.
    ///   2. Validates minimum prerequisites (Posting Date, IC Partner Code, lines present).
    ///   3. Applies currency conversion (resolves rates and stamps Exchange Rate fields).
    ///   4. Writes IC General Journal lines in a dedicated batch.
    ///   5. Posts the journal batch using standard BC logic, which automatically
    ///      creates IC Outbox entries and handles the double-entry bookkeeping.
    ///   6. Stamps Posted = TRUE and Status = Posted on the header.
    /// </summary>
    procedure PostRechargeRequest(var RechargeHeader: Record "IC Recharge Request Header")
    var
        ICRechargeSetup: Record "IC Recharge Setup";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        ICRechargeCalc: Codeunit "IC Recharge Calculation";
    begin
        // ── 1. Duplicate-posting guard ────────────────────────────────────────────
        if RechargeHeader."Posted" then
            Error(AlreadyPostedErr, RechargeHeader."No.");

        // ── 2. Prerequisites ──────────────────────────────────────────────────────
        RechargeHeader.TestField("IC Partner Code");
        RechargeHeader.TestField("Posting Date");
        RechargeHeader.TestField("Document Date");
        EnsureLinesExist(RechargeHeader);

        ICRechargeSetup.GetRecordOnce();

        // ── 3. Apply currency conversion — resolves partner Currency Rule,
        //       fetches exchange rates, stamps Exchange Rate and Exchange Rate Amount
        //       on every line.  Raises an error for unmapped or missing rates.
        ICRechargeCalc.ApplyCurrencyConversion(RechargeHeader);

        // ── 4. Write IC General Journal lines ────────────────────────────────────
        // We use a dedicated batch per request to avoid collision and allow atomic posting.
        GetOrCreateICJournalBatch(RechargeHeader."No.", GenJnlBatch);

        // Clear any leftover lines in this batch (e.g. from a previous failed attempt).
        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        GenJnlLine.DeleteAll(true);

        CreateICGeneralJournalLines(RechargeHeader, GenJnlBatch, ICRechargeSetup);

        // ── 5. Post the Journal Batch ─────────────────────────────────────────────
        // Standard posting creates IC Outbox entries automatically when IC Partner Code is set.
        PostJournalBatch(GenJnlBatch);

        // ── 6. Stamp Posted flag and finalise status ──────────────────────────────
        RechargeHeader."Posted" := true;
        RechargeHeader.Validate(RechargeHeader.Status, RechargeHeader.Status::Posted);
        RechargeHeader.Modify(true);
    end;

    // ─────────────────────────────────────────────────────────────────────────────
    // IC General Journal
    // ─────────────────────────────────────────────────────────────────────────────

    local procedure CreateICGeneralJournalLines(
        var RechargeHeader: Record "IC Recharge Request Header";
        var GenJnlBatch: Record "Gen. Journal Batch";
        var ICRechargeSetup: Record "IC Recharge Setup")
    var
        ReqLine: Record "IC Recharge Request Line";
        GenJnlLine: Record "Gen. Journal Line";
        LineNo: Integer;
        EffectiveCurrCode: Code[10];
    begin
        LineNo := 10000;

        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        ReqLine.SetCurrentKey("Request No.", "Line No.");
        if not ReqLine.FindSet() then
            exit;

        repeat
            if ReqLine."Recharge Amount" <> 0 then begin
                GenJnlLine.Init();
                GenJnlLine."Journal Template Name" := GenJnlBatch."Journal Template Name";
                GenJnlLine."Journal Batch Name" := GenJnlBatch.Name;
                GenJnlLine."Line No." := LineNo;
                GenJnlLine."Posting Date" := RechargeHeader."Posting Date";
                GenJnlLine."Document Date" := RechargeHeader."Document Date";
                GenJnlLine."Document No." := RechargeHeader."No.";
                GenJnlLine."External Document No." := RechargeHeader."External Document No.";
                GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                GenJnlLine.Validate("Account No.", ReqLine."G/L Account No.");
                GenJnlLine.Description :=
                    CopyStr(
                        StrSubstNo(ICRechargeJnlDescTxt,
                            RechargeHeader."No.",
                            ReqLine."IC Partner Code"),
                        1, MaxStrLen(GenJnlLine.Description));

                // Determine effective currency for this journal line
                EffectiveCurrCode := GetEffectiveCurrencyCode(RechargeHeader, ReqLine);

                // Set currency on the journal line before amount so BC performs conversion
                if EffectiveCurrCode <> '' then begin
                    GenJnlLine.Validate("Currency Code", EffectiveCurrCode);
                    // Use Exchange Rate Amount (already converted to partner currency)
                    // RECHARGE LOGIC: CREDIT the source account (negative) to move cost out.
                    if ReqLine."Exchange Rate Amount" <> 0 then
                        GenJnlLine.Validate(Amount, -ReqLine."Exchange Rate Amount")
                    else
                        GenJnlLine.Validate(Amount, -ReqLine."Recharge Amount");
                end else begin
                    // LCY line — no currency conversion needed
                    GenJnlLine.Validate(Amount, -ReqLine."Recharge Amount");
                end;

                GenJnlLine.Validate("IC Partner Code", ReqLine."IC Partner Code");
                GenJnlLine."IC Account Type" := GenJnlLine."IC Account Type"::"G/L Account";
                GenJnlLine."IC Account No." := ReqLine."Target IC G/L Account No.";
                GenJnlLine."Source Code" := GetSourceCode(ICRechargeSetup);
                GenJnlLine."Shortcut Dimension 1 Code" := ReqLine."Shortcut Dimension 1 Code";
                GenJnlLine."Shortcut Dimension 2 Code" := ReqLine."Shortcut Dimension 2 Code";
                GenJnlLine."Dimension Set ID" := ReqLine."Dimension Set ID";
                GenJnlLine.Insert(true);

                LineNo := LineNo + 10000;
            end;
        until ReqLine.Next() = 0;
    end;

    local procedure PostJournalBatch(var GenJnlBatch: Record "Gen. Journal Batch")
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        if GenJnlLine.FindFirst() then
            Codeunit.Run(Codeunit::"Gen. Jnl.-Post Batch", GenJnlLine);
    end;

    // ─────────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────────

    local procedure GetOrCreateICJournalBatch(RequestNo: Code[20]; var GenJnlBatch: Record "Gen. Journal Batch")
    var
        GenJnlTemplate: Record "Gen. Journal Template";
        BatchName: Code[10];
    begin
        // Ensure the IC General Journal template exists.
        if not GenJnlTemplate.Get(ICJournalTemplateTxt) then begin
            GenJnlTemplate.Init();
            GenJnlTemplate.Name := ICJournalTemplateTxt;
            GenJnlTemplate.Description := ICJournalTemplateDescTxt;
            GenJnlTemplate.Type := GenJnlTemplate.Type::Intercompany;
            GenJnlTemplate.Insert(true);
        end;

        // Use a batch name derived from the Request No.
        BatchName := CopyStr(RequestNo, 1, 10);
        if BatchName = '' then
            BatchName := 'DEFAULT';

        // Ensure the batch exists.
        if not GenJnlBatch.Get(ICJournalTemplateTxt, BatchName) then begin
            GenJnlBatch.Init();
            GenJnlBatch."Journal Template Name" := ICJournalTemplateTxt;
            GenJnlBatch.Name := BatchName;
            GenJnlBatch.Description := ICJournalBatchDescTxt;
            GenJnlBatch.Insert(true);
        end;
    end;

    local procedure GetSourceCode(var ICRechargeSetup: Record "IC Recharge Setup"): Code[10]
    var
        SourceCode: Record "Source Code";
    begin
        if ICRechargeSetup."IC Recharge Source Code" <> '' then
            exit(ICRechargeSetup."IC Recharge Source Code");

        if not SourceCode.Get(DefaultSourceCodeTxt) then begin
            SourceCode.Init();
            SourceCode.Code := DefaultSourceCodeTxt;
            SourceCode.Description := DefaultSourceCodeDescTxt;
            SourceCode.Insert(true);
        end;
        exit(DefaultSourceCodeTxt);
    end;

    local procedure GetEffectiveCurrencyCode(
        var RechargeHeader: Record "IC Recharge Request Header";
        var ReqLine: Record "IC Recharge Request Line"): Code[10]
    begin
        // Line currency (populated by ApplyCurrencyConversion) takes precedence
        if ReqLine."Currency Code" <> '' then
            exit(ReqLine."Currency Code");
        exit(RechargeHeader."Currency Code");
    end;

    local procedure EnsureLinesExist(var RechargeHeader: Record "IC Recharge Request Header")
    var
        ReqLine: Record "IC Recharge Request Line";
    begin
        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        if ReqLine.IsEmpty() then
            Error(NoLinesErr, RechargeHeader."No.");
    end;

    var
        ICJournalTemplateTxt: Label 'ICRECHARGE', Locked = true;
        ICJournalTemplateDescTxt: Label 'IC Recharge General Journal';
        ICJournalBatchDescTxt: Label 'IC Recharge Batch';
        DefaultSourceCodeTxt: Label 'ICRECHARG', Locked = true;
        DefaultSourceCodeDescTxt: Label 'IC Intercompany Recharge';
        ICRechargeJnlDescTxt: Label 'IC Recharge %1 – Partner %2', Comment = '%1=Request No., %2=IC Partner Code';
        AlreadyPostedErr: Label 'IC Recharge Request %1 has already been posted. Duplicate posting is not allowed.', Comment = '%1 = Document No.';
        NoLinesErr: Label 'IC Recharge Request %1 has no lines. Add recharge lines before posting.', Comment = '%1 = Document No.';
}
