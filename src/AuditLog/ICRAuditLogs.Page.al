/// <summary>
/// Read-only list page for the immutable ICR Audit Log. Users can browse the
/// history of significant actions on Recharge Requests but cannot insert,
/// modify or delete rows from this page — the underlying table's OnModify
/// and OnDelete triggers additionally reject any attempt made via API or
/// background code. New rows are created only by the 'ICR Management'
/// codeunit's LogAction procedure.
/// </summary>
page 50107 "ICR Audit Logs"
{
    Caption = 'ICR Audit Logs';
    PageType = List;
    SourceTable = "ICR Audit Log";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("Action Timestamp") order(descending);
    AboutTitle = 'ICR Audit Logs';
    AboutText = 'Immutable log of every significant action captured on an Intercompany Recharge Request (creation, submission, cancellation, posting, status changes).';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the surrogate primary key of the audit log entry.';
                }
                field("Action Timestamp"; Rec."Action Timestamp")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the exact date and time the action was recorded.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the ICR Recharge Request document number the action applies to.';
                }
                field("Action"; Rec."Action")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the action captured, for example CREATED, SUBMITTED, CANCELLED, ACTIVATED, POSTED, STATUS-CHANGED.';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the BC user that performed the action.';
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text description of the action captured by the calling process.';
                }
            }
        }
    }
}
