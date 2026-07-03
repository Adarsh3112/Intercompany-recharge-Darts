page 50105 "MIR Recharge Line Subform"
{
    Caption = 'Lines';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "MIR Recharge Line";
    AutoSplitKey = true;
    DelayedInsert = true;

    layout
    {
        area(content)
        {
            repeater(LinesRepeater)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the line number within the recharge document. Assigned automatically.';
                    Visible = false;
                }
                field("Target Partner"; Rec."Target Partner")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the IC partner that will receive this allocated portion of the recharge.';
                }
                field("Allocation Basis"; Rec."Allocation Basis")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the allocation value is interpreted: Fixed % of the header''s source amount, an absolute Amount, a Dimension-driven share, or a Headcount-driven share.';
                }
                field("Allocation Value"; Rec."Allocation Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value to apply for the chosen allocation basis. For Fixed % this is the percentage; for Amount this is the absolute amount.';
                }
                field("Calculated Amount"; Rec."Calculated Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount derived from the allocation basis and the header''s source amount. Updated automatically when the allocation value changes.';
                    Editable = false;
                    StyleExpr = 'Strong';
                }
                field("Target IC GL Acc."; Rec."Target IC GL Acc.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the IC G/L account in the partner''s company that the recharge will post to.';
                }
                field("Allocation Trace"; Rec."Allocation Trace")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text trace that records how this allocation was derived. Surfaces in the audit log.';
                }
            }
        }
    }
}
