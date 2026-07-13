table 50101 "ICR Partner Mapping"
{
    Caption = 'ICR Partner Mapping';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    LookupPageId = "ICR Partner Mappings";
    DrillDownPageId = "ICR Partner Mappings";

    fields
    {
        field(1; "Partner Code"; Code[20])
        {
            Caption = 'Partner Code';
            DataClassification = CustomerContent;
            TableRelation = "IC Partner";
            NotBlank = true;

            trigger OnValidate()
            var
                ICPartner: Record "IC Partner";
            begin
                if "Partner Code" = '' then
                    exit;
                if not ICPartner.Get("Partner Code") then
                    Error(PartnerNotFoundErr, "Partner Code");
            end;
        }
        field(2; "Target Company"; Text[30])
        {
            Caption = 'Target Company';
            DataClassification = CustomerContent;

            trigger OnLookup()
            var
                Company: Record Company;
                CompanyList: Page Companies;
            begin
                CompanyList.LookupMode(true);
                if CompanyList.RunModal() = Action::LookupOK then begin
                    CompanyList.GetRecord(Company);
                    "Target Company" := CopyStr(Company.Name, 1, MaxStrLen("Target Company"));
                end;
            end;

            trigger OnValidate()
            var
                Company: Record Company;
            begin
                if "Target Company" = '' then
                    exit;
                if not Company.Get("Target Company") then
                    Error(CompanyNotFoundErr, "Target Company");
            end;
        }
        field(3; "IC G/L Account"; Code[20])
        {
            Caption = 'IC G/L Account';
            DataClassification = CustomerContent;
            TableRelation = "IC G/L Account";
        }
        field(4; "Dimension Mapping"; Enum "ICR Dimension Mapping")
        {
            Caption = 'Dimension Mapping';
            DataClassification = CustomerContent;
        }
        field(5; "Auto-Send"; Boolean)
        {
            Caption = 'Auto-Send';
            DataClassification = CustomerContent;
        }
        field(6; "Auto-Accept"; Boolean)
        {
            Caption = 'Auto-Accept';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Partner Code")
        {
            Clustered = true;
        }
        key(TargetCompany; "Target Company")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Partner Code", "Target Company", "IC G/L Account")
        {
        }
        fieldgroup(Brick; "Partner Code", "Target Company", "IC G/L Account", "Auto-Send", "Auto-Accept")
        {
        }
    }

    var
        PartnerNotFoundErr: Label 'Intercompany Partner %1 does not exist. Create it on the IC Partners page first.', Comment = '%1 = Partner Code';
        CompanyNotFoundErr: Label 'Company %1 does not exist in this database. Use the lookup to select a valid company.', Comment = '%1 = Target Company name';
}
