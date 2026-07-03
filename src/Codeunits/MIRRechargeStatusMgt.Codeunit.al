codeunit 50101 "MIR Recharge Status Mgt"
{
    // Status Management pattern: every status transition and every field-protection check
    // for the MIR Recharge Header lives in this codeunit. Pages, OnModify triggers, and any
    // future API hooks call into here — they never mutate Status directly. This makes the
    // lifecycle rules independent of the entry point.

    procedure SetDraft(var Rec: Record "MIR Recharge Header")
    begin
        // Draft is only reachable from Rejected (re-work) — Posted/Reversed/Closed are final.
        if not (Rec.Status in [Rec.Status::Rejected]) then
            Error('MIR Recharge Header %1 cannot return to Draft from status %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::Draft);
    end;

    procedure SetValidated(var Rec: Record "MIR Recharge Header")
    var
        AllocationEngine: Codeunit "MIR Allocation Engine";
    begin
        if Rec.Status <> Rec.Status::Draft then
            Error('Only Draft recharge headers can be validated. %1 is currently %2.', Rec."No.", Rec.Status);
        ValidateMandatoryFields(Rec);
        // Allocation rules are now enforced at the same gate as mandatory-field checks.
        // The engine recomputes Calculated Amount + Allocation Trace on every line and
        // raises a document-named error if the lines over-allocate, mis-total on %, or
        // are otherwise inconsistent. This runs BEFORE the status flips so a failed
        // validation leaves the document in Draft for the user to fix.
        AllocationEngine.ValidateRechargeRequest(Rec);
        ChangeStatus(Rec, Rec.Status::Validated);
    end;

    procedure SetPendingApproval(var Rec: Record "MIR Recharge Header")
    begin
        if Rec.Status <> Rec.Status::Validated then
            Error('Only Validated recharge headers can be sent for approval. %1 is currently %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::"Pending Approval");
    end;

    procedure SetApproved(var Rec: Record "MIR Recharge Header")
    begin
        if Rec.Status <> Rec.Status::"Pending Approval" then
            Error('Only Pending Approval recharge headers can be approved. %1 is currently %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::Approved);
    end;

    procedure SetRejected(var Rec: Record "MIR Recharge Header")
    begin
        if not (Rec.Status in [Rec.Status::"Pending Approval", Rec.Status::Validated]) then
            Error('Only Validated or Pending Approval recharge headers can be rejected. %1 is currently %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::Rejected);
    end;

    procedure SetPosted(var Rec: Record "MIR Recharge Header")
    begin
        if Rec.Status <> Rec.Status::Approved then
            Error('Only Approved recharge headers can be posted. %1 is currently %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::Posted);
    end;

    procedure SetReversed(var Rec: Record "MIR Recharge Header")
    begin
        if Rec.Status <> Rec.Status::Posted then
            Error('Only Posted recharge headers can be reversed. %1 is currently %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::Reversed);
    end;

    procedure SetClosed(var Rec: Record "MIR Recharge Header")
    begin
        if not (Rec.Status in [Rec.Status::Posted, Rec.Status::Reversed, Rec.Status::Rejected]) then
            Error('MIR Recharge Header %1 cannot be closed from status %2.', Rec."No.", Rec.Status);
        ChangeStatus(Rec, Rec.Status::Closed);
    end;

    procedure CheckProtectedFieldsUnchanged(OldRec: Record "MIR Recharge Header"; NewRec: Record "MIR Recharge Header")
    begin
        // The Status field is allowed to change because that's the legitimate state
        // transition path. Every other field is locked once the document leaves Draft.
        // OnDelete and immutability of Posted/Reversed are handled separately on the table.
        if OldRec.Description <> NewRec.Description then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption(Description));
        if OldRec."Source Amount" <> NewRec."Source Amount" then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("Source Amount"));
        if OldRec."Currency Code" <> NewRec."Currency Code" then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("Currency Code"));
        if OldRec."Posting Date" <> NewRec."Posting Date" then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("Posting Date"));
        if OldRec."External ID" <> NewRec."External ID" then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("External ID"));
        if OldRec."Created By" <> NewRec."Created By" then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("Created By"));
        if OldRec."Created At" <> NewRec."Created At" then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("Created At"));
        if OldRec."No." <> NewRec."No." then
            ErrorFieldLocked(OldRec, OldRec.FieldCaption("No."));
    end;

    local procedure ValidateMandatoryFields(var Rec: Record "MIR Recharge Header")
    begin
        // Surface a precise error per missing field rather than a generic "validation failed".
        Rec.TestField(Description);
        Rec.TestField("Source Amount");
        Rec.TestField("Currency Code");
        Rec.TestField("Posting Date");
    end;

    local procedure ChangeStatus(var Rec: Record "MIR Recharge Header"; NewStatus: Enum "MIR Recharge Status")
    var
        StatusField: Integer;
    begin
        // Bypass the table's OnModify field-lock guard for this single, controlled
        // mutation by issuing a targeted ModifyAll over the primary key. Using a filtered
        // record + ModifyAll on just the Status field ensures no other field can be edited
        // here either — the codeunit cannot be used as a back door to mutate other fields.
        Rec.Status := NewStatus;
        StatusField := Rec.FieldNo(Status);
        // ModifyAll on a single-record filter is the BC idiom for a controlled, atomic
        // field update that bypasses OnModify (because OnModify enforces user-edit rules,
        // and ChangeStatus is itself the policy authority).
        UpdateStatusField(Rec."No.", NewStatus);
    end;

    local procedure UpdateStatusField(DocNo: Code[20]; NewStatus: Enum "MIR Recharge Status")
    var
        Header: Record "MIR Recharge Header";
    begin
        Header.SetRange("No.", DocNo);
        Header.ModifyAll(Status, NewStatus, false);
    end;

    local procedure ErrorFieldLocked(Rec: Record "MIR Recharge Header"; FieldName: Text)
    begin
        Error('Field ''%1'' on MIR Recharge Header %2 cannot be changed because the document status is %3. Only Draft documents may be edited.', FieldName, Rec."No.", Rec.Status);
    end;
}
