page 50101 "IC Recharge Partner List"
{
    Caption = 'IC Recharge Partners';
    PageType = List;
    SourceTable = "IC Recharge Partner";
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "IC Recharge Partner Card";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("IC Partner Code"; Rec."IC Partner Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the intercompany partner code.';
                }
                field("IC Partner Name"; Rec."IC Partner Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the intercompany partner.';
                }
                field("Source G/L Account No."; Rec."Source G/L Account No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source G/L account from which costs are recharged.';
                }
                field("Source G/L Account Name"; Rec."Source G/L Account Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the source G/L account.';
                }
                field("Target IC G/L Account No."; Rec."Target IC G/L Account No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the target IC G/L account on the partner side.';
                }
                field("Target IC G/L Account Name"; Rec."Target IC G/L Account Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the target IC G/L account.';
                }
                field("Currency Rule"; Rec."Currency Rule")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the currency is determined for this partner recharge.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a fixed currency code when the Currency Rule is set to Use Fixed Currency.';
                }
                field("Recharge Method"; Rec."Recharge Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharge calculation method for this partner.';
                }
                field("Auto-Send"; Rec."Auto-Send")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether recharge transactions for this partner are sent automatically.';
                }
                field("Auto-Accept"; Rec."Auto-Accept")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether incoming recharge transactions from this partner are accepted automatically.';
                }
                field("Enabled"; Rec."Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this partner mapping is active.';
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text description for this partner mapping.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RechargeSetup)
            {
                Caption = 'IC Recharge Setup';
                ApplicationArea = All;
                Image = Setup;
                RunObject = Page "IC Recharge Setup Card";
                ToolTip = 'Open the IC Recharge Setup card.';
            }
        }
        area(Promoted)
        {
            actionref(RechargeSetup_Promoted; RechargeSetup) { }
        }
    }
}
