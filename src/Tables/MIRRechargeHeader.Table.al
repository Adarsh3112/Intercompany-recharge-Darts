table 50103 "MIR Recharge Header"
{
    Caption = 'MIR Recharge Header';
    DataClassification = CustomerContent;
    LookupPageId = "MIR Recharge Header List";
    DrillDownPageId = "MIR Recharge Header List";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                MIRSetup: Record "MIR Setup";
                NoSeries: Codeunit "No. Series";
            begin
                // Allow manual entry of a number from outside the series only when the user
                // explicitly changes "No.". Mirrors the standard BC pattern on documents.
                if Rec."No." <> xRec."No." then begin
                    MIRSetup.GetSetup();
                    NoSeries.TestManual(MIRSetup."Recharge Request Nos.");
                    Rec."No. Series" := '';
                end;
            end;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; Status; Enum "MIR Recharge Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(4; "Source Amount"; Decimal)
        {
            Caption = 'Source Amount';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 0;
            AutoFormatType = 1;
            AutoFormatExpression = Rec."Currency Code";
        }
        field(5; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency.Code;
        }
        field(6; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            DataClassification = CustomerContent;
        }
        field(7; "External ID"; Code[50])
        {
            Caption = 'External ID';
            DataClassification = CustomerContent;
        }
        field(8; "Created By"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(9; "Created At"; DateTime)
        {
            Caption = 'Created At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(10; "No. Series"; Code[20])
        {
            Caption = 'No. Series';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(Status; Status, "Posting Date")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", Description, Status, "Source Amount", "Currency Code")
        {
        }
        fieldgroup(Brick; "No.", Description, Status, "Source Amount", "Currency Code", "Posting Date")
        {
        }
    }

    trigger OnInsert()
    var
        MIRSetup: Record "MIR Setup";
        NoSeries: Codeunit "No. Series";
    begin
        // GetSetup() is the canonical accessor — it auto-creates the singleton if missing
        // so first-time document creation does not fail because Setup was never opened.
        MIRSetup.GetSetup();

        if Rec."No." = '' then begin
            if MIRSetup."Recharge Request Nos." = '' then
                Error('You must configure ''Recharge Request Nos.'' on the MIR Setup page before creating a MIR Recharge Header.');
            Rec."No." := NoSeries.GetNextNo(MIRSetup."Recharge Request Nos.", Rec."Posting Date");
            Rec."No. Series" := MIRSetup."Recharge Request Nos.";
        end;

        // Defaults applied at insert time so audit fields are immediately populated.
        if Rec."Posting Date" = 0D then
            Rec."Posting Date" := WorkDate();
        if Rec."Created At" = 0DT then
            Rec."Created At" := CurrentDateTime();
        if Rec."Created By" = '' then
            Rec."Created By" := CopyStr(UserId(), 1, MaxStrLen(Rec."Created By"));

        // Newly inserted documents always start in Draft. The Status field is read-only on
        // the page and is only mutated via the MIR Recharge Status Mgt codeunit.
        Rec.Status := Rec.Status::Draft;
    end;

    trigger OnModify()
    var
        ExistingRec: Record "MIR Recharge Header";
        StatusMgt: Codeunit "MIR Recharge Status Mgt";
    begin
        // Field-locking: once a document has left Draft, only the Status field itself may
        // change (and only through the status-management codeunit). This trigger is the
        // authoritative gate — it fires for changes from pages, APIs, and codeunits alike.
        if not ExistingRec.Get(Rec."No.") then
            exit;

        // If the record is still in Draft in the database, all field edits are allowed.
        // If it has moved past Draft, every non-Status field must remain unchanged here.
        if ExistingRec.Status = ExistingRec.Status::Draft then
            exit;

        StatusMgt.CheckProtectedFieldsUnchanged(ExistingRec, Rec);
    end;

    trigger OnDelete()
    begin
        // Documents that have been posted or reversed represent immutable financial events;
        // deletion would break the audit trail. Closed/Rejected drafts are administrative
        // states that may be cleaned up.
        if Rec.Status in [Rec.Status::Posted, Rec.Status::Reversed] then
            Error('MIR Recharge Header %1 cannot be deleted because its status is %2. Create a reversal instead.', Rec."No.", Rec.Status);
    end;

    procedure AssistEdit(): Boolean
    var
        MIRSetup: Record "MIR Setup";
        MIRRechargeHeader: Record "MIR Recharge Header";
        NoSeries: Codeunit "No. Series";
    begin
        // Standard No. Series assist-edit — lets a user pick a different series interactively
        // when creating a new document, mirroring how Sales Header / Purchase Header behave.
        MIRSetup.GetSetup();
        MIRRechargeHeader := Rec;
        if NoSeries.LookupRelatedNoSeries(MIRSetup."Recharge Request Nos.", MIRRechargeHeader."No. Series") then begin
            MIRRechargeHeader."No." := NoSeries.GetNextNo(MIRRechargeHeader."No. Series", MIRRechargeHeader."Posting Date");
            Rec := MIRRechargeHeader;
            exit(true);
        end;
    end;
}
