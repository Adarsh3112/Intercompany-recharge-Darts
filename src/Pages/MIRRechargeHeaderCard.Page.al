page 50104 "MIR Recharge Header Card"
{
    Caption = 'MIR Recharge Header';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "MIR Recharge Header";

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique number of the intercompany recharge document. Leave blank to receive an automatic number from the configured Recharge Request Nos. series.';
                    Importance = Promoted;

                    trigger OnAssistEdit()
                    begin
                        if Rec.AssistEdit() then
                            CurrPage.Update();
                    end;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a short description that identifies what the intercompany recharge covers.';
                    Editable = IsDraft;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lifecycle status of the recharge document. Use the actions in the ribbon to move the document through its lifecycle.';
                    Importance = Promoted;
                    StyleExpr = StatusStyleTxt;
                }
            }
            group(Amounts)
            {
                Caption = 'Amounts';
                field("Source Amount"; Rec."Source Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the gross amount in the source currency that will be recharged to the partner company.';
                    Editable = IsDraft;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency in which the source amount is expressed.';
                    Editable = IsDraft;
                }
            }
            part(Lines; "MIR Recharge Line Subform")
            {
                ApplicationArea = All;
                Caption = 'Lines';
                // Link the subform to the current header by the FK on the line table. The
                // subform's source records are automatically filtered to lines whose
                // Document No. matches this card's No.
                SubPageLink = "Document No." = field("No.");
                UpdatePropagation = Both;
                Editable = IsDraft;
            }
            group(Posting)
            {
                Caption = 'Posting';
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date that will be used as the G/L posting date when the recharge is posted.';
                    Editable = IsDraft;
                }
                field("External ID"; Rec."External ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an external reference identifier supplied by the originating system, used to correlate this recharge with an upstream transaction.';
                    Editable = IsDraft;
                }
            }
            group(Audit)
            {
                Caption = 'Audit';
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who created the recharge document.';
                    Editable = false;
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time at which the recharge document was created.';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(StatusActions)
            {
                Caption = 'Status';
                Image = ChangeStatus;

                action(Simulate_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Simulate Allocation';
                    Image = CalculateLines;
                    ToolTip = 'Run the allocation engine without committing. Recalculates each line''s Calculated Amount and Allocation Trace in memory and reports the totals, balanced state, and any rule violations. Useful before Validate.';
                    Enabled = Rec.Status = Rec.Status::Draft;

                    trigger OnAction()
                    var
                        AllocationEngine: Codeunit "MIR Allocation Engine";
                        TempLine: Record "MIR Recharge Line" temporary;
                        TotalAllocated: Decimal;
                        TotalPercent: Decimal;
                        IsBalanced: Boolean;
                        BalancedTxt: Text;
                        SimulationMsg: Label 'Simulation for %1\Lines processed: %2\Total Calculated Amount: %3\Source Amount: %4\Status: %5', Comment = '%1 doc, %2 line count, %3 total, %4 source, %5 balanced text';
                        LineCount: Integer;
                    begin
                        // Non-committing dry run. The engine runs the same validation
                        // rules SetValidated would run; any failure surfaces here so the
                        // user can correct the document before they commit.
                        AllocationEngine.SimulateAllocation(Rec, TempLine, TotalAllocated, TotalPercent, IsBalanced);
                        if TempLine.FindSet() then
                            repeat
                                LineCount += 1;
                            until TempLine.Next() = 0;
                        if IsBalanced then
                            BalancedTxt := 'Balanced (fully allocates the Source Amount)'
                        else
                            BalancedTxt := 'Partial (allocates less than the Source Amount)';
                        Message(SimulationMsg, Rec."No.", LineCount, TotalAllocated, Rec."Source Amount", BalancedTxt);
                    end;
                }
                action(Validate_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Validate';
                    Image = ValidateEmailLoggingSetup;
                    ToolTip = 'Move the document from Draft to Validated after confirming the mandatory fields are populated. Fields become read-only once this action runs.';
                    Enabled = Rec.Status = Rec.Status::Draft;

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetValidated(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(SendForApproval_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Send for Approval';
                    Image = SendApprovalRequest;
                    ToolTip = 'Submit the validated document for approval. The document moves to Pending Approval.';
                    Enabled = Rec.Status = Rec.Status::Validated;

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetPendingApproval(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(Approve_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Approve';
                    Image = Approve;
                    ToolTip = 'Approve the document. Only documents in Pending Approval can be approved.';
                    Enabled = Rec.Status = Rec.Status::"Pending Approval";

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetApproved(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(Reject_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Reject';
                    Image = Reject;
                    ToolTip = 'Reject the document. Rejected documents can be returned to Draft for re-work.';
                    Enabled = Rec.Status in [Rec.Status::Validated, Rec.Status::"Pending Approval"];

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetRejected(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(ReopenDraft_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Reopen as Draft';
                    Image = ReOpen;
                    ToolTip = 'Return a Rejected document to Draft so the source fields can be corrected.';
                    Enabled = Rec.Status = Rec.Status::Rejected;

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetDraft(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(Post_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Post';
                    Image = PostDocument;
                    ToolTip = 'Post the approved recharge. Only Approved documents can be posted.';
                    Enabled = Rec.Status = Rec.Status::Approved;

                    trigger OnAction()
                    var
                        PostingMgt: Codeunit "MIR Posting Management";
                    begin
                        // Delegate the full posting pipeline (IC Outbox lines, balancing
                        // credit, ledger entry, and the Approved -> Posted status flip via
                        // Status Mgt) to the MIR Posting Management codeunit.
                        PostingMgt.PostRechargeRequest(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(Reverse_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Reverse';
                    Image = ReverseLines;
                    ToolTip = 'Reverse a posted recharge.';
                    Enabled = Rec.Status = Rec.Status::Posted;

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetReversed(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(Close_Action)
                {
                    ApplicationArea = All;
                    Caption = 'Close';
                    Image = Close;
                    ToolTip = 'Close the recharge document. Closed documents are final and cannot transition further.';
                    Enabled = Rec.Status in [Rec.Status::Posted, Rec.Status::Reversed, Rec.Status::Rejected];

                    trigger OnAction()
                    var
                        StatusMgt: Codeunit "MIR Recharge Status Mgt";
                    begin
                        StatusMgt.SetClosed(Rec);
                        CurrPage.Update(false);
                    end;
                }
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Simulate_Promoted; Simulate_Action) { }
                actionref(Validate_Promoted; Validate_Action) { }
                actionref(SendForApproval_Promoted; SendForApproval_Action) { }
                actionref(Approve_Promoted; Approve_Action) { }
                actionref(Reject_Promoted; Reject_Action) { }
                actionref(Post_Promoted; Post_Action) { }
                actionref(Reverse_Promoted; Reverse_Action) { }
                actionref(Close_Promoted; Close_Action) { }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        // Drive the page's field-editability and the status badge from the current record's
        // status. Editability is also enforced on the table side (OnModify) so this is
        // strictly a UX nicety — protection does not depend on it.
        IsDraft := Rec.Status = Rec.Status::Draft;

        case Rec.Status of
            Rec.Status::Draft:
                StatusStyleTxt := 'Standard';
            Rec.Status::Validated, Rec.Status::Approved:
                StatusStyleTxt := 'Favorable';
            Rec.Status::"Pending Approval":
                StatusStyleTxt := 'Ambiguous';
            Rec.Status::Rejected, Rec.Status::Reversed:
                StatusStyleTxt := 'Unfavorable';
            Rec.Status::Posted:
                StatusStyleTxt := 'StrongAccent';
            Rec.Status::Closed:
                StatusStyleTxt := 'Subordinate';
            else
                StatusStyleTxt := 'Standard';
        end;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        // Default a new record to today's work date so the user sees a sensible posting
        // date prefilled. The OnInsert trigger will overwrite if still blank.
        if Rec."Posting Date" = 0D then
            Rec."Posting Date" := WorkDate();
    end;

    var
        IsDraft: Boolean;
        StatusStyleTxt: Text;
}
