page 50104 "IC Recharge Request Card"
{
    Caption = 'IC Recharge Request';
    PageType = Document;
    SourceTable = "IC Recharge Request Header";
    UsageCategory = None;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the document number of the IC Recharge Request.';

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit(xRec) then
                            CurrPage.Update();
                    end;
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies a description of the IC Recharge Request.';
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the current processing status of this IC Recharge Request.';
                }
                field("Document Date"; Rec."Document Date")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the document date.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the intended posting date.';
                }
                field("External Document No."; Rec."External Document No.")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies an external document reference number.';
                }
                field("Source Amount"; Rec."Source Amount")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the source amount to be distributed among intercompany partners.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(true);
                    end;
                }
            }
            group(PartnerDetails)
            {
                Caption = 'Intercompany Partner';

                field("IC Partner Code"; Rec."IC Partner Code")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the intercompany partner for this request.';
                }
                field("IC Partner Name"; Rec."IC Partner Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the name of the intercompany partner.';
                }
                field("Recharge Method"; Rec."Recharge Method")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the default recharge calculation method for lines on this request.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    ToolTip = 'Specifies the currency for this IC Recharge Request.';
                }
                field("Total Amount"; Rec."Total Amount")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the total recharge amount across all lines.';
                }
            }
            group(AdditionalInfo)
            {
                Caption = 'Additional Information';

                field("Reason Code"; Rec."Reason Code")
                {
                    ApplicationArea = All;
                    Editable = IsHeaderEditable;
                    MultiLine = true;
                    ToolTip = 'Specifies the reason or notes for this IC Recharge Request.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the user who created the IC Recharge Request.';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when the IC Recharge Request was created.';
                }
                field("Last Modified DateTime"; Rec."Last Modified DateTime")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when the IC Recharge Request was last modified.';
                }
            }
            part(Lines; "IC Recharge Request Lines")
            {
                ApplicationArea = All;
                Caption = 'Lines';
                SubPageLink = "Request No." = field("No.");
                UpdatePropagation = Both;
            }
        }
        area(FactBoxes)
        {
            systempart(Links; Links)
            {
                ApplicationArea = RecordLinks;
            }
            systempart(Notes; Notes)
            {
                ApplicationArea = Notes;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CalculateAllocations)
            {
                Caption = 'Calculate Allocations';
                ApplicationArea = All;
                Image = Calculate;
                ToolTip = 'Run the Recharge Calculation engine to distribute source costs across IC partners based on configured percentages or amounts. Rounding differences are adjusted on the last line.';
                Enabled = IsHeaderEditable;

                trigger OnAction()
                var
                    ICRechargeCalc: Codeunit "IC Recharge Calculation";
                begin
                    ICRechargeCalc.CalculateAllocations(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(AdvanceStatus)
            {
                Caption = 'Advance Status';
                ApplicationArea = All;
                Image = NextRecord;
                ToolTip = 'Advance this IC Recharge Request to the next status.';
                Enabled = Rec.Status <> Rec.Status::Posted;

                trigger OnAction()
                begin
                    Rec.AdvanceStatus();
                    SetPageVariables();
                    CurrPage.Update(false);
                end;
            }
            action(ResetToDraft)
            {
                Caption = 'Reset to Draft';
                ApplicationArea = All;
                Image = ReOpen;
                ToolTip = 'Reset this IC Recharge Request back to Draft so it can be edited.';
                Enabled = (Rec.Status <> Rec.Status::Draft) and (Rec.Status <> Rec.Status::Posted);

                trigger OnAction()
                begin
                    Rec.ResetToDraft();
                    SetPageVariables();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(RechargeRequestList)
            {
                Caption = 'IC Recharge Requests';
                ApplicationArea = All;
                Image = List;
                RunObject = Page "IC Recharge Request List";
                ToolTip = 'Open the list of all IC Recharge Requests.';
            }
        }
        area(Promoted)
        {
            actionref(CalculateAllocations_Promoted; CalculateAllocations) { }
            actionref(AdvanceStatus_Promoted; AdvanceStatus) { }
            actionref(ResetToDraft_Promoted; ResetToDraft) { }
            actionref(RechargeRequestList_Promoted; RechargeRequestList) { }
        }
    }

    var
        IsHeaderEditable: Boolean;
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        SetPageVariables();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        SetPageVariables();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        SetPageVariables();
    end;

    local procedure SetPageVariables()
    begin
        IsHeaderEditable := Rec.Status = Rec.Status::Draft;
        StatusStyle := GetStatusStyle();
    end;

    local procedure GetStatusStyle(): Text
    begin
        case Rec.Status of
            Rec.Status::Draft:
                exit('Standard');
            Rec.Status::Validated:
                exit('Favorable');
            Rec.Status::"Pending Approval":
                exit('Ambiguous');
            Rec.Status::Approved:
                exit('Favorable');
            Rec.Status::Posted:
                exit('Strong');
            else
                exit('Standard');
        end;
    end;
}
