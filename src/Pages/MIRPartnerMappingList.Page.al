page 50101 "MIR Partner Mapping List"
{
    Caption = 'MIR Partner Mapping';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "MIR Partner Mapping";
    Editable = true;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Partner Code"; Rec."Partner Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the IC Partner code that this mapping applies to. The value must reference an existing IC Partner record.';
                }
                field("Source Company"; Rec."Source Company")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the BC company that originates the intercompany recharge.';
                }
                field("Target Company"; Rec."Target Company")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the BC company that receives the intercompany recharge.';
                }
                field("Curr. Handling Rule"; Rec."Curr. Handling Rule")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which currency to use when posting the intercompany recharge: Source company currency, Target company currency, or a Fixed currency configured separately.';
                }
                field("Approval Threshold"; Rec."Approval Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount above which a recharge request for this partner requires explicit approval before posting.';
                }
            }
        }
    }
}
