table 50100 "MIR Setup"
{
    Caption = 'MIR Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; "Recharge Request Nos."; Code[20])
        {
            Caption = 'Recharge Request Nos.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(3; "Partner Mapping Nos."; Code[20])
        {
            Caption = 'Partner Mapping Nos.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(4; "IC Journal Template"; Code[10])
        {
            Caption = 'IC Journal Template';
            DataClassification = CustomerContent;
            TableRelation = "Gen. Journal Template".Name;

            trigger OnValidate()
            begin
                if Rec."IC Journal Template" <> xRec."IC Journal Template" then
                    Rec."IC Journal Batch" := '';
            end;
        }
        field(5; "IC Journal Batch"; Code[10])
        {
            Caption = 'IC Journal Batch';
            DataClassification = CustomerContent;
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("IC Journal Template"));
        }
        field(6; "Auto-Send Flag"; Boolean)
        {
            Caption = 'Auto-Send Flag';
            DataClassification = CustomerContent;
        }
        field(7; "Auto-Accept Flag"; Boolean)
        {
            Caption = 'Auto-Accept Flag';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetSetup()
    begin
        // Singleton accessor. Use Get('') so callers do not need to clear Rec's state first;
        // the empty Primary Key is the canonical singleton key (matches the Install codeunit).
        Rec.Reset();
        if not Rec.Get('') then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec.Insert();
        end;
    end;
}
