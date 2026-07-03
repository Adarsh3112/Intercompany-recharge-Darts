page 50100 "MIR Setup"
{
    Caption = 'MIR Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "MIR Setup";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group("Numbering")
            {
                Caption = 'Numbering';
                field("Recharge Request Nos."; Rec."Recharge Request Nos.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series used to assign numbers to new Recharge Request documents.';
                }
                field("Partner Mapping Nos."; Rec."Partner Mapping Nos.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series used to assign numbers to new Partner Mapping records.';
                }
            }
            group("Intercompany Journal")
            {
                Caption = 'Intercompany Journal';
                field("IC Journal Template"; Rec."IC Journal Template")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the general journal template used when posting intercompany recharge journals.';
                }
                field("IC Journal Batch"; Rec."IC Journal Batch")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the general journal batch (under the selected template) used when posting intercompany recharge journals.';
                }
            }
            group("Automation")
            {
                Caption = 'Automation';
                field("Auto-Send Flag"; Rec."Auto-Send Flag")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether approved recharge requests are automatically sent to the partner company.';
                }
                field("Auto-Accept Flag"; Rec."Auto-Accept Flag")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether incoming recharge requests from partner companies are automatically accepted.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        // Delegate singleton load/create to the table helper so the page and Install
        // codeunit share one canonical implementation.
        Rec.GetSetup();
    end;
}
