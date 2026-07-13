page 50103 "ICR Recharge Lines"
{
    Caption = 'Recharge Lines';
    PageType = ListPart;
    SourceTable = "ICR Recharge Line";
    AutoSplitKey = true;
    DelayedInsert = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Target Partner"; Rec."Target Partner")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the intercompany partner that receives a share of this recharge.';
                }
                field("Allocation %"; Rec."Allocation %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the percentage of the header Total Amount allocated to this partner. All lines must sum to 100 percent.';
                }
                field("Allocated Amount"; Rec."Allocated Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the monetary amount allocated to this partner. Recalculated automatically when Allocation % changes.';
                }
                field("Target IC G/L Account"; Rec."Target IC G/L Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the intercompany G/L account in the target partner used when posting this line. Defaulted from the Partner Mapping when the Target Partner is set.';
                }
                field("Posted"; Rec."Posted")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies whether this line has been posted to the intercompany outbox and the general ledger.';
                }
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the internal line number that, together with the Document No., uniquely identifies this recharge line.';
                }
            }
        }
    }
}
