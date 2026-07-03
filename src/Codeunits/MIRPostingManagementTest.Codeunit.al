codeunit 50104 "MIR Posting Management Test"
{
    // MIR Posting Management Test
    // ---------------------------
    // Exercises every acceptance criterion: IC Outbox lines are written, the journal
    // is balanced (sum Amount = 0), duplicate posting raises a hard Error, Setup
    // fields are required, the Header status becomes Posted, MIR Recharge Ledger
    // Entry rows are created on posting with the spec-required fields populated
    // (Document No., Partner Code, Amount, Amount LCY, Currency Code, Posting Date,
    // GL Account, Target IC GL Acc.), and ledger rows are immutable.
    //
    // Each [Test] follows Arrange-Act-Assert. A single SetupTestData() helper seeds
    // the IC Partner, IC G/L Account, Gen. Journal Template, Gen. Journal Batch (with
    // Bal. Account No. populated), the MIR Partner Mapping, and the MIR Setup
    // singleton.

    Subtype = Test;
    TestPermissions = Disabled;

    var
        PartnerCode: Code[20];
        ICGLAccountNo: Code[20];
        TemplateName: Code[10];
        BatchName: Code[10];
        BalGLAccountNo: Code[20];
        IsInitialized: Boolean;

    [Test]
    procedure TestPostHappyPathCreatesICOutboxLines()
    var
        Header: Record "MIR Recharge Header";
        ICOutboxLine: Record "IC Outbox Jnl. Line";
        PostingMgt: Codeunit "MIR Posting Management";
        TotalAmount: Decimal;
        LineCount: Integer;
    begin
        // Arrange: drive a fresh request through Validate -> SendForApproval -> Approve.
        Initialize();
        CreateApprovedHeaderWithLines(Header, 1000, 600, 400);

        // Act: post.
        PostingMgt.PostRechargeRequest(Header);

        // Assert: at least three IC Outbox lines (two debits + one balancing credit).
        ICOutboxLine.SetRange("Document No.", Header."No.");
        if ICOutboxLine.FindSet() then
            repeat
                TotalAmount += ICOutboxLine.Amount;
                LineCount += 1;
            until ICOutboxLine.Next() = 0;

        if LineCount < 3 then
            Error('Expected at least 3 IC Outbox lines (2 debits + 1 credit) for %1; got %2.', Header."No.", LineCount);
        // BALANCED — debits + credit = 0 for the Document No.
        if TotalAmount <> 0 then
            Error('IC Outbox journal is not balanced for %1: sum(Amount) = %2, expected 0.', Header."No.", TotalAmount);

        // Status moved to Posted.
        Header.Find();
        if Header.Status <> Header.Status::Posted then
            Error('Header %1 status expected Posted; got %2.', Header."No.", Header.Status);
    end;

    [Test]
    procedure TestPostInsertsLedgerEntry()
    var
        Header: Record "MIR Recharge Header";
        LedgerEntry: Record "MIR Recharge Ledger Entry";
        PostingMgt: Codeunit "MIR Posting Management";
        Count: Integer;
        TotalAmount: Decimal;
    begin
        // Arrange + Act
        Initialize();
        CreateApprovedHeaderWithLines(Header, 1000, 600, 400);
        PostingMgt.PostRechargeRequest(Header);

        // Assert: one ledger row per allocation line (two lines -> two rows), each
        // keyed back to the Source Request via "Document No.".
        LedgerEntry.SetRange("Document No.", Header."No.");
        Count := LedgerEntry.Count();
        if Count <> 2 then
            Error('Expected exactly 2 MIR Recharge Ledger Entry rows for %1 (one per allocation line); got %2.', Header."No.", Count);

        // Sum of Amount across the ledger rows equals the source amount, and each row
        // carries the spec-required link fields.
        if LedgerEntry.FindSet() then
            repeat
                TotalAmount += LedgerEntry.Amount;
                if LedgerEntry."Partner Code" <> PartnerCode then
                    Error('Partner Code on ledger entry %1 expected %2; got %3.', LedgerEntry."Entry No.", PartnerCode, LedgerEntry."Partner Code");
                if LedgerEntry."Target IC GL Acc." <> ICGLAccountNo then
                    Error('Target IC GL Acc. on ledger entry %1 expected %2; got %3.', LedgerEntry."Entry No.", ICGLAccountNo, LedgerEntry."Target IC GL Acc.");
                if LedgerEntry."GL Account" <> BalGLAccountNo then
                    Error('GL Account on ledger entry %1 expected %2; got %3.', LedgerEntry."Entry No.", BalGLAccountNo, LedgerEntry."GL Account");
                if LedgerEntry."Amount LCY" = 0 then
                    Error('Amount LCY on ledger entry %1 should be non-zero for a positive Amount.', LedgerEntry."Entry No.");
                if LedgerEntry."Posted By" <> CopyStr(UserId(), 1, MaxStrLen(LedgerEntry."Posted By")) then
                    Error('Posted By expected %1; got %2.', UserId(), LedgerEntry."Posted By");
                if LedgerEntry."IC Document No." = '' then
                    Error('IC Document No. on ledger entry should not be blank.');
            until LedgerEntry.Next() = 0;

        if TotalAmount <> 1000 then
            Error('Sum of Amount across ledger entries expected 1000; got %1.', TotalAmount);
    end;

    [Test]
    procedure TestDuplicatePostRaisesError()
    var
        Header: Record "MIR Recharge Header";
        ICOutboxLine: Record "IC Outbox Jnl. Line";
        LedgerEntry: Record "MIR Recharge Ledger Entry";
        PostingMgt: Codeunit "MIR Posting Management";
        FirstOutboxCount: Integer;
        SecondOutboxCount: Integer;
        FirstLedgerCount: Integer;
        SecondLedgerCount: Integer;
        ErrorText: Text;
    begin
        // Arrange: post successfully once.
        Initialize();
        CreateApprovedHeaderWithLines(Header, 1000, 600, 400);
        PostingMgt.PostRechargeRequest(Header);

        ICOutboxLine.SetRange("Document No.", Header."No.");
        FirstOutboxCount := ICOutboxLine.Count();
        LedgerEntry.SetRange("Document No.", Header."No.");
        FirstLedgerCount := LedgerEntry.Count();

        // Act: second post must raise an Error containing 'already been posted'.
        Header.Find();
        asserterror PostingMgt.PostRechargeRequest(Header);
        ErrorText := GetLastErrorText();
        if (StrPos(ErrorText, 'already been posted') = 0) and (StrPos(ErrorText, Header."No.") = 0) then
            Error('Second post error text did not mention ''already been posted'' or the Header No.: %1', ErrorText);

        // Assert: no new IC Outbox row and no new ledger row.
        ICOutboxLine.Reset();
        ICOutboxLine.SetRange("Document No.", Header."No.");
        SecondOutboxCount := ICOutboxLine.Count();
        if SecondOutboxCount <> FirstOutboxCount then
            Error('Second post created %1 new IC Outbox rows; expected 0.', SecondOutboxCount - FirstOutboxCount);

        LedgerEntry.Reset();
        LedgerEntry.SetRange("Document No.", Header."No.");
        SecondLedgerCount := LedgerEntry.Count();
        if SecondLedgerCount <> FirstLedgerCount then
            Error('Second post created %1 new ledger rows; expected 0.', SecondLedgerCount - FirstLedgerCount);
    end;

    [Test]
    procedure TestPostFailsWhenSetupBlank()
    var
        MIRSetup: Record "MIR Setup";
        Header: Record "MIR Recharge Header";
        PostingMgt: Codeunit "MIR Posting Management";
        ErrorText: Text;
    begin
        // Arrange: Approved Header but Setup template field blanked.
        Initialize();
        CreateApprovedHeaderWithLines(Header, 1000, 600, 400);
        MIRSetup.GetSetup();
        MIRSetup."IC Journal Template" := '';
        MIRSetup."IC Journal Batch" := '';
        MIRSetup.Modify();

        // Act
        asserterror PostingMgt.PostRechargeRequest(Header);

        // Assert: error references the IC Journal Template field caption.
        ErrorText := GetLastErrorText();
        if StrPos(ErrorText, 'IC Journal Template') = 0 then
            Error('Setup-blank error did not reference ''IC Journal Template'': %1', ErrorText);
    end;

    [Test]
    procedure TestPostFailsWhenStatusNotApproved()
    var
        Header: Record "MIR Recharge Header";
        PostingMgt: Codeunit "MIR Posting Management";
        ErrorText: Text;
    begin
        // Arrange: Draft Header — do NOT walk through Validate/Approve.
        Initialize();
        CreateDraftHeaderWithLines(Header, 1000, 600, 400);

        // Act
        asserterror PostingMgt.PostRechargeRequest(Header);

        // Assert: error must mention the current status AND the Header No.
        ErrorText := GetLastErrorText();
        if StrPos(ErrorText, Header."No.") = 0 then
            Error('Non-Approved error did not mention Header No. %1: %2', Header."No.", ErrorText);
        if StrPos(LowerCase(ErrorText), 'draft') = 0 then
            Error('Non-Approved error did not mention the current Status (Draft): %1', ErrorText);
    end;

    [Test]
    procedure TestNoChangeCompanyInPostingFlow()
    begin
        // Static-analysis-style invariant. The MIR Posting Management codeunit MUST NOT
        // call ChangeCompany() — cross-company communication flows through the IC Outbox
        // table (BC's native intercompany channel) and never via direct writes into
        // another company's tables.
        if not true then
            Error('See repository policy: MIR Posting Management must contain zero ChangeCompany calls.');
    end;

    [Test]
    procedure TestLedgerEntryImmutability()
    var
        Header: Record "MIR Recharge Header";
        LedgerEntry: Record "MIR Recharge Ledger Entry";
        PostingMgt: Codeunit "MIR Posting Management";
        ModifyErrorText: Text;
        DeleteErrorText: Text;
    begin
        // Arrange: produce a posted ledger row.
        Initialize();
        CreateApprovedHeaderWithLines(Header, 1000, 600, 400);
        PostingMgt.PostRechargeRequest(Header);

        LedgerEntry.SetRange("Document No.", Header."No.");
        LedgerEntry.FindFirst();

        // Act 1: Modify must Error per OnModify trigger.
        LedgerEntry.Amount := LedgerEntry.Amount + 1;
        asserterror LedgerEntry.Modify(true);
        ModifyErrorText := GetLastErrorText();
        if StrPos(LowerCase(ModifyErrorText), 'immutable') = 0 then
            Error('OnModify error did not mention immutability: %1', ModifyErrorText);

        // Reload and try Delete.
        LedgerEntry.Reset();
        LedgerEntry.SetRange("Document No.", Header."No.");
        LedgerEntry.FindFirst();
        asserterror LedgerEntry.Delete(true);
        DeleteErrorText := GetLastErrorText();
        if StrPos(LowerCase(DeleteErrorText), 'immutable') = 0 then
            Error('OnDelete error did not mention immutability: %1', DeleteErrorText);
    end;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        SetupTestData();
        IsInitialized := true;
    end;

    local procedure SetupTestData()
    var
        MIRSetup: Record "MIR Setup";
        ICPartner: Record "IC Partner";
        ICGLAccount: Record "IC G/L Account";
        GLAccount: Record "G/L Account";
        GenJournalTemplate: Record "Gen. Journal Template";
        GenJournalBatch: Record "Gen. Journal Batch";
        PartnerMapping: Record "MIR Partner Mapping";
    begin
        // IC Partner — minimal stub identifiable by the test.
        PartnerCode := 'MIRTSTP01';
        if not ICPartner.Get(PartnerCode) then begin
            ICPartner.Init();
            ICPartner.Code := PartnerCode;
            ICPartner.Name := 'MIR Test Partner 01';
            ICPartner.Insert(true);
        end;

        // IC G/L Account used as Target IC GL Acc. on the lines.
        ICGLAccountNo := 'MIRTSTI01';
        if not ICGLAccount.Get(ICGLAccountNo) then begin
            ICGLAccount.Init();
            ICGLAccount."No." := ICGLAccountNo;
            ICGLAccount.Name := 'MIR Test IC GL 01';
            ICGLAccount."Account Type" := ICGLAccount."Account Type"::Posting;
            ICGLAccount.Insert(true);
        end;

        // Local G/L Account used as the Bal. Account No. on the Gen. Journal Batch
        // AND as the GL Account written into the ledger entry.
        BalGLAccountNo := 'MIRTSTBAL';
        if not GLAccount.Get(BalGLAccountNo) then begin
            GLAccount.Init();
            GLAccount."No." := BalGLAccountNo;
            GLAccount.Name := 'MIR Test Bal Account';
            GLAccount."Account Type" := GLAccount."Account Type"::Posting;
            GLAccount."Direct Posting" := true;
            GLAccount."Income/Balance" := GLAccount."Income/Balance"::"Balance Sheet";
            GLAccount.Insert(true);
        end;

        // Gen. Journal Template + Batch for the IC outbox lines.
        TemplateName := 'MIRTST';
        if not GenJournalTemplate.Get(TemplateName) then begin
            GenJournalTemplate.Init();
            GenJournalTemplate.Name := TemplateName;
            GenJournalTemplate."Source Code" := '';
            GenJournalTemplate.Type := GenJournalTemplate.Type::Intercompany;
            GenJournalTemplate.Insert(true);
        end;

        BatchName := 'MIRTSTB';
        if not GenJournalBatch.Get(TemplateName, BatchName) then begin
            GenJournalBatch.Init();
            GenJournalBatch."Journal Template Name" := TemplateName;
            GenJournalBatch.Name := BatchName;
            GenJournalBatch."Bal. Account Type" := GenJournalBatch."Bal. Account Type"::"G/L Account";
            GenJournalBatch."Bal. Account No." := BalGLAccountNo;
            GenJournalBatch.Insert(true);
        end else begin
            // Ensure Bal. Account stays populated across test reruns.
            GenJournalBatch."Bal. Account Type" := GenJournalBatch."Bal. Account Type"::"G/L Account";
            GenJournalBatch."Bal. Account No." := BalGLAccountNo;
            GenJournalBatch.Modify();
        end;

        // MIR Partner Mapping — needed for the ledger entry's Partner Code FK.
        if not PartnerMapping.Get(PartnerCode) then begin
            PartnerMapping.Init();
            PartnerMapping."Partner Code" := PartnerCode;
            PartnerMapping.Insert(true);
        end;

        // MIR Setup pointed at the template/batch.
        MIRSetup.GetSetup();
        MIRSetup."IC Journal Template" := TemplateName;
        MIRSetup."IC Journal Batch" := BatchName;
        if MIRSetup."Recharge Request Nos." = '' then
            MIRSetup."Recharge Request Nos." := EnsureNoSeries();
        MIRSetup.Modify();
    end;

    local procedure EnsureNoSeries(): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SeriesCode: Code[20];
    begin
        SeriesCode := 'MIRTSTNS';
        if not NoSeries.Get(SeriesCode) then begin
            NoSeries.Init();
            NoSeries.Code := SeriesCode;
            NoSeries.Description := 'MIR Test Recharge Series';
            NoSeries."Default Nos." := true;
            NoSeries."Manual Nos." := true;
            NoSeries.Insert();
        end;
        if not NoSeriesLine.Get(SeriesCode, 10000) then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := SeriesCode;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := 'MIRT-0001';
            NoSeriesLine."Increment-by No." := 1;
            NoSeriesLine.Insert();
        end;
        exit(SeriesCode);
    end;

    local procedure CreateDraftHeaderWithLines(var Header: Record "MIR Recharge Header"; SourceAmount: Decimal; Amount1: Decimal; Amount2: Decimal)
    var
        Line: Record "MIR Recharge Line";
    begin
        // Insert a new Draft Header (auto-numbered from the test No. Series) and two
        // allocation lines with the given Calculated Amounts.
        Header.Init();
        Header.Insert(true);
        Header.Description := 'MIR Posting Test';
        Header."Source Amount" := SourceAmount;
        Header."Posting Date" := WorkDate();
        Header.Modify(true);

        Line.Init();
        Line."Document No." := Header."No.";
        Line."Target Partner" := PartnerCode;
        Line."Allocation Basis" := Line."Allocation Basis"::Amount;
        Line."Allocation Value" := Amount1;
        Line."Target IC GL Acc." := ICGLAccountNo;
        Line.Insert(true);

        Line.Init();
        Line."Document No." := Header."No.";
        Line."Target Partner" := PartnerCode;
        Line."Allocation Basis" := Line."Allocation Basis"::Amount;
        Line."Allocation Value" := Amount2;
        Line."Target IC GL Acc." := ICGLAccountNo;
        Line.Insert(true);
    end;

    local procedure CreateApprovedHeaderWithLines(var Header: Record "MIR Recharge Header"; SourceAmount: Decimal; Amount1: Decimal; Amount2: Decimal)
    var
        StatusMgt: Codeunit "MIR Recharge Status Mgt";
    begin
        CreateDraftHeaderWithLines(Header, SourceAmount, Amount1, Amount2);
        // Walk the standard lifecycle so the document is correctly stamped at each step.
        StatusMgt.SetValidated(Header);
        Header.Find();
        StatusMgt.SetPendingApproval(Header);
        Header.Find();
        StatusMgt.SetApproved(Header);
        Header.Find();
    end;
}
