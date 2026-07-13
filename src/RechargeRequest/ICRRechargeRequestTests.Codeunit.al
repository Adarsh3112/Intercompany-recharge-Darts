codeunit 50104 "ICR Recharge Request Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        IsInitialized: Boolean;
        AssertAreEqualErr: Label 'Assertion failed. Expected: %1. Actual: %2. %3', Comment = '%1=expected, %2=actual, %3=message';
        AssertAreNotEqualErr: Label 'Assertion failed. Values should differ. Value: %1. %2', Comment = '%1=value, %2=message';
        AssertIsTrueErr: Label 'Assertion failed. Condition should be TRUE. %1', Comment = '%1=message';
        AssertExpectedErrorErr: Label 'Assertion failed. Expected error containing ''%1'' but got: %2', Comment = '%1=expected substring, %2=actual error';

    local procedure Initialize()
    var
        ICRSetup: Record "ICR Setup";
    begin
        if IsInitialized then begin
            EnsureSetupSeries();
            exit;
        end;

        ICRSetup.GetSetup();
        EnsureSetupSeries();
        IsInitialized := true;
    end;

    local procedure EnsureSetupSeries()
    var
        ICRSetup: Record "ICR Setup";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        ICRSetup.GetSetup();
        if ICRSetup."Recharge Request Nos." = '' then begin
            if not NoSeries.Get('ICR-REQ') then begin
                NoSeries.Init();
                NoSeries.Code := 'ICR-REQ';
                NoSeries.Description := 'Intercompany Recharge Requests';
                NoSeries."Default Nos." := true;
                NoSeries.Insert(true);
            end;
            NoSeriesLine.SetRange("Series Code", 'ICR-REQ');
            if not NoSeriesLine.FindFirst() then begin
                NoSeriesLine.Init();
                NoSeriesLine."Series Code" := 'ICR-REQ';
                NoSeriesLine."Line No." := 10000;
                NoSeriesLine."Starting No." := 'REQ-0001';
                NoSeriesLine."Increment-by No." := 1;
                NoSeriesLine.Insert(true);
            end;
            ICRSetup."Recharge Request Nos." := 'ICR-REQ';
            ICRSetup.Modify(true);
        end;
    end;

    local procedure DeleteAllRequests()
    var
        RechargeRequest: Record "ICR Recharge Request";
    begin
        RechargeRequest.Reset();
        RechargeRequest.DeleteAll();
    end;

    [Test]
    procedure NoSeriesAutoAssignsOnInsert()
    var
        RechargeRequest: Record "ICR Recharge Request";
    begin
        // [GIVEN] A configured ICR Setup with a valid Recharge Request Nos. series
        Initialize();
        DeleteAllRequests();

        // [WHEN] Inserting a Recharge Request with blank No.
        RechargeRequest.Init();
        RechargeRequest."No." := '';
        RechargeRequest.Insert(true);

        // [THEN] The No. field is populated with a value from the ICR-REQ series
        AssertAreNotEqual('', RechargeRequest."No.", 'No. should be assigned automatically on Insert.');
        AssertIsTrue(
            CopyStr(RechargeRequest."No.", 1, 4) = 'REQ-',
            'Assigned No. should start with the ''REQ-'' prefix from the ICR-REQ number series.');

        // Cleanup
        RechargeRequest.Delete();
    end;

    [Test]
    procedure StatusDefaultsToDraftOnInsert()
    var
        RechargeRequest: Record "ICR Recharge Request";
    begin
        // [GIVEN] A configured ICR Setup
        Initialize();
        DeleteAllRequests();

        // [WHEN] Inserting a new Recharge Request
        RechargeRequest.Init();
        RechargeRequest.Insert(true);

        // [THEN] Status defaults to Draft
        AssertAreEqual(
            RechargeRequest.Status::Draft.AsInteger(),
            RechargeRequest.Status.AsInteger(),
            'Status should default to Draft after Insert.');

        // Cleanup
        RechargeRequest.Delete();
    end;

    [Test]
    procedure BlankSetupSeriesRaisesError()
    var
        ICRSetup: Record "ICR Setup";
        RechargeRequest: Record "ICR Recharge Request";
        SavedSeries: Code[20];
    begin
        // [GIVEN] ICR Setup with Recharge Request Nos. cleared
        Initialize();
        DeleteAllRequests();
        ICRSetup.GetSetup();
        SavedSeries := ICRSetup."Recharge Request Nos.";
        ICRSetup."Recharge Request Nos." := '';
        ICRSetup.Modify(true);

        // [WHEN] Inserting a Recharge Request with blank No.
        RechargeRequest.Init();
        RechargeRequest."No." := '';
        asserterror RechargeRequest.Insert(true);

        // [THEN] An actionable error mentioning ICR Setup is raised
        AssertExpectedError('ICR Setup');

        // Cleanup: restore the setup series so subsequent tests pass
        ICRSetup.GetSetup();
        ICRSetup."Recharge Request Nos." := SavedSeries;
        ICRSetup.Modify(true);
    end;

    [Test]
    procedure RequestStatusEnumValuesArePresent()
    var
        StatusEnum: Enum "ICR Request Status";
    begin
        // [WHEN] Each declared status enum value is referenced
        // [THEN] No runtime error occurs and ordinal positions are as specified
        AssertAreEqual(0, StatusEnum::Draft.AsInteger(), 'Draft must be ordinal 0.');
        AssertAreEqual(1, StatusEnum::Validated.AsInteger(), 'Validated must be ordinal 1.');
        AssertAreEqual(2, StatusEnum::"Pending Approval".AsInteger(), 'Pending Approval must be ordinal 2.');
        AssertAreEqual(3, StatusEnum::Approved.AsInteger(), 'Approved must be ordinal 3.');
        AssertAreEqual(4, StatusEnum::Rejected.AsInteger(), 'Rejected must be ordinal 4.');
        AssertAreEqual(5, StatusEnum::Posted.AsInteger(), 'Posted must be ordinal 5.');
        AssertAreEqual(6, StatusEnum::Reversed.AsInteger(), 'Reversed must be ordinal 6.');
        AssertAreEqual(7, StatusEnum::Closed.AsInteger(), 'Closed must be ordinal 7.');
    end;

    [Test]
    procedure AllocationBasisEnumValuesArePresent()
    var
        BasisEnum: Enum "ICR Allocation Basis";
    begin
        // [WHEN] Each declared allocation basis value is referenced
        // [THEN] No runtime error occurs and ordinal positions are as specified
        AssertAreEqual(0, BasisEnum::"Fixed Percentage".AsInteger(), 'Fixed Percentage must be ordinal 0.');
        AssertAreEqual(1, BasisEnum::"Amount-Based".AsInteger(), 'Amount-Based must be ordinal 1.');
        AssertAreEqual(2, BasisEnum::"Dimension-Driven".AsInteger(), 'Dimension-Driven must be ordinal 2.');
        AssertAreEqual(3, BasisEnum::Headcount.AsInteger(), 'Headcount must be ordinal 3.');
    end;

    [Test]
    procedure FieldsExistAndAcceptExpectedValues()
    var
        RechargeRequest: Record "ICR Recharge Request";
        GLAccount: Record "G/L Account";
        Currency: Record Currency;
        GLAccountNo: Code[20];
        CurrencyCode: Code[10];
    begin
        // [GIVEN] Setup, a G/L Account, and a Currency fixture
        Initialize();
        DeleteAllRequests();
        GLAccountNo := EnsureGLAccount(GLAccount);
        CurrencyCode := EnsureCurrency(Currency);

        // [WHEN] A Recharge Request is inserted with representative values for each field
        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest.Validate("Source Company", CopyStr(CompanyName(), 1, MaxStrLen(RechargeRequest."Source Company")));
        RechargeRequest.Validate("Recharge Type", 'SHARED-IT');
        RechargeRequest.Validate("Allocation Basis", RechargeRequest."Allocation Basis"::"Fixed Percentage");
        RechargeRequest.Validate("Source G/L Account", GLAccountNo);
        RechargeRequest.Validate("Currency Code", CurrencyCode);
        RechargeRequest.Validate("Total Amount", 1000);
        RechargeRequest.Validate("Exchange Rate", 1);
        RechargeRequest.Modify(true);

        // [THEN] Re-reading the record returns the persisted values
        RechargeRequest.Get(RechargeRequest."No.");
        AssertAreEqual(CopyStr(CompanyName(), 1, MaxStrLen(RechargeRequest."Source Company")), RechargeRequest."Source Company", 'Source Company should persist.');
        AssertAreEqual('SHARED-IT', RechargeRequest."Recharge Type", 'Recharge Type should persist.');
        AssertAreEqual(RechargeRequest."Allocation Basis"::"Fixed Percentage".AsInteger(), RechargeRequest."Allocation Basis".AsInteger(), 'Allocation Basis should persist.');
        AssertAreEqual(GLAccountNo, RechargeRequest."Source G/L Account", 'Source G/L Account should persist.');
        AssertAreEqual(CurrencyCode, RechargeRequest."Currency Code", 'Currency Code should persist.');
        AssertAreEqual(1000, RechargeRequest."Total Amount", 'Total Amount should persist.');
        AssertAreEqual(1, RechargeRequest."Exchange Rate", 'Exchange Rate should persist.');

        // Cleanup
        RechargeRequest.Delete();
    end;

    [Test]
    procedure CalculateAllocationsBlocksOverAllocation()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRMgmt: Codeunit "ICR Management";
    begin
        // [GIVEN] A Recharge Request with Total Amount 1000 and two lines totalling 1200
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Fixed Percentage";
        RechargeRequest.Modify(true);

        // Set Allocated Amount directly (not via Validate on Allocation %) so the
        // sum can exceed Total Amount without being clamped by the trigger.
        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 10000;
        RechargeLine."Allocated Amount" := 700;
        RechargeLine.Insert(false);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 20000;
        RechargeLine."Allocated Amount" := 500;
        RechargeLine.Insert(false);

        // [WHEN] CalculateAllocations is invoked
        asserterror ICRMgmt.CalculateAllocations(RechargeRequest);

        // [THEN] The mandated error phrases are present in the raised error
        AssertExpectedError('Total allocated');
        AssertExpectedError('exceeds source amount');

        // Cleanup
        RechargeLine.SetRange("Document No.", RechargeRequest."No.");
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure CheckBalancingAcceptsPercentageAt100()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRMgmt: Codeunit "ICR Management";
    begin
        // [GIVEN] A Fixed Percentage request with lines summing to exactly 100%
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Fixed Percentage";
        RechargeRequest.Modify(true);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 10000;
        RechargeLine."Allocation %" := 60;
        RechargeLine.Insert(false);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 20000;
        RechargeLine."Allocation %" := 40;
        RechargeLine.Insert(false);

        // [WHEN] CheckBalancing is invoked
        // [THEN] It completes silently (no error)
        ICRMgmt.CheckBalancing(RechargeRequest);

        // Cleanup
        RechargeLine.SetRange("Document No.", RechargeRequest."No.");
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure CheckBalancingRejectsPercentageNot100()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRMgmt: Codeunit "ICR Management";
    begin
        // [GIVEN] A Fixed Percentage request with lines summing to 90%
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Fixed Percentage";
        RechargeRequest.Modify(true);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 10000;
        RechargeLine."Allocation %" := 60;
        RechargeLine.Insert(false);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 20000;
        RechargeLine."Allocation %" := 30;
        RechargeLine.Insert(false);

        // [WHEN] CheckBalancing is invoked
        asserterror ICRMgmt.CheckBalancing(RechargeRequest);

        // [THEN] An error is raised (percentages must sum to 100)
        AssertExpectedError(RechargeRequest."No.");

        // Cleanup
        RechargeLine.SetRange("Document No.", RechargeRequest."No.");
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure CheckBalancingAcceptsAmountEqualsTotal()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRMgmt: Codeunit "ICR Management";
    begin
        // [GIVEN] An Amount-Based request with lines summing to exactly Total Amount
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Amount-Based";
        RechargeRequest.Modify(true);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 10000;
        RechargeLine."Allocated Amount" := 600;
        RechargeLine.Insert(false);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 20000;
        RechargeLine."Allocated Amount" := 400;
        RechargeLine.Insert(false);

        // [WHEN] CheckBalancing is invoked
        // [THEN] It completes silently (no error)
        ICRMgmt.CheckBalancing(RechargeRequest);

        // Cleanup
        RechargeLine.SetRange("Document No.", RechargeRequest."No.");
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure CheckBalancingRejectsAmountNotEqualTotal()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRMgmt: Codeunit "ICR Management";
    begin
        // [GIVEN] An Amount-Based request with lines summing to 900 vs Total 1000
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Amount-Based";
        RechargeRequest.Modify(true);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 10000;
        RechargeLine."Allocated Amount" := 600;
        RechargeLine.Insert(false);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 20000;
        RechargeLine."Allocated Amount" := 300;
        RechargeLine.Insert(false);

        // [WHEN] CheckBalancing is invoked
        asserterror ICRMgmt.CheckBalancing(RechargeRequest);

        // [THEN] An error is raised (amounts must sum to Total Amount)
        AssertExpectedError(RechargeRequest."No.");

        // Cleanup
        RechargeLine.SetRange("Document No.", RechargeRequest."No.");
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure SendMovesRequestToPendingApproval()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
        DocNo: Code[20];
    begin
        // [GIVEN] A Draft Recharge Request with no open Approval Entry
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        DocNo := RechargeRequest."No.";

        // [WHEN] Send-For-Approval is invoked via the library codeunit
        // The library flips Status BEFORE dispatching to ApprovalsMgmt, so
        // even if the standard framework raises 'No approval workflow enabled'
        // (no Workflow record in the test tenant), the status flip must have
        // already been persisted via Modify(true).
        if not TrySendForApproval(ICRApprovalWorkflow, RechargeRequest) then
            ClearLastError();

        // [THEN] Re-reading the record shows Status = Pending Approval (ordinal 2)
        RechargeRequest.Get(DocNo);
        AssertAreEqual(
            RechargeRequest.Status::"Pending Approval".AsInteger(),
            RechargeRequest.Status.AsInteger(),
            'Send should have flipped Status to Pending Approval.');

        // Cleanup
        RechargeLine.SetRange("Document No.", DocNo);
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure CancelRestoresRequestFromPendingApproval()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
        DocNo: Code[20];
    begin
        // [GIVEN] A Recharge Request forced into Pending Approval
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        DocNo := RechargeRequest."No.";
        RechargeRequest.Status := RechargeRequest.Status::"Pending Approval";
        RechargeRequest.Modify(true);

        // [WHEN] Cancel-Approval-Request is invoked via the library codeunit
        ICRApprovalWorkflow.OnCancelICRRechargeRequestApprovalRequest(RechargeRequest);

        // [THEN] Status is no longer Pending Approval (naturally reverts to Draft)
        RechargeRequest.Get(DocNo);
        AssertAreNotEqual(
            RechargeRequest.Status::"Pending Approval".AsInteger(),
            RechargeRequest.Status.AsInteger(),
            'Cancel should have reverted Status away from Pending Approval.');

        // Cleanup
        RechargeLine.SetRange("Document No.", DocNo);
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    [Test]
    procedure SendOnAlreadyPendingRequestErrors()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
        DocNo: Code[20];
    begin
        // [GIVEN] A Recharge Request already in Pending Approval
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        DocNo := RechargeRequest."No.";
        RechargeRequest.Status := RechargeRequest.Status::"Pending Approval";
        RechargeRequest.Modify(true);

        // [WHEN] Send is invoked a second time
        asserterror ICRApprovalWorkflow.OnSendICRRechargeRequestForApproval(RechargeRequest);

        // [THEN] The guard error is raised and its message contains the document number
        AssertExpectedError(DocNo);

        // Cleanup
        if RechargeRequest.Get(DocNo) then begin
            RechargeLine.SetRange("Document No.", DocNo);
            RechargeLine.DeleteAll();
            RechargeRequest.Delete();
        end;
    end;

    [Test]
    procedure CancelOnDraftRequestErrors()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
        DocNo: Code[20];
    begin
        // [GIVEN] A Draft Recharge Request (Status <> Pending Approval)
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        DocNo := RechargeRequest."No.";

        // [WHEN] Cancel is invoked on a Draft request
        asserterror ICRApprovalWorkflow.OnCancelICRRechargeRequestApprovalRequest(RechargeRequest);

        // [THEN] The guard error is raised and its message contains the document number
        AssertExpectedError(DocNo);

        // Cleanup
        if RechargeRequest.Get(DocNo) then begin
            RechargeLine.SetRange("Document No.", DocNo);
            RechargeLine.DeleteAll();
            RechargeRequest.Delete();
        end;
    end;

    [TryFunction]
    local procedure TrySendForApproval(var ICRApprovalWorkflow: Codeunit "ICR Approval Workflow"; var Header: Record "ICR Recharge Request")
    begin
        // Wrap the Send call in a TryFunction so we can observe the persisted
        // Status change even when the downstream ApprovalsMgmt framework raises
        // 'No approval workflow enabled' due to the absence of a configured
        // Workflow record in the test tenant.
        ICRApprovalWorkflow.OnSendICRRechargeRequestForApproval(Header);
    end;

    local procedure EnsureGLAccount(var GLAccount: Record "G/L Account"): Code[20]
    begin
        GLAccount.Reset();
        GLAccount.SetRange(Blocked, false);
        GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
        if GLAccount.FindFirst() then
            exit(GLAccount."No.");

        if not GLAccount.Get('ICR-TEST-GL') then begin
            GLAccount.Init();
            GLAccount."No." := 'ICR-TEST-GL';
            GLAccount.Name := 'ICR Test G/L Account';
            GLAccount."Account Type" := GLAccount."Account Type"::Posting;
            GLAccount.Insert(true);
        end;
        exit(GLAccount."No.");
    end;

    local procedure EnsureCurrency(var Currency: Record Currency): Code[10]
    begin
        Currency.Reset();
        if Currency.FindFirst() then
            exit(Currency.Code);

        if not Currency.Get('EUR') then begin
            Currency.Init();
            Currency.Code := 'EUR';
            Currency.Description := 'Euro';
            Currency.Insert(true);
        end;
        exit(Currency.Code);
    end;

    local procedure AssertAreEqual(Expected: Variant; Actual: Variant; Message: Text)
    begin
        if Format(Expected) <> Format(Actual) then
            Error(AssertAreEqualErr, Expected, Actual, Message);
    end;

    local procedure AssertAreNotEqual(NotExpected: Variant; Actual: Variant; Message: Text)
    begin
        if Format(NotExpected) = Format(Actual) then
            Error(AssertAreNotEqualErr, Actual, Message);
    end;

    local procedure AssertIsTrue(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(AssertIsTrueErr, Message);
    end;

    local procedure AssertExpectedError(ExpectedSubstring: Text)
    var
        ActualError: Text;
    begin
        ActualError := GetLastErrorText();
        if StrPos(ActualError, ExpectedSubstring) = 0 then
            Error(AssertExpectedErrorErr, ExpectedSubstring, ActualError);
        ClearLastError();
    end;

    [Test]
    procedure BatchProcessorProcessesMultipleApprovedRequestsInOneRun()
    var
        RechargeRequest: Record "ICR Recharge Request";
        ICRBatchProcessor: Codeunit "ICR Batch Processor";
        DocNo1: Code[20];
        DocNo2: Code[20];
        DocNo3: Code[20];
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Chunks: Integer;
    begin
        // [GIVEN] Three Approved Recharge Requests and one Draft request that must be skipped
        Initialize();
        DeleteAllRequests();

        DocNo1 := CreateApprovedRequest();
        DocNo2 := CreateApprovedRequest();
        DocNo3 := CreateApprovedRequest();
        CreateDraftRequest();

        // [WHEN] The Batch Processor is invoked as it would be from a Job Queue Entry
        ICRBatchProcessor.ProcessAll(Processed, Succeeded, Failed, Chunks);

        // [THEN] All three Approved requests were processed in a single job
        AssertAreEqual(3, Processed, 'Batch Processor should process all three Approved requests in one job.');
        AssertAreEqual(3, Succeeded, 'All three requests should have succeeded.');
        AssertAreEqual(0, Failed, 'No requests should have failed.');
        AssertIsTrue(Chunks >= 1, 'At least one chunk should have been committed.');

        // [THEN] Each Approved request has been transitioned to Posted, Draft is untouched
        RechargeRequest.Get(DocNo1);
        AssertAreEqual(RechargeRequest.Status::Posted.AsInteger(), RechargeRequest.Status.AsInteger(), 'Request 1 should be Posted after batch run.');
        RechargeRequest.Get(DocNo2);
        AssertAreEqual(RechargeRequest.Status::Posted.AsInteger(), RechargeRequest.Status.AsInteger(), 'Request 2 should be Posted after batch run.');
        RechargeRequest.Get(DocNo3);
        AssertAreEqual(RechargeRequest.Status::Posted.AsInteger(), RechargeRequest.Status.AsInteger(), 'Request 3 should be Posted after batch run.');

        // Cleanup
        DeleteAllRequests();
    end;

    [Test]
    procedure BatchProcessorUpdatesLastJobStatusInSetup()
    var
        ICRSetup: Record "ICR Setup";
        ICRBatchProcessor: Codeunit "ICR Batch Processor";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Chunks: Integer;
        StatusBefore: Text[250];
    begin
        // [GIVEN] A configured Setup and two Approved Recharge Requests
        Initialize();
        DeleteAllRequests();

        ICRSetup.GetSetup();
        StatusBefore := ICRSetup."Last Job Status";

        CreateApprovedRequest();
        CreateApprovedRequest();

        // [WHEN] The Batch Processor runs
        ICRBatchProcessor.ProcessAll(Processed, Succeeded, Failed, Chunks);

        // [THEN] Setup."Last Job Status" has been updated with the run outcome
        ICRSetup.GetSetup();
        AssertAreNotEqual(StatusBefore, ICRSetup."Last Job Status", 'Last Job Status should be updated after a batch run.');
        AssertIsTrue(StrPos(ICRSetup."Last Job Status", 'OK') > 0, 'Last Job Status should indicate success (OK).');
        AssertIsTrue(ICRSetup."Last Job Run DateTime" <> 0DT, 'Last Job Run DateTime should be populated.');

        // Cleanup
        DeleteAllRequests();
    end;

    [Test]
    procedure BatchProcessorIsIdempotentAcrossReRuns()
    var
        RechargeRequest: Record "ICR Recharge Request";
        ICRBatchProcessor: Codeunit "ICR Batch Processor";
        DocNo: Code[20];
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Chunks: Integer;
    begin
        // [GIVEN] One Approved Recharge Request
        Initialize();
        DeleteAllRequests();
        DocNo := CreateApprovedRequest();

        // [WHEN] The Batch Processor runs twice
        ICRBatchProcessor.ProcessAll(Processed, Succeeded, Failed, Chunks);
        AssertAreEqual(1, Processed, 'First run should process the single Approved request.');

        ICRBatchProcessor.ProcessAll(Processed, Succeeded, Failed, Chunks);

        // [THEN] The second run finds zero Approved requests — the first run already moved it to Posted
        AssertAreEqual(0, Processed, 'Second run must not re-process an already-Posted request (idempotency).');
        AssertAreEqual(0, Succeeded, 'Second run should have zero successes.');
        AssertAreEqual(0, Failed, 'Second run should have zero failures.');

        // Request is still Posted, not double-transitioned
        RechargeRequest.Get(DocNo);
        AssertAreEqual(RechargeRequest.Status::Posted.AsInteger(), RechargeRequest.Status.AsInteger(), 'Request should remain Posted after the idempotent second run.');

        // Cleanup
        DeleteAllRequests();
    end;

    [Test]
    procedure BatchProcessorHonoursChunkSizeInSetup()
    var
        ICRSetup: Record "ICR Setup";
        ICRBatchProcessor: Codeunit "ICR Batch Processor";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Chunks: Integer;
        i: Integer;
        SavedChunkSize: Integer;
    begin
        // [GIVEN] Batch Chunk Size = 2 and four Approved requests
        Initialize();
        DeleteAllRequests();

        ICRSetup.GetSetup();
        SavedChunkSize := ICRSetup."Batch Chunk Size";
        ICRSetup."Batch Chunk Size" := 2;
        ICRSetup.Modify(true);

        for i := 1 to 4 do
            CreateApprovedRequest();

        // [WHEN] The Batch Processor runs
        ICRBatchProcessor.ProcessAll(Processed, Succeeded, Failed, Chunks);

        // [THEN] Four requests processed across exactly two committed chunks (4 / 2)
        AssertAreEqual(4, Processed, 'All four Approved requests should have been processed.');
        AssertAreEqual(2, Chunks, 'With chunk size 2 and 4 requests, exactly 2 chunks should have been committed.');

        // Restore Setup for downstream tests
        ICRSetup.GetSetup();
        ICRSetup."Batch Chunk Size" := SavedChunkSize;
        if ICRSetup."Batch Chunk Size" = 0 then
            ICRSetup."Batch Chunk Size" := 50;
        ICRSetup.Modify(true);
        DeleteAllRequests();
    end;

    [Test]
    procedure BatchProcessorNoWorkPathUpdatesSetupCleanly()
    var
        ICRSetup: Record "ICR Setup";
        ICRBatchProcessor: Codeunit "ICR Batch Processor";
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Chunks: Integer;
    begin
        // [GIVEN] No Approved recharge requests exist
        Initialize();
        DeleteAllRequests();

        // [WHEN] The Batch Processor runs
        ICRBatchProcessor.ProcessAll(Processed, Succeeded, Failed, Chunks);

        // [THEN] Zero counters and a 'No eligible' status line are recorded
        AssertAreEqual(0, Processed, 'No work path should report zero processed.');
        AssertAreEqual(0, Chunks, 'No work path should commit zero chunks.');

        ICRSetup.GetSetup();
        AssertIsTrue(StrPos(ICRSetup."Last Job Status", 'No eligible') > 0, 'Last Job Status should note that no eligible requests were found.');
    end;

    local procedure CreateApprovedRequest(): Code[20]
    var
        RechargeRequest: Record "ICR Recharge Request";
    begin
        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest.Status := RechargeRequest.Status::Approved;
        RechargeRequest.Modify(true);
        exit(RechargeRequest."No.");
    end;

    local procedure CreateDraftRequest(): Code[20]
    var
        RechargeRequest: Record "ICR Recharge Request";
    begin
        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        // Status defaults to Draft on OnInsert
        exit(RechargeRequest."No.");
    end;

    /// <summary>
    /// Spec-mandated test: 'TestTotalAllocationLimit'.
    /// Verifies that the core business logic rejects a Recharge Request whose
    /// total allocation exceeds 100% of the header Total Amount. The test
    /// builds a request with Total Amount = 1000 and inserts two recharge
    /// lines whose Allocated Amount sum (700 + 500 = 1200) is 120% of the
    /// header total, then asserts that ICR Management.CalculateAllocations
    /// raises an error naming the over-allocation.
    /// </summary>
    [Test]
    procedure TestTotalAllocationLimit()
    var
        RechargeRequest: Record "ICR Recharge Request";
        RechargeLine: Record "ICR Recharge Line";
        ICRMgmt: Codeunit "ICR Management";
    begin
        // [GIVEN] Setup data materialised by Initialize and a Recharge Request
        // with Total Amount 1000 and two lines whose Allocated Amount sum
        // exceeds the header total (700 + 500 = 1200, i.e. 120%).
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Fixed Percentage";
        RechargeRequest.Modify(true);

        // Allocated Amount is written directly rather than derived from
        // Allocation % via Validate because the Allocation % field is
        // constrained to MaxValue = 100 on the table and would otherwise
        // reject a value that models the > 100% overflow scenario.
        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 10000;
        RechargeLine."Allocated Amount" := 700;
        RechargeLine.Insert(false);

        RechargeLine.Init();
        RechargeLine."Document No." := RechargeRequest."No.";
        RechargeLine."Line No." := 20000;
        RechargeLine."Allocated Amount" := 500;
        RechargeLine.Insert(false);

        // [WHEN] The allocation-limit check is invoked
        asserterror ICRMgmt.CalculateAllocations(RechargeRequest);

        // [THEN] An error is raised that names the over-allocation condition.
        // The Management codeunit's ExceedsErr contains both phrases below.
        AssertExpectedError('Total allocated');
        AssertExpectedError('exceeds source amount');

        // Cleanup
        RechargeLine.SetRange("Document No.", RechargeRequest."No.");
        RechargeLine.DeleteAll();
        RechargeRequest.Delete();
    end;

    /// <summary>
    /// Spec-mandated test: 'TestDuplicatePosting'.
    /// Verifies that the core business logic rejects an attempt to post a
    /// Recharge Request whose Status is already Posted. The test forces the
    /// request into Status = Posted, calls ICR Management.PostRequest, and
    /// asserts that the codeunit raises an error naming the document.
    /// </summary>
    [Test]
    procedure TestDuplicatePosting()
    var
        RechargeRequest: Record "ICR Recharge Request";
        ICRMgmt: Codeunit "ICR Management";
        DocNo: Code[20];
    begin
        // [GIVEN] Setup data materialised by Initialize and a Recharge Request
        // that has already been driven to Status = Posted.
        Initialize();
        DeleteAllRequests();

        RechargeRequest.Init();
        RechargeRequest.Insert(true);
        DocNo := RechargeRequest."No.";
        RechargeRequest."Total Amount" := 1000;
        RechargeRequest."Allocation Basis" := RechargeRequest."Allocation Basis"::"Fixed Percentage";
        RechargeRequest.Status := RechargeRequest.Status::Posted;
        RechargeRequest.Modify(true);

        // [WHEN] PostRequest is invoked against the already-Posted document
        asserterror ICRMgmt.PostRequest(RechargeRequest);

        // [THEN] The duplicate-posting guard raises an error naming the
        // document number, and the record is not double-transitioned.
        AssertExpectedError(DocNo);

        // Re-read the header — Status must still be Posted (unchanged by the
        // rejected call) so we know the guard fired BEFORE any Modify would
        // have re-written the record.
        RechargeRequest.Get(DocNo);
        AssertAreEqual(
            RechargeRequest.Status::Posted.AsInteger(),
            RechargeRequest.Status.AsInteger(),
            'Status must remain Posted after the duplicate-posting attempt is rejected.');

        // Cleanup
        RechargeRequest.Delete();
    end;

}
