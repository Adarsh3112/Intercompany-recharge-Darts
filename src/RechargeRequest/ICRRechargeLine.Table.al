table 50103 "ICR Recharge Line"
{
    Caption = 'Recharge Line';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    LookupPageId = "ICR Recharge Lines";
    DrillDownPageId = "ICR Recharge Lines";

    fields
    {
        field(1; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
            TableRelation = "ICR Recharge Request"."No.";
            NotBlank = true;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Target Partner"; Code[20])
        {
            Caption = 'Target Partner';
            DataClassification = CustomerContent;
            TableRelation = "IC Partner";

            trigger OnValidate()
            var
                PartnerMapping: Record "ICR Partner Mapping";
            begin
                if "Target Partner" = '' then begin
                    "Target IC G/L Account" := '';
                    exit;
                end;
                if PartnerMapping.Get("Target Partner") then
                    if "Target IC G/L Account" = '' then
                        "Target IC G/L Account" := PartnerMapping."IC G/L Account";
            end;
        }
        field(4; "Allocation %"; Decimal)
        {
            Caption = 'Allocation %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;

            trigger OnValidate()
            var
                Header: Record "ICR Recharge Request";
            begin
                if Header.Get("Document No.") then
                    "Allocated Amount" := Round(Header."Total Amount" * "Allocation %" / 100, 0.01);
            end;
        }
        field(5; "Allocated Amount"; Decimal)
        {
            Caption = 'Allocated Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
            MinValue = 0;
        }
        field(6; "Target IC G/L Account"; Code[20])
        {
            Caption = 'Target IC G/L Account';
            DataClassification = CustomerContent;
            TableRelation = "IC G/L Account";
        }
        field(7; "Posted"; Boolean)
        {
            Caption = 'Posted';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Document No.", "Line No.")
        {
            Clustered = true;
        }
        key(TargetPartner; "Target Partner")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Document No.", "Line No.", "Target Partner", "Allocated Amount")
        {
        }
        fieldgroup(Brick; "Document No.", "Line No.", "Target Partner", "Allocation %", "Allocated Amount", "Posted")
        {
        }
    }

    trigger OnInsert()
    begin
        if "Line No." = 0 then
            "Line No." := GetNextLineNo();
    end;

    trigger OnModify()
    begin
        TestNotPosted();
    end;

    trigger OnDelete()
    begin
        TestNotPosted();
    end;

    local procedure GetNextLineNo(): Integer
    var
        RechargeLine: Record "ICR Recharge Line";
    begin
        RechargeLine.SetRange("Document No.", "Document No.");
        if RechargeLine.FindLast() then
            exit(RechargeLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure TestNotPosted()
    begin
        if "Posted" then
            Error(PostedLineErr, "Document No.", "Line No.");
    end;

    var
        PostedLineErr: Label 'Recharge line %1/%2 has already been posted and cannot be changed or deleted. Create a correcting entry instead.', Comment = '%1 = Document No., %2 = Line No.';
}
