page 50102 "IC Recharge Partner Card"
{
    Caption = 'IC Recharge Partner';
    PageType = Card;
    SourceTable = "IC Recharge Partner";
    UsageCategory = None;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

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
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a free-text description for this partner mapping.';
                }
                field("Enabled"; Rec."Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this partner mapping is active.';
                }
            }
            group(AccountMapping)
            {
                Caption = 'Account Mapping';

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
            }
            group(RechargeSettings)
            {
                Caption = 'Recharge Settings';

                field("Recharge Method"; Rec."Recharge Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharge calculation method for this partner.';
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
                    Enabled = Rec."Currency Rule" = Rec."Currency Rule"::"Use Fixed Currency";
                }
            }
            group(Automation)
            {
                Caption = 'Automation';

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
            }
        }
    }
}
