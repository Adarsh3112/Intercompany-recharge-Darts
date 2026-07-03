page 50103 "MIR Recharge Header List"
{
    Caption = 'MIR Recharge Headers';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "MIR Recharge Header";
    CardPageId = "MIR Recharge Header Card";
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique number of the intercompany recharge document. Numbers are assigned automatically from the Recharge Request Nos. series on MIR Setup.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a short description that identifies what the intercompany recharge covers.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lifecycle status of the recharge document. Status changes only through the actions in the document card.';
                    StyleExpr = StatusStyleTxt;
                }
                field("Source Amount"; Rec."Source Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the gross amount in the source currency that will be recharged to the partner company.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency in which the source amount is expressed.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date that will be used as the G/L posting date when the recharge is posted.';
                }
                field("External ID"; Rec."External ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an external reference identifier supplied by the originating system, used to correlate this recharge with an upstream transaction.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who created the recharge document.';
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time at which the recharge document was created.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        // Visual hint mirroring standard BC document lists — colours a row according to
        // where the document sits in its lifecycle, so a list of mixed-status documents
        // can be scanned at a glance.
        case Rec.Status of
            Rec.Status::Draft:
                StatusStyleTxt := 'Standard';
            Rec.Status::Validated, Rec.Status::Approved:
                StatusStyleTxt := 'Favorable';
            Rec.Status::"Pending Approval":
                StatusStyleTxt := 'Ambiguous';
            Rec.Status::Rejected, Rec.Status::Reversed:
                StatusStyleTxt := 'Unfavorable';
            Rec.Status::Posted:
                StatusStyleTxt := 'StrongAccent';
            Rec.Status::Closed:
                StatusStyleTxt := 'Subordinate';
            else
                StatusStyleTxt := 'Standard';
        end;
    end;

    var
        StatusStyleTxt: Text;
}
