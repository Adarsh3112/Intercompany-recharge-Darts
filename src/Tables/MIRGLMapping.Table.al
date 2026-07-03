table 50102 "MIR GL Mapping"
{
    Caption = 'MIR GL Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "MIR GL Mapping List";
    DrillDownPageId = "MIR GL Mapping List";

    fields
    {
        field(1; "Partner Code"; Code[20])
        {
            Caption = 'Partner Code';
            DataClassification = CustomerContent;
            TableRelation = "MIR Partner Mapping"."Partner Code";
            NotBlank = true;
        }
        field(2; "Source GL Account"; Code[20])
        {
            Caption = 'Source GL Account';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No.";
            NotBlank = true;
        }
        field(3; "Target IC GL Acc."; Code[20])
        {
            Caption = 'Target IC GL Acc.';
            DataClassification = CustomerContent;
            TableRelation = "IC G/L Account"."No.";
        }
        field(4; "Recharge Type"; Code[20])
        {
            Caption = 'Recharge Type';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Partner Code", "Source GL Account")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Partner Code", "Source GL Account", "Target IC GL Acc.")
        {
        }
        fieldgroup(Brick; "Partner Code", "Source GL Account", "Target IC GL Acc.", "Recharge Type")
        {
        }
    }
}
