/// <summary>
/// List page used by the 'ICR Reconciliation' report to render the aggregated
/// buffer rows. Bound to the temporary ICR Reconciliation Buffer table and
/// opened from the report at the end of the OnPostReport trigger. The page is
/// read-only — reconciliation rows exist only for the duration of the report
/// run and are not persisted.
/// </summary>
page 50106 "ICR Reconciliation Result"
{
    Caption = 'ICR Reconciliation Result';
    PageType = List;
    SourceTable = "ICR Reconciliation Buffer";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Source Company"; Rec."Source Company")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source company whose ledger entries are being reconciled.';
                }
                field("Recharge Request No."; Rec."Recharge Request No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Intercompany Recharge Request that produced this reconciliation row.';
                }
                field("Recharge Type"; Rec."Recharge Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharge type or category configured on the Recharge Request.';
                }
                field("Target Partner"; Rec."Target Partner")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the intercompany partner that received the allocation.';
                }
                field("Period Start"; Rec."Period Start")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the start of the reconciliation period filter used when the report was run.';
                }
                field("Period End"; Rec."Period End")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the end of the reconciliation period filter used when the report was run.';
                }
                field("Request Status"; Rec."Request Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lifecycle status of the underlying Recharge Request.';
                }
                field("Source Amount"; Rec."Source Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total source amount taken from the source ledger entry / Recharge Request header, prorated to the partner share.';
                }
                field("Allocated Amount"; Rec."Allocated Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total amount allocated to this partner by the recharge lines.';
                }
                field("Posted Amount"; Rec."Posted Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total amount that has actually been posted through the intercompany recharge for this partner.';
                }
                field("Difference"; Rec."Difference")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies Source Amount minus Allocated Amount for this partner. A non-zero difference signals an unreconciled allocation.';
                    StyleExpr = DifferenceStyle;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency of the source, allocated and posted amounts.';
                }
                field("Reconciliation Status"; Rec."Reconciliation Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reconciliation classification of this row: Balanced, Unbalanced, Posted, or Unposted.';
                    StyleExpr = StatusStyle;
                }
            }
        }
    }

    var
        DifferenceStyle: Text;
        StatusStyle: Text;

    /// <summary>
    /// Accepts a caller-owned temporary ICR Reconciliation Buffer and copies
    /// every row into the page's own temporary Rec. Because Rec is temporary,
    /// the transfer preserves the in-memory result set produced by the
    /// 'ICR Reconciliation' report for the lifetime of the page.
    /// </summary>
    procedure SetSourceRecords(var SourceBuffer: Record "ICR Reconciliation Buffer" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();

        SourceBuffer.Reset();
        if not SourceBuffer.FindSet() then
            exit;
        repeat
            Rec.Init();
            Rec.TransferFields(SourceBuffer, true);
            Rec.Insert();
        until SourceBuffer.Next() = 0;

        Rec.Reset();
        if Rec.FindFirst() then;
    end;

    trigger OnAfterGetRecord()
    begin
        if Rec."Difference" <> 0 then
            DifferenceStyle := 'Unfavorable'
        else
            DifferenceStyle := 'Favorable';

        case Rec."Reconciliation Status" of
            Rec."Reconciliation Status"::Balanced,
            Rec."Reconciliation Status"::Posted:
                StatusStyle := 'Favorable';
            Rec."Reconciliation Status"::Unbalanced:
                StatusStyle := 'Unfavorable';
            else
                StatusStyle := 'Ambiguous';
        end;
    end;
}
