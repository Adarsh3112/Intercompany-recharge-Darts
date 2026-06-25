table 50102 "IC Recharge Request Header"
{
    Caption = 'IC Recharge Request Header';
    DataClassification = CustomerContent;
    TableType = Normal;
    LookupPageId = "IC Recharge Request List";
    DrillDownPageId = "IC Recharge Request List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
            NotBlank = true;

            trigger OnValidate()
            begin
                if "No." <> xRec."No." then begin
                    ICRechargeSetup.GetRecordOnce();
                end;
            end;
        }
        field(2; "Description"; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; "Status"; Enum "IC Recharge Request Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(4; "Document Date"; Date)
        {
            Caption = 'Document Date';
            DataClassification = CustomerContent;
        }
        field(5; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            DataClassification = CustomerContent;
        }
        field(6; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency.Code;
        }
        field(7; "IC Partner Code"; Code[20])
        {
            Caption = 'IC Partner Code';
            DataClassification = CustomerContent;
            TableRelation = "IC Partner".Code;

            trigger OnValidate()
            begin
                if "IC Partner Code" <> '' then begin
                    ICPartner.Get("IC Partner Code");
                    "IC Partner Name" := ICPartner.Name;
                end else
                    "IC Partner Name" := '';
            end;
        }
        field(8; "IC Partner Name"; Text[100])
        {
            Caption = 'IC Partner Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(9; "Recharge Method"; Enum "IC Recharge Method")
        {
            Caption = 'Recharge Method';
            DataClassification = CustomerContent;
        }
        field(10; "Total Amount"; Decimal)
        {
            Caption = 'Total Amount';
            DataClassification = CustomerContent;
            Editable = false;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
        }
        field(11; "Created By"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            TableRelation = User."User Name";
        }
        field(12; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(13; "Last Modified DateTime"; DateTime)
        {
            Caption = 'Last Modified DateTime';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(14; "External Document No."; Code[35])
        {
            Caption = 'External Document No.';
            DataClassification = CustomerContent;
        }
        field(15; "Reason Code"; Text[250])
        {
            Caption = 'Reason / Notes';
            DataClassification = CustomerContent;
        }
        field(16; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
            Editable = false;
        }
        field(17; "Source Amount"; Decimal)
        {
            Caption = 'Source Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";

            trigger OnValidate()
            begin
                if "Source Amount" <> xRec."Source Amount" then
                    Status := Status::Draft;
            end;
        }
        field(18; "Posted"; Boolean)
        {
            Caption = 'Posted';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Indicates whether this IC Recharge Request has already been posted to the IC General Journal and IC Outbox. Prevents duplicate posting.';
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(Status; "Status") { }
        key(DocumentDate; "Document Date") { }
    }

    var
        ICRechargeSetup: Record "IC Recharge Setup";
        ICPartner: Record "IC Partner";

    trigger OnInsert()
    var
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            ICRechargeSetup.GetRecordOnce();
            ICRechargeSetup.TestField("IC Recharge Request Nos.");
            if NoSeries.AreRelated(ICRechargeSetup."IC Recharge Request Nos.", xRec."No. Series") then
                "No. Series" := xRec."No. Series"
            else
                "No. Series" := ICRechargeSetup."IC Recharge Request Nos.";
            "No." := NoSeries.GetNextNo("No. Series");
        end;
        "Created By" := CopyStr(UserId(), 1, MaxStrLen("Created By"));
        "Created DateTime" := CurrentDateTime();
        "Last Modified DateTime" := CurrentDateTime();
        if "Document Date" = 0D then
            "Document Date" := WorkDate();
    end;

    trigger OnModify()
    begin
        "Last Modified DateTime" := CurrentDateTime();
    end;

    trigger OnDelete()
    begin
        TestStatusIsDraft();
        DeleteLines();
    end;

    /// <summary>
    /// Raises an error when the document status is not Draft.
    /// Used to enforce the locking pattern on header edits and deletions.
    /// </summary>
    procedure TestStatusIsDraft()
    begin
        if Status <> Status::Draft then
            Error(DocumentNotDraftErr, "No.");
    end;

    /// <summary>
    /// Transitions the document status forward by one step in the status flow.
    /// Draft → Validated → Pending Approval → Approved → Posted
    /// On the Approved → Posted transition the IC Recharge Post Management codeunit
    /// is called to write IC General Journal lines, push entries to the IC Outbox,
    /// and stamp the Posted flag to prevent duplicate posting.
    /// </summary>
    procedure AdvanceStatus()
    var
        ICRechargePostMgt: Codeunit "IC Recharge Post Management";
    begin
        case Status of
            Status::Draft:
                begin
                    CheckMandatoryFields();
                    Validate(Status, Status::Validated);
                end;
            Status::Validated:
                Validate(Status, Status::"Pending Approval");
            Status::"Pending Approval":
                Validate(Status, Status::Approved);
            Status::Approved:
                begin
                    // Guard: prevent duplicate posting.
                    if "Posted" then
                        Error(AlreadyPostedErr, "No.");
                    ICRechargePostMgt.PostRechargeRequest(Rec);
                    OnAfterPost(Rec);
                end;
            else
                Error(AlreadyPostedErr, "No.");
        end;
        // PostRechargeRequest sets Status and Posted directly on Rec and calls Modify;
        // for all other transitions we Modify here.
        if Status <> Status::Posted then
            Modify(true);
    end;

    /// <summary>
    /// Resets status back to Draft (e.g. for rejection or correction).
    /// </summary>
    procedure ResetToDraft()
    begin
        if Status = Status::Posted then
            Error(CannotResetPostedErr, "No.");
        Validate(Status, Status::Draft);
        Modify(true);
    end;

    local procedure CheckMandatoryFields()
    var
        ReqLine: Record "IC Recharge Request Line";
        ICRechargeCalc: Codeunit "IC Recharge Calculation";
    begin
        TestField("IC Partner Code");
        TestField("Document Date");
        TestField("Posting Date");

        ReqLine.SetRange("Request No.", "No.");
        if ReqLine.IsEmpty() then
            Error(LinesMissingErr);

        ReqLine.SetFilter("Recharge Amount", '<=0');
        if not ReqLine.IsEmpty() then
            Error(InvalidLineAmountErr);

        // Validate that allocations are balanced before moving to Validated status.
        ICRechargeCalc.ValidateAllocations(Rec);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPost(var ICRechargeHeader: Record "IC Recharge Request Header")
    begin
    end;

    procedure AssistEdit(OldICRechargeHeader: Record "IC Recharge Request Header"): Boolean
    var
        NoSeries: Codeunit "No. Series";
    begin
        ICRechargeSetup.GetRecordOnce();
        ICRechargeSetup.TestField("IC Recharge Request Nos.");
        if NoSeries.LookupRelatedNoSeries(ICRechargeSetup."IC Recharge Request Nos.", OldICRechargeHeader."No. Series", "No. Series") then begin
            "No." := NoSeries.GetNextNo("No. Series");
            exit(true);
        end;
    end;

    /// <summary>
    /// Recalculates Total Amount by summing all lines.
    /// </summary>
    procedure CalcTotalAmount()
    var
        ReqLine: Record "IC Recharge Request Line";
    begin
        ReqLine.SetRange("Request No.", "No.");
        ReqLine.CalcSums("Recharge Amount");
        "Total Amount" := ReqLine."Recharge Amount";
        Modify(false);
    end;

    local procedure DeleteLines()
    var
        ReqLine: Record "IC Recharge Request Line";
    begin
        ReqLine.SetRange("Request No.", "No.");
        ReqLine.DeleteAll(true);
    end;

    var
        DocumentNotDraftErr: Label 'IC Recharge Request %1 cannot be modified because its status is not Draft.', Comment = '%1 = Document No.';
        AlreadyPostedErr: Label 'IC Recharge Request %1 is already Posted and cannot be advanced further.', Comment = '%1 = Document No.';
        CannotResetPostedErr: Label 'IC Recharge Request %1 has been Posted and cannot be reset to Draft.', Comment = '%1 = Document No.';
        LinesMissingErr: Label 'The IC Recharge Request must have at least one line before it can be validated.';
        InvalidLineAmountErr: Label 'All lines must have a Recharge Amount greater than zero.';
}
