/// <summary>
/// Temporary buffer table used by the 'ICR Reconciliation' report to
/// aggregate one row per (Recharge Request, Target Partner) tuple containing
/// the source amount, the allocation total, the posted intercompany total and
/// the reconciling difference. The report populates this buffer at run time
/// and displays it via the 'ICR Reconciliation Result' list page.
///
/// Marked TableType = Temporary so no schema is deployed at install time and
/// the aggregation lives only for the lifetime of a single report execution —
/// matching the technical hint on the requirement.
///
/// Object ID note: this table was relocated from 50106 to 50107 to free
/// table ID 50106 for the immutable 'ICR Audit Log' table required by the
/// audit log task. Because the table is temporary, no data migration is
/// needed — no rows are persisted between report runs.
/// </summary>
table 50107 "ICR Reconciliation Buffer"
{
    Caption = 'ICR Reconciliation Buffer';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = false;
        }
        field(2; "Source Company"; Text[30])
        {
            Caption = 'Source Company';
            DataClassification = SystemMetadata;
        }
        field(3; "Recharge Request No."; Code[20])
        {
            Caption = 'Recharge Request No.';
            DataClassification = SystemMetadata;
            TableRelation = "ICR Recharge Request"."No.";
        }
        field(4; "Target Partner"; Code[20])
        {
            Caption = 'Target Partner';
            DataClassification = SystemMetadata;
            TableRelation = "IC Partner";
        }
        field(5; "Period Start"; Date)
        {
            Caption = 'Period Start';
            DataClassification = SystemMetadata;
        }
        field(6; "Period End"; Date)
        {
            Caption = 'Period End';
            DataClassification = SystemMetadata;
        }
        field(7; "Request Status"; Enum "ICR Request Status")
        {
            Caption = 'Request Status';
            DataClassification = SystemMetadata;
        }
        field(8; "Source Amount"; Decimal)
        {
            Caption = 'Source Amount';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
        }
        field(9; "Allocated Amount"; Decimal)
        {
            Caption = 'Allocated Amount';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
        }
        field(10; "Posted Amount"; Decimal)
        {
            Caption = 'Posted Amount';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
        }
        field(11; "Difference"; Decimal)
        {
            Caption = 'Difference';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
        }
        field(12; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = SystemMetadata;
        }
        field(13; "Reconciliation Status"; Enum "ICR Reconciliation Status")
        {
            Caption = 'Reconciliation Status';
            DataClassification = SystemMetadata;
        }
        field(14; "Recharge Type"; Code[20])
        {
            Caption = 'Recharge Type';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Partner; "Target Partner", "Recharge Request No.")
        {
        }
        key(Company; "Source Company", "Target Partner")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Recharge Request No.", "Target Partner", "Source Amount", "Allocated Amount")
        {
        }
        fieldgroup(Brick; "Recharge Request No.", "Target Partner", "Source Amount", "Allocated Amount", "Posted Amount", "Difference", "Reconciliation Status")
        {
        }
    }

    /// <summary>
    /// Classifies the reconciliation row by comparing Source, Allocated and
    /// Posted amounts. Called by the report after all amounts have been
    /// aggregated so the buffer's "Reconciliation Status" is consistent with
    /// the numeric fields.
    /// </summary>
    procedure ClassifyStatus()
    begin
        "Difference" := "Source Amount" - "Allocated Amount";

        if "Posted Amount" = 0 then
            "Reconciliation Status" := "Reconciliation Status"::Unposted
        else
            "Reconciliation Status" := "Reconciliation Status"::Posted;

        // Balanced/Unbalanced classification takes precedence over posted
        // state so unbalanced posted rows surface as Unbalanced — the more
        // actionable state for a reconciliation user.
        if "Difference" <> 0 then
            "Reconciliation Status" := "Reconciliation Status"::Unbalanced
        else
            if "Reconciliation Status" <> "Reconciliation Status"::Unposted then
                "Reconciliation Status" := "Reconciliation Status"::Balanced;
    end;
}
