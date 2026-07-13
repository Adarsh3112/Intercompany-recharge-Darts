table 50102 "ICR Recharge Request"
{
    Caption = 'Recharge Request';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    LookupPageId = "ICR Recharge Request";
    DrillDownPageId = "ICR Recharge Request";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
        }
        field(2; "Status"; Enum "ICR Request Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }
        field(3; "Source Company"; Text[30])
        {
            Caption = 'Source Company';
            DataClassification = CustomerContent;

            trigger OnLookup()
            var
                Company: Record Company;
                CompanyList: Page Companies;
            begin
                CompanyList.LookupMode(true);
                if CompanyList.RunModal() = Action::LookupOK then begin
                    CompanyList.GetRecord(Company);
                    "Source Company" := CopyStr(Company.Name, 1, MaxStrLen("Source Company"));
                end;
            end;
        }
        field(4; "Recharge Type"; Code[20])
        {
            Caption = 'Recharge Type';
            DataClassification = CustomerContent;
        }
        field(5; "Allocation Basis"; Enum "ICR Allocation Basis")
        {
            Caption = 'Allocation Basis';
            DataClassification = CustomerContent;
        }
        field(6; "Source G/L Account"; Code[20])
        {
            Caption = 'Source G/L Account';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account";
        }
        field(7; "Total Amount"; Decimal)
        {
            Caption = 'Total Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
        }
        field(8; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency;
        }
        field(9; "Exchange Rate"; Decimal)
        {
            Caption = 'Exchange Rate';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
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
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "Source Company", "Recharge Type", "Status")
        {
        }
        fieldgroup(Brick; "No.", "Source Company", "Recharge Type", "Total Amount", "Currency Code", "Status")
        {
        }
    }

    trigger OnInsert()
    var
        ICRSetup: Record "ICR Setup";
        NoSeriesCU: Codeunit "No. Series";
        ICRMgt: Codeunit "ICR Management";
    begin
        if "No." = '' then begin
            ICRSetup.GetSetup();
            if ICRSetup."Recharge Request Nos." = '' then
                Error(NoSeriesNotSetupErr);
            "No. Series" := ICRSetup."Recharge Request Nos.";
            "No." := NoSeriesCU.GetNextNo("No. Series", 0D, true);
        end;

        "Status" := "Status"::Draft;

        // Audit — record the creation of the recharge request. The audit log
        // procedure is a no-op when Document No. is blank (safety net), so
        // this call is safe even in edge cases where the No. Series returned
        // an empty code.
        ICRMgt.LogAction('CREATED', "No.",
            CopyStr(StrSubstNo(AuditCreatedLbl, "Source Company", "Recharge Type"), 1, 250));
    end;

    var
        NoSeriesNotSetupErr: Label 'You must specify a value in the ''Recharge Request Nos.'' field on the ICR Setup page before you can create a new Recharge Request.';
        AuditCreatedLbl: Label 'Recharge Request created (Source Company: %1, Recharge Type: %2). Initial Status: Draft.', Comment = '%1 = Source Company, %2 = Recharge Type';
}
