page 50102 "ICR Recharge Request"
{
    Caption = 'Recharge Request';
    PageType = Card;
    SourceTable = "ICR Recharge Request";
    ApplicationArea = All;
    UsageCategory = Documents;
    AboutTitle = 'Recharge Request';
    AboutText = 'Create and edit an Intercompany Recharge Request that will be validated, approved, and posted to allocate costs across companies.';

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
                    ToolTip = 'Specifies the unique document number for this Recharge Request. Leave blank on a new record to have the next number assigned automatically from the number series configured on the ICR Setup page.';
                }
                field("Status"; Rec."Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the current lifecycle status of the Recharge Request. New records default to Draft.';
                }
                field("Source Company"; Rec."Source Company")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the company that originated the recharge. Use the lookup to pick a company that exists in this database.';
                }
                field("Recharge Type"; Rec."Recharge Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharge type or category (for example, a shared-service code) used to classify this request.';
                }
                field("Allocation Basis"; Rec."Allocation Basis")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how the total amount will be allocated across intercompany partners.';
                }
            }
            group(Source)
            {
                Caption = 'Source';
                field("Source G/L Account"; Rec."Source G/L Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source G/L account that will be credited or debited when this recharge is posted.';
                }
            }
            group(Amounts)
            {
                Caption = 'Amounts';
                field("Total Amount"; Rec."Total Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the total amount to be recharged in the currency indicated by the Currency Code field.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency for the total amount. Leave blank to use the local currency (LCY) of the source company.';
                }
                field("Exchange Rate"; Rec."Exchange Rate")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the exchange rate used to convert the total amount to local currency at posting time.';
                }
            }
            part(Lines; "ICR Recharge Lines")
            {
                Caption = 'Lines';
                ApplicationArea = All;
                SubPageLink = "Document No." = field("No.");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Approval)
            {
                Caption = 'Approval';

                action(SendApprovalRequest)
                {
                    ApplicationArea = All;
                    Caption = 'Send Approval Request';
                    Image = SendApprovalRequest;
                    ToolTip = 'Submit the Recharge Request to the standard approval workflow. Routing by Recharge Type and Total Amount is handled by the workflow configured by administrators.';
                    Enabled = CanSendForApproval;

                    trigger OnAction()
                    var
                        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
                    begin
                        ICRApprovalWorkflow.OnSendICRRechargeRequestForApproval(Rec);
                        CurrPage.Update(false);
                    end;
                }

                action(CancelApprovalRequest)
                {
                    ApplicationArea = All;
                    Caption = 'Cancel Approval Request';
                    Image = CancelApprovalRequest;
                    ToolTip = 'Cancel a Recharge Request that is currently Pending Approval and revert it to Draft.';
                    Enabled = CanCancelApproval;

                    trigger OnAction()
                    var
                        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
                    begin
                        ICRApprovalWorkflow.OnCancelICRRechargeRequestApprovalRequest(Rec);
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

                actionref(SendApprovalRequest_Promoted; SendApprovalRequest)
                {
                }
                actionref(CancelApprovalRequest_Promoted; CancelApprovalRequest)
                {
                }
            }
        }
    }

    var
        CanSendForApproval: Boolean;
        CanCancelApproval: Boolean;
        OpenApprovalEntriesExistForRec: Boolean;

    trigger OnAfterGetCurrRecord()
    var
        ICRApprovalWorkflow: Codeunit "ICR Approval Workflow";
    begin
        OpenApprovalEntriesExistForRec := ICRApprovalWorkflow.OpenApprovalEntriesExist(Rec);

        CanSendForApproval :=
            (Rec."No." <> '') and
            (Rec.Status in [Rec.Status::Draft, Rec.Status::Validated, Rec.Status::Rejected]) and
            (not OpenApprovalEntriesExistForRec);

        CanCancelApproval :=
            (Rec."No." <> '') and
            (Rec.Status = Rec.Status::"Pending Approval") and
            OpenApprovalEntriesExistForRec;
    end;
}
