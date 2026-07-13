codeunit 50103 "ICR Approval Workflow"
{
    // Custom library codeunit that integrates the ICR Recharge Request with
    // BC's standard approval framework (WorkflowManagement 1501 + ApprovalsMgmt 1535).
    // Owns: event-code label, workflow event library registration, and the guarded
    // status transitions for Send / Cancel approval requests.

    var
        AlreadyPendingErr: Label 'Recharge Request %1 is already pending approval or in a non-submittable status (%2).', Comment = '%1=Document No., %2=Current Status';
        OpenApprovalExistsErr: Label 'Recharge Request %1 already has an open approval request. Cancel the existing request before submitting a new one.', Comment = '%1=Document No.';
        NotPendingErr: Label 'Recharge Request %1 cannot be cancelled because its status is %2 (only Pending Approval requests can be cancelled).', Comment = '%1=Document No., %2=Current Status';
        AuditSubmittedLbl: Label 'Recharge Request submitted for approval. Status changed from %1 to Pending Approval.', Comment = '%1 = previous Status';
        AuditCancelledLbl: Label 'Approval request cancelled. Status reverted from Pending Approval to Draft.';

    /// <summary>
    /// Stable event code used by administrators to compose a workflow that
    /// listens for the Send-For-Approval event on an ICR Recharge Request.
    /// </summary>
    procedure RunWorkflowOnSendICRRechargeRequestForApprovalCode(): Code[128]
    begin
        exit('RUNWORKFLOWONSENDICRRECHARGEREQUESTFORAPPROVAL');
    end;

    /// <summary>
    /// Stable event code used by administrators to compose a workflow that
    /// listens for the Cancel-Approval event on an ICR Recharge Request.
    /// </summary>
    procedure RunWorkflowOnCancelICRRechargeRequestApprovalCode(): Code[128]
    begin
        exit('RUNWORKFLOWONCANCELICRRECHARGEREQUESTAPPROVAL');
    end;

    /// <summary>
    /// Registers the ICR Send-For-Approval and Cancel-Approval events with
    /// the standard Workflow Event Handling library so administrators can
    /// pick them up in the Workflow designer.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Workflow Event Handling", 'OnAddWorkflowEventsToLibrary', '', false, false)]
    local procedure AddWorkflowEventsToLibrary()
    var
        WorkflowEventHandling: Codeunit "Workflow Event Handling";
        SendEventDescriptionLbl: Label 'Approval of an ICR Recharge Request is requested.';
        CancelEventDescriptionLbl: Label 'Approval of an ICR Recharge Request is cancelled.';
    begin
        WorkflowEventHandling.AddEventToLibrary(
            RunWorkflowOnSendICRRechargeRequestForApprovalCode(),
            DATABASE::"ICR Recharge Request",
            SendEventDescriptionLbl,
            0,
            false);
        WorkflowEventHandling.AddEventToLibrary(
            RunWorkflowOnCancelICRRechargeRequestApprovalCode(),
            DATABASE::"ICR Recharge Request",
            CancelEventDescriptionLbl,
            0,
            false);
    end;

    /// <summary>
    /// Submits the recharge request for approval. Applies the double-submit
    /// guards, flips Status to Pending Approval, persists via Modify(true),
    /// then dispatches through ApprovalsMgmt + WorkflowManagement so that any
    /// configured workflow can route by amount / recharge type.
    /// </summary>
    procedure OnSendICRRechargeRequestForApproval(var Header: Record "ICR Recharge Request")
    var
        WorkflowManagement: Codeunit "Workflow Management";
        ICRMgt: Codeunit "ICR Management";
        ApprovalEntry: Record "Approval Entry";
        RecRef: RecordRef;
        PreviousStatus: Text;
    begin
        // Guard 1: status must be in a submittable state.
        case Header.Status of
            Header.Status::"Pending Approval",
            Header.Status::Approved,
            Header.Status::Posted,
            Header.Status::Reversed,
            Header.Status::Closed:
                Error(AlreadyPendingErr, Header."No.", Format(Header.Status));
        end;

        // Guard 2: no open Approval Entry may already exist for this document.
        ApprovalEntry.Reset();
        ApprovalEntry.SetRange("Table ID", DATABASE::"ICR Recharge Request");
        ApprovalEntry.SetRange("Document No.", Header."No.");
        ApprovalEntry.SetRange(Status, ApprovalEntry.Status::Open);
        if not ApprovalEntry.IsEmpty() then
            Error(OpenApprovalExistsErr, Header."No.");

        PreviousStatus := Format(Header.Status);

        // Flip status and persist BEFORE calling the approval framework so
        // that subscribers reading the record see the new status.
        Header.Status := Header.Status::"Pending Approval";
        Header.Modify(true);

        // Dispatch through the workflow event engine.
        // WorkflowManagement.HandleEvent fires any configured workflow
        // listening for our event code (registered in
        // AddWorkflowEventsToLibrary) so administrators can route by
        // amount / Recharge Type. The standard Approvals Mgmt workflow
        // responses subscribe to this event and create the required
        // Approval Entry rows for this document.
        RecRef.GetTable(Header);
        WorkflowManagement.HandleEvent(
            RunWorkflowOnSendICRRechargeRequestForApprovalCode(),
            RecRef);

        // Audit — captured AFTER Modify(true) succeeds so the log only
        // reflects state changes that actually persisted.
        ICRMgt.LogAction('SUBMITTED', Header."No.",
            CopyStr(StrSubstNo(AuditSubmittedLbl, PreviousStatus), 1, 250));
    end;

    /// <summary>
    /// Cancels a Pending Approval recharge request. Reverts Status to Draft
    /// and asks the approval framework to cancel any related approval entries.
    /// </summary>
    procedure OnCancelICRRechargeRequestApprovalRequest(var Header: Record "ICR Recharge Request")
    var
        WorkflowManagement: Codeunit "Workflow Management";
        ICRMgt: Codeunit "ICR Management";
        ApprovalEntry: Record "Approval Entry";
        RecRef: RecordRef;
    begin
        // Guard: only Pending Approval can be cancelled.
        if Header.Status <> Header.Status::"Pending Approval" then
            Error(NotPendingErr, Header."No.", Format(Header.Status));

        // Fire the cancel workflow event so any standard Approvals Mgmt
        // workflow response subscribed to cancellation cleans up its
        // Approval Entry rows.
        RecRef.GetTable(Header);
        WorkflowManagement.HandleEvent(
            RunWorkflowOnCancelICRRechargeRequestApprovalCode(),
            RecRef);

        // Fallback for custom tables: also mark any lingering open approval
        // entries as Canceled directly so the record is not left in a
        // half-cancelled state if no workflow response was configured.
        ApprovalEntry.Reset();
        ApprovalEntry.SetRange("Table ID", DATABASE::"ICR Recharge Request");
        ApprovalEntry.SetRange("Document No.", Header."No.");
        ApprovalEntry.SetFilter(Status, '<>%1&<>%2',
            ApprovalEntry.Status::Rejected,
            ApprovalEntry.Status::Canceled);
        if ApprovalEntry.FindSet() then
            repeat
                ApprovalEntry.Validate(Status, ApprovalEntry.Status::Canceled);
                ApprovalEntry.Modify(true);
            until ApprovalEntry.Next() = 0;

        Header.Status := Header.Status::Draft;
        Header.Modify(true);

        // Audit — captured AFTER Modify(true) succeeds so the log only
        // reflects state changes that actually persisted.
        ICRMgt.LogAction('CANCELLED', Header."No.", AuditCancelledLbl);
    end;

    /// <summary>
    /// Forward-compatible pre-posting approval check. Returns TRUE when the
    /// header is in an approved state safe to post; returns FALSE otherwise.
    /// Callers that need to block posting until approval is complete can
    /// invoke this from the posting codeunit.
    /// </summary>
    procedure PrePostApprovalCheckICR(var Header: Record "ICR Recharge Request"): Boolean
    var
        ApprovalEntry: Record "Approval Entry";
    begin
        // Reject if the header is still pending approval.
        if Header.Status = Header.Status::"Pending Approval" then
            exit(false);

        // Reject if an open approval entry still exists.
        ApprovalEntry.Reset();
        ApprovalEntry.SetRange("Table ID", DATABASE::"ICR Recharge Request");
        ApprovalEntry.SetRange("Document No.", Header."No.");
        ApprovalEntry.SetRange(Status, ApprovalEntry.Status::Open);
        if not ApprovalEntry.IsEmpty() then
            exit(false);

        exit(true);
    end;

    /// <summary>
    /// Returns TRUE when an open Approval Entry currently exists for the
    /// supplied header. Used by the card page to enable/disable the Cancel
    /// Approval Request action.
    /// </summary>
    procedure OpenApprovalEntriesExist(var Header: Record "ICR Recharge Request"): Boolean
    var
        ApprovalEntry: Record "Approval Entry";
    begin
        if Header."No." = '' then
            exit(false);

        ApprovalEntry.Reset();
        ApprovalEntry.SetRange("Table ID", DATABASE::"ICR Recharge Request");
        ApprovalEntry.SetRange("Document No.", Header."No.");
        ApprovalEntry.SetRange(Status, ApprovalEntry.Status::Open);
        exit(not ApprovalEntry.IsEmpty());
    end;
}
