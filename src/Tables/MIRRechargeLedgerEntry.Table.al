table 50105 "MIR Recharge Ledger Entry"
{
    // MIR Recharge Ledger Entry
    // -------------------------
    // Immutable, audit-safe record of a posted intercompany recharge. One row is
    // written by the MIR Posting Management codeunit for every allocation line on
    // the source MIR Recharge Header at the moment the request transitions from
    // Approved to Posted. The table serves three purposes:
    //
    //   1. Audit sink — captures Document No., Partner Code, Amount, Amount LCY,
    //      Currency Code, Posting Date, GL Account, and Target IC GL Acc. so an
    //      auditor can reconstruct exactly what was recharged, to which partner,
    //      against which local and intercompany G/L accounts.
    //
    //   2. Source-request linkage — "Document No." relates back to the MIR Recharge
    //      Header "No." so the original request, its allocation rules, and its
    //      Approval trail are all reachable from any ledger row. "Partner Code"
    //      relates to the MIR Partner Mapping so the partner-side context (target
    //      company, dimensions, default IC G/L) is also discoverable.
    //
    //   3. Duplicate-post guard — MIR Posting Management does a
    //         SetRange("Document No.", Header."No.") + IsEmpty
    //      check against this table before producing any IC Outbox line. A second
    //      attempt to post the same request finds rows here and is blocked with a
    //      hard Error before any side effect occurs.
    //
    // Per the platform immutability rule for posted-financial-event tables, both
    // OnModify and OnDelete raise CannotModifyPostedEntriesErr directing the user
    // to create a reversal on the source MIR Recharge Header instead.

    Caption = 'MIR Recharge Ledger Entry';
    DataClassification = CustomerContent;
    LookupPageId = "MIR Recharge Ledger Entries";
    DrillDownPageId = "MIR Recharge Ledger Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            // Per the spec technical hint: Entry No. is auto-incremented by the
            // platform so the posting codeunit never has to allocate a key value
            // itself. Editable = false because this is the primary key of an
            // immutable record.
            AutoIncrement = true;
            Editable = false;
        }
        field(2; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
            // Links the ledger row back to the Source Request — i.e. the MIR
            // Recharge Header."No." that originated the posting. The secondary
            // key DocumentNo on this table indexes it so the duplicate-post check
            // in MIR Posting Management runs as a single seek.
            TableRelation = "MIR Recharge Header"."No.";
            Editable = false;
            NotBlank = true;
        }
        field(3; "Partner Code"; Code[20])
        {
            Caption = 'Partner Code';
            DataClassification = CustomerContent;
            // Links the ledger row back to the Partner that received the recharge.
            // MIR Partner Mapping is the canonical partner registry in this
            // extension and IC Partner is its underlying BC reference, so we relate
            // to the mapping table that the rest of the extension uses.
            TableRelation = "MIR Partner Mapping"."Partner Code";
            Editable = false;
            NotBlank = true;
        }
        field(4; Amount; Decimal)
        {
            Caption = 'Amount';
            DataClassification = CustomerContent;
            // The recharge amount in the source/document currency (Currency Code).
            DecimalPlaces = 2 : 2;
            AutoFormatType = 1;
            AutoFormatExpression = Rec."Currency Code";
            Editable = false;
        }
        field(5; "Amount LCY"; Decimal)
        {
            Caption = 'Amount LCY';
            DataClassification = CustomerContent;
            // The recharge amount converted to the local company's currency. For
            // postings made in LCY this equals Amount. For foreign-currency
            // postings, the posting codeunit converts Amount using the standard BC
            // Currency Exchange Rate codeunit at the Posting Date and stores the
            // LCY-equivalent here for G/L reporting.
            DecimalPlaces = 2 : 2;
            AutoFormatType = 1;
            Editable = false;
        }
        field(6; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency.Code;
            Editable = false;
        }
        field(7; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(8; "GL Account"; Code[20])
        {
            Caption = 'GL Account';
            DataClassification = CustomerContent;
            // The local G/L account used as the offset for the recharge debit on
            // the source company side — typically the source expense / clearing
            // account from MIR Setup or the GL Mapping.
            TableRelation = "G/L Account"."No.";
            Editable = false;
        }
        field(9; "Target IC GL Acc."; Code[20])
        {
            Caption = 'Target IC GL Acc.';
            DataClassification = CustomerContent;
            // The intercompany G/L account in the partner company that this
            // recharge line debited. Copied from the allocation line at posting
            // time so the ledger remains valid even if the partner mapping is
            // later edited.
            TableRelation = "G/L Account"."No.";
            Editable = false;
        }
        field(10; "Posted By"; Code[50])
        {
            Caption = 'Posted By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(11; "Posted At"; DateTime)
        {
            Caption = 'Posted At';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(12; "IC Document No."; Code[20])
        {
            Caption = 'IC Document No.';
            DataClassification = CustomerContent;
            // The Document No. carried on the IC Outbox journal rows produced by
            // the post. In the current implementation this equals the source
            // Document No. verbatim, but it is stored separately so a future
            // numbering scheme can diverge without breaking back-references.
            Editable = false;
        }
        field(13; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name';
            DataClassification = CustomerContent;
            TableRelation = "Gen. Journal Template".Name;
            Editable = false;
        }
        field(14; "Journal Batch Name"; Code[10])
        {
            Caption = 'Journal Batch Name';
            DataClassification = CustomerContent;
            TableRelation = "Gen. Journal Batch".Name where("Journal Template Name" = field("Journal Template Name"));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(DocumentNo; "Document No.")
        {
            // Indexes the duplicate-post pre-check
            // (SetRange("Document No.", ...) + IsEmpty) in MIR Posting Management,
            // and the drill-down from MIR Recharge Header to its ledger entries.
        }
        key(PartnerCode; "Partner Code", "Posting Date")
        {
            // Supports partner-centric reporting: "show me everything ever
            // recharged to partner X, in posting-date order".
        }
        key(PostingDate; "Posting Date")
        {
            // Supports period-based reporting / filtering on the list page.
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Entry No.", "Document No.", "Partner Code", Amount, "Currency Code", "Posting Date")
        {
        }
        fieldgroup(Brick; "Entry No.", "Document No.", "Partner Code", Amount, "Currency Code", "Posting Date", "Posted By")
        {
        }
    }

    var
        // Per the spec technical hint: use the pattern
        //   Error(CannotModifyPostedEntriesErr)
        // in the modify/delete triggers. The single shared Label keeps the message
        // consistent and points the user to the only legitimate recovery path —
        // a reversal on the source MIR Recharge Header.
        CannotModifyPostedEntriesErr: Label 'You cannot modify or delete MIR Recharge Ledger Entry %1. Posted recharge ledger entries are immutable. To undo a posting, create a reversal on the source MIR Recharge Header.', Comment = '%1 = Entry No.';

    trigger OnModify()
    begin
        // Posted financial event — modification is forbidden. The reversal flow on
        // MIR Recharge Header is the correct path to undo a post.
        Error(CannotModifyPostedEntriesErr, Rec."Entry No.");
    end;

    trigger OnDelete()
    begin
        // Posted financial event — deletion is forbidden. Removing the row would
        // re-open the door to duplicate posting and break the audit trail.
        Error(CannotModifyPostedEntriesErr, Rec."Entry No.");
    end;

    trigger OnRename()
    begin
        // Renaming the primary key on an immutable audit row is meaningless and
        // would, if allowed, also bypass the audit. Block it for symmetry with the
        // modify/delete guards.
        Error(CannotModifyPostedEntriesErr, Rec."Entry No.");
    end;
}
