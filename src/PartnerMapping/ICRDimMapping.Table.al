table 50105 "ICR Dim Mapping"
{
    Caption = 'ICR Dim Mapping';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    LookupPageId = "ICR Dim Mappings";
    DrillDownPageId = "ICR Dim Mappings";

    fields
    {
        field(1; "Partner Code"; Code[20])
        {
            Caption = 'Partner Code';
            DataClassification = CustomerContent;
            TableRelation = "ICR Partner Mapping"."Partner Code";
            NotBlank = true;

            trigger OnValidate()
            var
                PartnerMapping: Record "ICR Partner Mapping";
            begin
                if "Partner Code" = '' then
                    exit;
                if not PartnerMapping.Get("Partner Code") then
                    Error(PartnerMappingMissingErr, "Partner Code");
            end;
        }
        field(2; "Source Dim. Code"; Code[20])
        {
            Caption = 'Source Dim. Code';
            DataClassification = CustomerContent;
            TableRelation = Dimension.Code;
            NotBlank = true;
        }
        field(3; "Source Dim. Value"; Code[20])
        {
            Caption = 'Source Dim. Value';
            DataClassification = CustomerContent;
            TableRelation = "Dimension Value".Code where("Dimension Code" = field("Source Dim. Code"));
        }
        field(4; "Target Dim. Code"; Code[20])
        {
            Caption = 'Target Dim. Code';
            DataClassification = CustomerContent;
            TableRelation = Dimension.Code;
            NotBlank = true;
        }
        field(5; "Target Dim. Value"; Code[20])
        {
            Caption = 'Target Dim. Value';
            DataClassification = CustomerContent;
            TableRelation = "Dimension Value".Code where("Dimension Code" = field("Target Dim. Code"));
        }
        field(6; "Mapping Type"; Enum "ICR Dim Mapping Type")
        {
            Caption = 'Mapping Type';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if "Mapping Type" = "Mapping Type"::"Same Code" then begin
                    // When the type is 'Same Code' the target should mirror the source.
                    // Auto-copy the source values so the row is internally consistent
                    // and ready to be used by the posting validation without
                    // requiring the user to duplicate the codes manually.
                    if "Target Dim. Code" = '' then
                        "Target Dim. Code" := "Source Dim. Code";
                    if "Target Dim. Value" = '' then
                        "Target Dim. Value" := "Source Dim. Value";
                end;
            end;
        }
    }

    keys
    {
        key(PK; "Partner Code", "Source Dim. Code", "Source Dim. Value")
        {
            Clustered = true;
        }
        key(SourceLookup; "Source Dim. Code", "Source Dim. Value")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Partner Code", "Source Dim. Code", "Source Dim. Value", "Target Dim. Code", "Target Dim. Value")
        {
        }
        fieldgroup(Brick; "Partner Code", "Source Dim. Code", "Source Dim. Value", "Target Dim. Code", "Target Dim. Value", "Mapping Type")
        {
        }
    }

    /// <summary>
    /// Attempts to locate an ICR Dim Mapping row for the supplied partner and
    /// source dimension code/value combination. Returns TRUE when a row is
    /// found; the calling code is expected to inspect the current record for
    /// the resolved Target Dim. Code / Target Dim. Value.
    ///
    /// This is the single lookup used by the posting validation in
    /// codeunit "ICR Management" so that the resolution rules live with the
    /// data they describe.
    /// </summary>
    procedure FindMapping(PartnerCode: Code[20]; SourceDimCode: Code[20]; SourceDimValue: Code[20]): Boolean
    begin
        Reset();
        SetRange("Partner Code", PartnerCode);
        SetRange("Source Dim. Code", SourceDimCode);
        SetRange("Source Dim. Value", SourceDimValue);
        exit(FindFirst());
    end;

    var
        PartnerMappingMissingErr: Label 'Partner Mapping %1 does not exist. Create it on the ICR Partner Mappings page before adding dimension mappings.', Comment = '%1 = Partner Code';
}
