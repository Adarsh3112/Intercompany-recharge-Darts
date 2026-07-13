/// <summary>
/// Immutable audit log capturing every significant action performed on an
/// ICR Recharge Request — creation, submission for approval, cancellation,
/// activation, posting, reversal and any lifecycle status change. Rows are
/// written by the LogAction procedure on the 'ICR Management' codeunit and
/// are protected by OnModify and OnDelete triggers that raise ImmutableErr
/// no matter how the modification reaches the table (page action, API call
/// or background codeunit).
///
/// Table structure matches the acceptance criteria exactly:
///   * 'Entry No.'     — auto-incrementing surrogate primary key
///   * 'User ID'       — the BC user that performed the action (Code[50])
///   * 'Action'        — short action code such as CREATED, SUBMITTED,
///                       CANCELLED, POSTED, ACTIVATED, STATUS-CHANGED
///   * 'Document No.'  — the ICR Recharge Request document number
///   * 'Action Timestamp' — DateTime when the action was captured
///   * 'Description'   — free-text description of what happened
/// </summary>
table 50106 "ICR Audit Log"
{
    Caption = 'ICR Audit Log';
    DataClassification = CustomerContent;
    DataPerCompany = true;
    LookupPageId = "ICR Audit Logs";
    DrillDownPageId = "ICR Audit Logs";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
            Editable = false;
        }
        field(2; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
            Editable = false;
        }
        field(3; "Action"; Text[50])
        {
            Caption = 'Action';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(4; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
            TableRelation = "ICR Recharge Request"."No.";
            Editable = false;
        }
        field(5; "Action Timestamp"; DateTime)
        {
            Caption = 'Action Timestamp';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(6; "Description"; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Document; "Document No.", "Action Timestamp")
        {
        }
        key(TimestampKey; "Action Timestamp")
        {
        }
        key(UserKey; "User ID", "Action Timestamp")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Entry No.", "Document No.", "Action", "Action Timestamp")
        {
        }
        fieldgroup(Brick; "Entry No.", "Document No.", "Action", "User ID", "Action Timestamp", "Description")
        {
        }
    }

    var
        ImmutableModifyErr: Label 'The ICR Audit Log is immutable. Entry No. %1 for document %2 cannot be modified. Create a new audit log entry to record a correction.', Comment = '%1 = Entry No., %2 = Document No.';
        ImmutableDeleteErr: Label 'The ICR Audit Log is immutable. Entry No. %1 for document %2 cannot be deleted. Audit history must be preserved.', Comment = '%1 = Entry No., %2 = Document No.';

    trigger OnModify()
    begin
        Error(ImmutableModifyErr, "Entry No.", "Document No.");
    end;

    trigger OnDelete()
    begin
        Error(ImmutableDeleteErr, "Entry No.", "Document No.");
    end;
}
