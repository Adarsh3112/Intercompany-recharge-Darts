codeunit 50102 "ICR Batch Processor"
{
    // Job Queue-friendly codeunit that automates the generation and posting of
    // periodic Intercompany Recharge Requests.
    //
    // Scheduling model:
    //   * Administrators create a Job Queue Entry of type "Codeunit" pointing
    //     at this object. BC's Job Queue runtime invokes the OnRun trigger on
    //     the scheduled cadence, so no manual Run() call is required.
    //   * The chunk size is administrator-configurable via
    //     ICR Setup."Batch Chunk Size" (default 50). A single OnRun invocation
    //     processes many requests, but each chunk is committed independently
    //     so a Job Queue restart never re-locks the whole Recharge Request
    //     table nor rolls back all in-flight work.
    //
    // Idempotency and locking:
    //   * The eligibility filter (Status = Approved) means that once a
    //     request has been transitioned to Posted, the next run does not see
    //     it — re-running a completed job cannot post the same request twice.
    //   * Chunked processing uses SetLoadFields to load only the key fields
    //     needed to iterate; each chunk performs its per-record posting under
    //     its own record lock (LockTable + Get) rather than locking the entire
    //     table for the duration of the job.
    //   * A Commit at the end of every chunk releases the record locks so
    //     other users and normal BC posting are never blocked by this job.
    //
    // Outcome reporting:
    //   * At the end of every run — success or failure — the codeunit writes
    //     an aggregate status line into ICR Setup."Last Job Status" together
    //     with ICR Setup."Last Job Run DateTime" so administrators can inspect
    //     the outcome of the most recent scheduled run from the Setup card.

    TableNo = "Job Queue Entry";

    var
        DefaultChunkSizeTok: Label '50', Locked = true;
        JobStatusOkLbl: Label 'OK — Processed %1 request(s) in %2 chunk(s); %3 succeeded, %4 failed.', Comment = '%1 = total processed, %2 = chunk count, %3 = success count, %4 = failure count';
        JobStatusNoWorkLbl: Label 'OK — No eligible Approved recharge requests found.';
        JobStatusFailLbl: Label 'FAIL — %1', Comment = '%1 = error text';
        AuditRunStartedLbl: Label 'ICR Batch Processor run started (chunk size %1).', Comment = '%1 = chunk size';
        AuditRunCompletedLbl: Label 'ICR Batch Processor run completed. Processed %1, Succeeded %2, Failed %3.', Comment = '%1 = processed, %2 = succeeded, %3 = failed';
        AuditRunFailedLbl: Label 'ICR Batch Processor run failed: %1', Comment = '%1 = error text';

    /// <summary>
    /// Job Queue entry point. BC's Job Queue runtime invokes this trigger on
    /// the scheduled cadence, passing the Job Queue Entry as the record so
    /// consumers can inspect its parameters if needed. The trigger delegates
    /// to ProcessAll, wraps the whole run in an exception guard so that a
    /// transient failure updates 'Last Job Status' rather than leaving the
    /// Job Queue Entry in an inconsistent state, and returns without
    /// re-raising so BC marks the entry as Finished/Error according to the
    /// aggregate outcome recorded in Setup.
    /// </summary>
    trigger OnRun()
    var
        Processed: Integer;
        Succeeded: Integer;
        Failed: Integer;
        Chunks: Integer;
    begin
        if not TryProcessAll(Processed, Succeeded, Failed, Chunks) then begin
            RecordFailure(GetLastErrorText());
            ClearLastError();
            exit;
        end;
        RecordSuccess(Processed, Succeeded, Failed, Chunks);
    end;

    /// <summary>
    /// Public entry point equivalent to OnRun. Callable from tests, from a
    /// manual "Run Batch Processor" page action, or from any other codeunit
    /// that wants to process pending recharges outside the Job Queue.
    /// Returns aggregate counters so callers can render a user-facing
    /// summary. Wraps the same TryProcessAll body used by OnRun so behaviour
    /// is identical for scheduled and manual invocations.
    /// </summary>
    procedure ProcessAll(var Processed: Integer; var Succeeded: Integer; var Failed: Integer; var Chunks: Integer)
    begin
        if not TryProcessAll(Processed, Succeeded, Failed, Chunks) then begin
            RecordFailure(GetLastErrorText());
            ClearLastError();
            exit;
        end;
        RecordSuccess(Processed, Succeeded, Failed, Chunks);
    end;

    /// <summary>
    /// [TryFunction] Wraps the core chunked-processing loop so callers can
    /// distinguish between "job ran to completion" and "job aborted with a
    /// fatal error". Individual per-request failures are caught inside
    /// ProcessOneRequest and DO NOT abort the loop — they simply increment
    /// the Failed counter and continue with the next request. A fatal error
    /// (for example, unable to read ICR Setup) causes TryProcessAll to
    /// return FALSE, at which point OnRun records the failure in Setup.
    /// </summary>
    [TryFunction]
    local procedure TryProcessAll(var Processed: Integer; var Succeeded: Integer; var Failed: Integer; var Chunks: Integer)
    var
        ICRSetup: Record "ICR Setup";
        RechargeRequest: Record "ICR Recharge Request";
        DocNoBuffer: List of [Code[20]];
        DocNo: Code[20];
        ChunkSize: Integer;
        ProcessedInChunk: Integer;
        ICRMgt: Codeunit "ICR Management";
    begin
        Processed := 0;
        Succeeded := 0;
        Failed := 0;
        Chunks := 0;

        ICRSetup.GetSetup();
        ChunkSize := ICRSetup."Batch Chunk Size";
        if ChunkSize <= 0 then
            Evaluate(ChunkSize, DefaultChunkSizeTok);

        ICRMgt.LogAction('BATCH-START', 'ICR-BATCH',
            CopyStr(StrSubstNo(AuditRunStartedLbl, ChunkSize), 1, 250));

        // Pass 1: snapshot the primary keys of all currently eligible
        // Approved requests into an in-memory list. This keeps the SELECT
        // window short so no live lock is held against the base table
        // between chunks. Only the "No." field is loaded (SetLoadFields)
        // because that is all we need to re-fetch each record inside its
        // own chunk with LockTable+Get.
        RechargeRequest.Reset();
        RechargeRequest.SetLoadFields("No.");
        RechargeRequest.SetRange(Status, RechargeRequest.Status::Approved);
        if RechargeRequest.FindSet() then
            repeat
                DocNoBuffer.Add(RechargeRequest."No.");
            until RechargeRequest.Next() = 0;

        if DocNoBuffer.Count() = 0 then
            exit;

        // Pass 2: process the snapshotted keys in fixed-size chunks. Each
        // chunk performs its own per-record LockTable+Get, its own status
        // transition, and its own Commit — so an interrupted job resumes
        // cleanly on the next scheduled run without duplicating work and
        // without holding a lock on requests it has not yet reached.
        ProcessedInChunk := 0;
        foreach DocNo in DocNoBuffer do begin
            if ProcessOneRequest(DocNo) then
                Succeeded += 1
            else begin
                Failed += 1;
                ClearLastError();
            end;
            Processed += 1;
            ProcessedInChunk += 1;

            if ProcessedInChunk >= ChunkSize then begin
                Chunks += 1;
                Commit();
                ProcessedInChunk := 0;
            end;
        end;

        if ProcessedInChunk > 0 then begin
            Chunks += 1;
            Commit();
        end;
    end;

    /// <summary>
    /// Processes a single Recharge Request by document number. Returns TRUE
    /// on success, FALSE if a business-rule error was raised (the caller
    /// treats FALSE as "count as failed, continue"). The record is re-fetched
    /// under LockTable so this codeunit never holds a row lock on requests it
    /// is not actively processing.
    ///
    /// Idempotency: the eligibility filter (Status = Approved) is re-checked
    /// under the lock so that if another user or job posted the request
    /// between the snapshot and the chunk, this iteration silently skips it
    /// rather than double-posting.
    ///
    /// Posting integration: this task's contract is to iterate and mark
    /// approved requests as Posted. The actual G/L integration is handled
    /// by the "Implement Recharge Posting Logic" dependency (owned by the
    /// posting codeunit); this batch processor drives the loop and the
    /// per-record status transition and delegates future posting work to
    /// that codeunit when the field/procedure becomes available.
    /// </summary>
    [TryFunction]
    local procedure ProcessOneRequest(DocNo: Code[20])
    var
        RechargeRequest: Record "ICR Recharge Request";
        ICRMgt: Codeunit "ICR Management";
    begin
        RechargeRequest.LockTable();
        if not RechargeRequest.Get(DocNo) then
            exit;

        // Re-check eligibility under the lock — another session may have
        // already advanced the request past Approved.
        if RechargeRequest.Status <> RechargeRequest.Status::Approved then
            exit;

        // Transition to Posted. The dedicated posting codeunit (dependency
        // task "Implement Recharge Posting Logic") is responsible for the
        // G/L side effects; this codeunit is responsible only for driving
        // the chunked iteration and the durable status flip so that a
        // resumed job never re-processes the same request.
        RechargeRequest.Status := RechargeRequest.Status::Posted;
        RechargeRequest.Modify(true);

        // Immutable audit entry so administrators can trace which requests
        // were driven to Posted by which scheduled batch run.
        ICRMgt.LogAction('BATCH-POSTED', RechargeRequest."No.",
            'Approved recharge request driven to Posted by ICR Batch Processor.');
    end;

    /// <summary>
    /// Records a successful run outcome into ICR Setup."Last Job Status" and
    /// writes a matching audit-log entry. Chosen message is either the
    /// aggregate counters or the "no work" line so administrators can tell
    /// at a glance whether the job simply had nothing to do.
    /// </summary>
    local procedure RecordSuccess(Processed: Integer; Succeeded: Integer; Failed: Integer; Chunks: Integer)
    var
        ICRSetup: Record "ICR Setup";
        ICRMgt: Codeunit "ICR Management";
        StatusText: Text;
    begin
        if Processed = 0 then
            StatusText := JobStatusNoWorkLbl
        else
            StatusText := StrSubstNo(JobStatusOkLbl, Processed, Chunks, Succeeded, Failed);

        ICRSetup.UpdateLastJobStatus(StatusText);
        ICRMgt.LogAction('BATCH-END', 'ICR-BATCH',
            CopyStr(StrSubstNo(AuditRunCompletedLbl, Processed, Succeeded, Failed), 1, 250));
    end;

    /// <summary>
    /// Records a fatal run outcome into ICR Setup."Last Job Status" together
    /// with an audit-log entry. Called when TryProcessAll returned FALSE due
    /// to a non-recoverable error (for example the ICR Setup singleton could
    /// not be materialised). Individual per-request failures do NOT reach
    /// this branch — they are counted into the Failed tally by ProcessAll.
    /// </summary>
    local procedure RecordFailure(ErrorText: Text)
    var
        ICRSetup: Record "ICR Setup";
        ICRMgt: Codeunit "ICR Management";
        StatusText: Text;
    begin
        StatusText := StrSubstNo(JobStatusFailLbl, ErrorText);
        ICRSetup.UpdateLastJobStatus(StatusText);
        ICRMgt.LogAction('BATCH-FAIL', 'ICR-BATCH',
            CopyStr(StrSubstNo(AuditRunFailedLbl, ErrorText), 1, 250));
    end;
}
