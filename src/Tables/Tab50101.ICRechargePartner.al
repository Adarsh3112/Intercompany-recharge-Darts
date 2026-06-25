table 50101 "IC Recharge Partner"
{
    Caption = 'IC Recharge Partner';
    DataClassification = CustomerContent;
    TableType = Normal;
    LookupPageId = "IC Recharge Partner List";
    DrillDownPageId = "IC Recharge Partner List";

    fields
    {
        field(1; "IC Partner Code"; Code[20])
        {
            Caption = 'IC Partner Code';
            DataClassification = CustomerContent;
            NotBlank = true;
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
        field(2; "IC Partner Name"; Text[100])
        {
            Caption = 'IC Partner Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(3; "Source G/L Account No."; Code[20])
        {
            Caption = 'Source G/L Account No.';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No.";

            trigger OnValidate()
            begin
                if "Source G/L Account No." <> '' then begin
                    GLAccount.Get("Source G/L Account No.");
                    "Source G/L Account Name" := GLAccount.Name;
                end else
                    "Source G/L Account Name" := '';
            end;
        }
        field(4; "Source G/L Account Name"; Text[100])
        {
            Caption = 'Source G/L Account Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(5; "Target IC G/L Account No."; Code[20])
        {
            Caption = 'Target IC G/L Account No.';
            DataClassification = CustomerContent;
            TableRelation = "IC G/L Account"."No.";

            trigger OnValidate()
            begin
                if "Target IC G/L Account No." <> '' then begin
                    ICGLAccount.Get("Target IC G/L Account No.");
                    "Target IC G/L Account Name" := ICGLAccount.Name;
                end else
                    "Target IC G/L Account Name" := '';
            end;
        }
        field(6; "Target IC G/L Account Name"; Text[100])
        {
            Caption = 'Target IC G/L Account Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(7; "Currency Rule"; Enum "IC Recharge Currency Rule")
        {
            Caption = 'Currency Rule';
            DataClassification = CustomerContent;
        }
        field(8; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency.Code;
        }
        field(9; "Auto-Send"; Boolean)
        {
            Caption = 'Auto-Send';
            DataClassification = CustomerContent;
        }
        field(10; "Auto-Accept"; Boolean)
        {
            Caption = 'Auto-Accept';
            DataClassification = CustomerContent;
        }
        field(11; "Enabled"; Boolean)
        {
            Caption = 'Enabled';
            DataClassification = CustomerContent;
        }
        field(12; "Recharge Method"; Enum "IC Recharge Method")
        {
            Caption = 'Recharge Method';
            DataClassification = CustomerContent;
        }
        field(13; "Description"; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "IC Partner Code")
        {
            Clustered = true;
        }
        key(SourceGL; "Source G/L Account No.") { }
    }

    var
        ICPartner: Record "IC Partner";
        GLAccount: Record "G/L Account";
        ICGLAccount: Record "IC G/L Account";
}
