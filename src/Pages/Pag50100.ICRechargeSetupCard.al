page 50100 "IC Recharge Setup Card"
{
    Caption = 'IC Recharge Setup';
    PageType = Card;
    SourceTable = "IC Recharge Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    DeleteAllowed = false;
    InsertAllowed = false;

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
                    ToolTip = 'Specifies the default intercompany partner for recharge transactions.';
                }
                field("IC Partner Name"; Rec."IC Partner Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the intercompany partner.';
                }
                field("Recharge Method"; Rec."Recharge Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default method used to calculate intercompany recharges.';
                }
                field("Default Currency Code"; Rec."Default Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default currency applied to recharge transactions.';
                }
            }
            group(Posting)
            {
                Caption = 'Posting';

                field("IC Recharge Source Code"; Rec."IC Recharge Source Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source code stamped on IC General Journal and IC Outbox entries for audit traceability. If blank, a default source code (ICRECHARG) is created automatically on first posting.';
                }
            }
            group(Automation)
            {
                Caption = 'Automation';

                field("Auto-Send"; Rec."Auto-Send")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether intercompany recharge transactions are sent automatically.';
                }
                field("Auto-Accept"; Rec."Auto-Accept")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether incoming intercompany recharge transactions are accepted automatically.';
                }
                field("Enabled"; Rec."Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the IC Recharge Setup is active.';
                }
                field("IC Recharge Request Nos."; Rec."IC Recharge Request Nos.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series for IC Recharge Requests.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(ICRechargePartners)
            {
                Caption = 'IC Recharge Partners';
                ApplicationArea = All;
                Image = IntercompanyGeneralJournal;
                RunObject = Page "IC Recharge Partner List";
                ToolTip = 'Open the list of configured intercompany recharge partners.';
            }
        }
        area(Promoted)
        {
            actionref(ICRechargePartners_Promoted; ICRechargePartners) { }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetRecordOnce();
    end;
}
