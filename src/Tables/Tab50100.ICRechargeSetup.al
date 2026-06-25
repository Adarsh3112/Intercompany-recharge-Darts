table 50100 "IC Recharge Setup"
{
    Caption = 'IC Recharge Setup';
    DataClassification = CustomerContent;
    TableType = Normal;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = CustomerContent;
        }
        field(2; "IC Partner Code"; Code[20])
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
        field(3; "IC Partner Name"; Text[100])
        {
            Caption = 'IC Partner Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(4; "Recharge Method"; Enum "IC Recharge Method")
        {
            Caption = 'Recharge Method';
            DataClassification = CustomerContent;
        }
        field(5; "Default Currency Code"; Code[10])
        {
            Caption = 'Default Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency.Code;
        }
        field(6; "Auto-Send"; Boolean)
        {
            Caption = 'Auto-Send';
            DataClassification = CustomerContent;
        }
        field(7; "Auto-Accept"; Boolean)
        {
            Caption = 'Auto-Accept';
            DataClassification = CustomerContent;
        }
        field(8; "Enabled"; Boolean)
        {
            Caption = 'Enabled';
            DataClassification = CustomerContent;
        }
        field(9; "IC Recharge Request Nos."; Code[20])
        {
            Caption = 'IC Recharge Request Nos.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(10; "IC Recharge Source Code"; Code[10])
        {
            Caption = 'IC Recharge Source Code';
            DataClassification = CustomerContent;
            TableRelation = "Source Code";
            ToolTip = 'Specifies the source code to stamp on IC General Journal and IC Outbox entries created by the IC Recharge posting engine. Used for audit traceability.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        ICPartner: Record "IC Partner";

    /// <summary>
    /// Returns the singleton setup record, creating it if it does not exist.
    /// </summary>
    procedure GetRecordOnce()
    begin
        if not Get('') then begin
            Init();
            "Primary Key" := '';
            Insert(true);
        end;
    end;
}
