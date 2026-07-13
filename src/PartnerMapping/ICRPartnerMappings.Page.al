page 50101 "ICR Partner Mappings"
{
    Caption = 'ICR Partner Mappings';
    PageType = List;
    SourceTable = "ICR Partner Mapping";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = true;
    AboutTitle = 'ICR Partner Mappings';
    AboutText = 'Maintain the mapping between local IC Partners and their target companies, IC G/L accounts, dimension translation rules, and automation flags.';

    layout
    {
        area(Content)
        {
            repeater(Mappings)
            {
                field("Partner Code"; Rec."Partner Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Intercompany Partner code linked to this mapping. The value must exist in the standard IC Partner table.';
                }
                field("Target Company"; Rec."Target Company")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the destination company that recharge documents will be sent to. Use the lookup to pick a company that exists in this database.';
                }
                field("IC G/L Account"; Rec."IC G/L Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the IC G/L Account used when generating intercompany journal lines for this partner.';
                }
                field("Dimension Mapping"; Rec."Dimension Mapping")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how dimensions on source transactions should be handled when the recharge is sent to the target company.';
                }
                field("Auto-Send"; Rec."Auto-Send")
                {
                    ApplicationArea = All;
                    ToolTip = 'If enabled, recharge documents for this partner will be sent to the target company automatically after posting.';
                }
                field("Auto-Accept"; Rec."Auto-Accept")
                {
                    ApplicationArea = All;
                    ToolTip = 'If enabled, inbound recharge documents from this partner will be accepted automatically in the destination company.';
                }
            }
        }
    }
}
