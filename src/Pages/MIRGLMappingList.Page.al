page 50102 "MIR GL Mapping List"
{
    Caption = 'MIR GL Mapping';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "MIR GL Mapping";
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
                    ToolTip = 'Specifies the MIR Partner Mapping that this G/L mapping line belongs to.';
                }
                field("Source GL Account"; Rec."Source GL Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the G/L account in the source company whose balances feed the intercompany recharge.';
                }
                field("Target IC GL Acc."; Rec."Target IC GL Acc.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the IC G/L account used when sending the recharge to the partner company.';
                }
                field("Recharge Type"; Rec."Recharge Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharge category used to classify this mapping (for example, Services, Rent, Allocation).';
                }
            }
        }
    }
}
