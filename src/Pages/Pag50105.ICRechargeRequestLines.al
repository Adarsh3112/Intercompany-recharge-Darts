page 50105 "IC Recharge Request Lines"
{
    Caption = 'IC Recharge Request Lines';
    PageType = ListPart;
    SourceTable = "IC Recharge Request Line";
    ApplicationArea = All;
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the line number within the IC Recharge Request.';
                }
                field("IC Partner Code"; Rec."IC Partner Code")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the intercompany partner to be recharged on this line.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("IC Partner Name"; Rec."IC Partner Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the name of the intercompany partner.';
                }
                field("G/L Account No."; Rec."G/L Account No.")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the source G/L account from which the cost is recharged.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("G/L Account Name"; Rec."G/L Account Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the name of the source G/L account.';
                }
                field("Target IC G/L Account No."; Rec."Target IC G/L Account No.")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the target IC G/L account on the partner side.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Target IC G/L Account Name"; Rec."Target IC G/L Account Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Specifies the name of the target IC G/L account.';
                }
                field("Recharge Method"; Rec."Recharge Method")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the recharge calculation method for this line.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Source Amount"; Rec."Source Amount")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the original source amount before allocation is applied.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Allocation %"; Rec."Allocation %")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the percentage of the source amount to be recharged to this partner.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Recharge Amount"; Rec."Recharge Amount")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the calculated recharge amount for this line.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the currency for this line. Leave blank to use the header currency. Populated automatically from the partner Currency Rule when IC Partner Code is entered.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Exchange Rate"; Rec."Exchange Rate")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the exchange rate (LCY per 1 unit of partner currency) that was applied when the calculation engine processed this line. Populated automatically; read-only.';
                }
                field("Exchange Rate Amount"; Rec."Exchange Rate Amount")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the Recharge Amount converted to the partner currency using the Exchange Rate stored at processing time. Read-only.';
                }
                field("Shortcut Dimension 1 Code"; Rec."Shortcut Dimension 1 Code")
                {
                    ApplicationArea = Dimensions;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the code of the first shortcut dimension on this line.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Shortcut Dimension 2 Code"; Rec."Shortcut Dimension 2 Code")
                {
                    ApplicationArea = Dimensions;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the code of the second shortcut dimension on this line.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
                field("Allocation Basis"; Rec."Allocation Basis")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies the basis used to determine the allocation, e.g. headcount, floor space.';
                }
                field("Allocation Calculation Note"; Rec."Allocation Calculation Note")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies a free-text note describing how the allocation amount was calculated for traceability.';
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    Editable = IsEditable;
                    ToolTip = 'Specifies a description for this recharge line.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RecalcAmounts)
            {
                Caption = 'Recalculate Amounts';
                ApplicationArea = All;
                Image = Refresh;
                ToolTip = 'Run the Recharge Calculation engine to distribute source costs across IC partners based on configured percentages or amounts. Resolves partner currency rules, fetches exchange rates, and stamps Exchange Rate and Exchange Rate Amount on each line.';
                Enabled = IsEditable;

                trigger OnAction()
                var
                    RechargeHeader: Record "IC Recharge Request Header";
                    ICRechargeCalc: Codeunit "IC Recharge Calculation";
                begin
                    if RechargeHeader.Get(Rec."Request No.") then
                        ICRechargeCalc.CalculateAllocations(RechargeHeader);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        IsEditable: Boolean;

    trigger OnAfterGetRecord()
    begin
        SetEditability();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        SetEditability();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        SetEditability();
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        RechargeHeader: Record "IC Recharge Request Header";
    begin
        if Rec."Request No." <> '' then
            if RechargeHeader.Get(Rec."Request No.") then
                RechargeHeader.TestStatusIsDraft();
        exit(true);
    end;

    local procedure SetEditability()
    var
        RechargeHeader: Record "IC Recharge Request Header";
    begin
        if Rec."Request No." <> '' then begin
            if RechargeHeader.Get(Rec."Request No.") then
                IsEditable := RechargeHeader.Status = RechargeHeader.Status::Draft
            else
                IsEditable := false;
        end else
            IsEditable := true;
    end;
}
