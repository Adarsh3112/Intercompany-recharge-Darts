page 50103 "IC Recharge Request List"
{
    Caption = 'IC Recharge Requests';
    PageType = List;
    SourceTable = "IC Recharge Request Header";
    UsageCategory = Documents;
    ApplicationArea = All;
    CardPageId = "IC Recharge Request Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document number of the IC Recharge Request.';
                }
                field("Description"; Rec."Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a description of the IC Recharge Request.';
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the IC Recharge Request.';
                }
                field("Document Date"; Rec."Document Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document date of the IC Recharge Request.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posting date of the IC Recharge Request.';
                }
                field("IC Partner Code"; Rec."IC Partner Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the intercompany partner for this request.';
                }
                field("IC Partner Name"; Rec."IC Partner Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the intercompany partner.';
                }
                field("Recharge Method"; Rec."Recharge Method")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharge calculation method.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency for this IC Recharge Request.';
                }
                field("Source Amount"; Rec."Source Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source amount to be distributed.';
                }
                field("Total Amount"; Rec."Total Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total recharge amount across all lines.';
                }
                field("External Document No."; Rec."External Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an external document reference number.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who created the IC Recharge Request.';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time when the IC Recharge Request was created.';
                }
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
            action(CreateNew)
            {
                Caption = 'New';
                ApplicationArea = All;
                Image = NewDocument;
                ToolTip = 'Create a new IC Recharge Request.';

                trigger OnAction()
                var
                    RechargeHeader: Record "IC Recharge Request Header";
                    RechargeRequestCard: Page "IC Recharge Request Card";
                begin
                    RechargeHeader.Init();
                    RechargeHeader.Insert(true);
                    RechargeRequestCard.SetRecord(RechargeHeader);
                    RechargeRequestCard.Run();
                end;
            }
            action(AdvanceStatus)
            {
                Caption = 'Advance Status';
                ApplicationArea = All;
                Image = NextRecord;
                ToolTip = 'Advance the status of the selected IC Recharge Request to the next step.';
                Enabled = Rec.Status <> Rec.Status::Posted;

                trigger OnAction()
                begin
                    Rec.AdvanceStatus();
                    CurrPage.Update(false);
                end;
            }
            action(ResetToDraft)
            {
                Caption = 'Reset to Draft';
                ApplicationArea = All;
                Image = ReOpen;
                ToolTip = 'Reset the selected IC Recharge Request back to Draft status.';
                Enabled = (Rec.Status <> Rec.Status::Draft) and (Rec.Status <> Rec.Status::Posted);

                trigger OnAction()
                begin
                    Rec.ResetToDraft();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(CreateNew_Promoted; CreateNew) { }
            actionref(AdvanceStatus_Promoted; AdvanceStatus) { }
            actionref(ResetToDraft_Promoted; ResetToDraft) { }
        }
    }
}
