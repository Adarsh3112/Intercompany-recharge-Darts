page 50106 "MIR Recharge Ledger Entries"
{
    // MIR Recharge Ledger Entries
    // ---------------------------
    // Read-only audit list over the immutable MIR Recharge Ledger Entry table. One
    // row exists per allocation line of every posted MIR Recharge Header, capturing
    // Document No. (the Source Request linkage), Partner Code, Amount, Amount LCY,
    // Currency Code, Posting Date, GL Account, and Target IC GL Acc.
    //
    // The page is non-editable end-to-end: InsertAllowed, ModifyAllowed, and
    // DeleteAllowed are all false. Even if a user found a way around the page-level
    // flags, the table's OnModify / OnDelete triggers raise CannotModifyPostedEntriesErr,
    // so the immutability guarantee holds whether the table is reached from this page,
    // the BC client, an API, or another codeunit.

    Caption = 'MIR Recharge Ledger Entries';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "MIR Recharge Ledger Entry";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique, auto-incremented identifier of this immutable recharge ledger entry.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source MIR Recharge Header that this ledger entry was posted from. Click to drill back to the originating recharge request.';
                }
                field("Partner Code"; Rec."Partner Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the partner that received this portion of the recharge.';
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharged amount in the document currency.';
                }
                field("Amount LCY"; Rec."Amount LCY")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the recharged amount converted to the local company currency at the posting date exchange rate.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency of the Amount field.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date on which this recharge was posted to the general ledger.';
                }
                field("GL Account"; Rec."GL Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the local G/L account that absorbed the recharge offset on the source company side.';
                }
                field("Target IC GL Acc."; Rec."Target IC GL Acc.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the intercompany G/L account in the partner company that received the recharge debit.';
                }
                field("IC Document No."; Rec."IC Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Document No. used on the IC Outbox journal rows produced by this posting.';
                }
                field("Journal Template Name"; Rec."Journal Template Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Gen. Journal Template that was configured on MIR Setup at the time of posting.';
                    Visible = false;
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Gen. Journal Batch that was configured on MIR Setup at the time of posting.';
                    Visible = false;
                }
                field("Posted By"; Rec."Posted By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user that ran the posting.';
                }
                field("Posted At"; Rec."Posted At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time at which the posting completed.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action("Source Request")
            {
                ApplicationArea = All;
                Caption = 'Source Request';
                Image = Document;
                ToolTip = 'Open the MIR Recharge Header that this ledger entry was posted from.';

                trigger OnAction()
                var
                    Header: Record "MIR Recharge Header";
                begin
                    // Acceptance criterion: ledger entries link back to the Source
                    // Request. The Document No. on the ledger row equals the source
                    // Header."No." verbatim, so a Get() is sufficient.
                    if Rec."Document No." = '' then
                        exit;
                    if Header.Get(Rec."Document No.") then
                        Page.Run(Page::"MIR Recharge Header Card", Header);
                end;
            }
            action("Partner Mapping")
            {
                ApplicationArea = All;
                Caption = 'Partner Mapping';
                Image = CustomerGroup;
                ToolTip = 'Open the MIR Partner Mapping for the partner on this ledger entry.';

                trigger OnAction()
                var
                    PartnerMapping: Record "MIR Partner Mapping";
                begin
                    // Acceptance criterion: ledger entries link back to the Partner.
                    if Rec."Partner Code" = '' then
                        exit;
                    PartnerMapping.SetRange("Partner Code", Rec."Partner Code");
                    Page.Run(Page::"MIR Partner Mapping List", PartnerMapping);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(SourceRequest_Promoted; "Source Request")
                {
                }
                actionref(PartnerMapping_Promoted; "Partner Mapping")
                {
                }
            }
        }
    }
}
