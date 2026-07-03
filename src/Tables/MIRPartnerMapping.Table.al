table 50101 "MIR Partner Mapping"
{
    Caption = 'MIR Partner Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "MIR Partner Mapping List";
    DrillDownPageId = "MIR Partner Mapping List";

    fields
    {
        field(1; "Partner Code"; Code[20])
        {
            Caption = 'Partner Code';
            DataClassification = CustomerContent;
            TableRelation = "IC Partner".Code;
            NotBlank = true;
        }
        field(2; "Source Company"; Text[30])
        {
            Caption = 'Source Company';
            DataClassification = CustomerContent;
            TableRelation = Company.Name;
        }
        field(3; "Target Company"; Text[30])
        {
            Caption = 'Target Company';
            DataClassification = CustomerContent;
            TableRelation = Company.Name;
        }
        field(4; "Curr. Handling Rule"; Enum "MIR Curr. Handling Rule")
        {
            Caption = 'Curr. Handling Rule';
            DataClassification = CustomerContent;
        }
        field(5; "Approval Threshold"; Decimal)
        {
            Caption = 'Approval Threshold';
            DataClassification = CustomerContent;
            MinValue = 0;
            DecimalPlaces = 2 : 2;
        }
    }

    keys
    {
        key(PK; "Partner Code")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Partner Code", "Target Company", "Approval Threshold")
        {
        }
        fieldgroup(Brick; "Partner Code", "Source Company", "Target Company")
        {
        }
    }

    trigger OnInsert()
    var
        MIRSetup: Record "MIR Setup";
        ICPartner: Record "IC Partner";
        NoSeries: Codeunit "No. Series";
        AssignedNo: Code[20];
    begin
        // Ensure Setup exists for downstream consumers (singleton auto-create).
        MIRSetup.GetSetup();

        // Auto-numbering only fires when the user did not supply a Partner Code.
        // Because "Partner Code" is FK to "IC Partner".Code (see TableRelation on field 1),
        // a number drawn from "Partner Mapping Nos." is only acceptable if it matches an
        // existing IC Partner. Otherwise the record would persist with a broken FK and any
        // downstream lookup would fail. We therefore peek the next number, verify it against
        // IC Partner, and only commit the assignment when the FK is valid. If validation
        // fails we surface a clear error directing the admin to either pick a valid IC
        // Partner code or to align the IC Partner master with the configured number series.
        if Rec."Partner Code" = '' then begin
            if MIRSetup."Partner Mapping Nos." = '' then
                Error('Partner Code must be specified. Configure ''Partner Mapping Nos.'' on the MIR Setup page or pick an existing IC Partner code from the lookup.');

            AssignedNo := NoSeries.GetNextNo(MIRSetup."Partner Mapping Nos.", 0D);
            if not ICPartner.Get(AssignedNo) then
                Error('Cannot auto-assign Partner Code %1 because no IC Partner with that code exists. Pick an existing IC Partner from the lookup, or create an IC Partner whose Code matches the ''Partner Mapping Nos.'' series in MIR Setup.', AssignedNo);

            // Use Validate so the TableRelation is checked explicitly and any future change
            // in the FK contract surfaces immediately.
            Rec.Validate("Partner Code", AssignedNo);
        end;
    end;
}
