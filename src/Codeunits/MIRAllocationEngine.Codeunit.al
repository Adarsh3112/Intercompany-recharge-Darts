codeunit 50102 "MIR Allocation Engine"
{
    // MIR Allocation Engine
    // ---------------------
    // Single authority for validating and computing the allocation of an intercompany
    // recharge request across its child lines. Two public entry points:
    //
    //   * ValidateRechargeRequest(Header)  — committing pass. Re-computes Calculated
    //                                        Amount + Allocation Trace on every line,
    //                                        modifies them in the database, then runs
    //                                        the balance and percentage checks. Used by
    //                                        MIR Recharge Status Mgt before transitioning
    //                                        a document out of Draft.
    //
    //   * SimulateAllocation(Header, ...)  — non-committing pass. Returns the would-be
    //                                        results (per-line trace and aggregate totals)
    //                                        without touching the database. Used by the
    //                                        card page so users can preview before they
    //                                        commit to Validated status.
    //
    // The internal engine ComputeAndTrace() does the math identically in both modes; the
    // only difference is whether the line records are persisted via Modify or returned as
    // a temporary record buffer for the simulation caller.

    var
        EmptyLinesErr: Label 'MIR Recharge Header %1 has no allocation lines. Add at least one line before validating.', Comment = '%1 = document number';
        SourceAmountErr: Label 'MIR Recharge Header %1 has Source Amount of zero. Set a non-zero Source Amount before allocating.', Comment = '%1 = document number';
        OverAllocationErr: Label 'MIR Recharge Header %1 is over-allocated. Total Calculated Amount %2 exceeds Source Amount %3 by a variance of %4. Adjust the allocation lines so the total does not exceed the Source Amount.', Comment = '%1 = document number, %2 = total allocated, %3 = source amount, %4 = variance';
        PercentSumErr: Label 'MIR Recharge Header %1 uses Fixed %% allocation but the sum of Allocation Value across its lines is %2, not 100. The variance is %3. Adjust the percentages on the lines so they total exactly 100.', Comment = '%1 = document number, %2 = total percent, %3 = variance';
        LineMissingPartnerErr: Label 'MIR Recharge Header %1 line %2 is missing a Target Partner. Every allocation line must name the partner that receives the recharge.', Comment = '%1 = document number, %2 = line number';
        NegativeAllocationErr: Label 'MIR Recharge Header %1 line %2 has a negative Allocation Value (%3). Allocation values must be zero or positive.', Comment = '%1 = document number, %2 = line number, %3 = value';

    /// <summary>
    /// Validate a recharge request's allocation in committing mode. Re-computes the
    /// Calculated Amount and Allocation Trace on every line, writes them back, and then
    /// checks the aggregate balance and (for Fixed %) the percent-sum rule. Errors are
    /// raised that name the document and the variance. Returns true when the request is
    /// fully balanced (total equals Source Amount); returns false when the request is
    /// partial (total is below Source Amount) — partial allocation is allowed per spec.
    /// </summary>
    procedure ValidateRechargeRequest(var Header: Record "MIR Recharge Header"): Boolean
    var
        TotalAllocated: Decimal;
        TotalPercent: Decimal;
        LineCount: Integer;
        UsesFixedPercent: Boolean;
        IsBalanced: Boolean;
    begin
        // Committing path: ComputeAndTrace will Modify each line as it goes.
        ComputeAndTrace(Header, true, TotalAllocated, TotalPercent, LineCount, UsesFixedPercent);
        RunValidationChecks(Header, TotalAllocated, TotalPercent, LineCount, UsesFixedPercent, IsBalanced);
        exit(IsBalanced);
    end;

    /// <summary>
    /// Simulate the allocation without persisting any change. The provided temporary
    /// MIR Recharge Line buffer is populated with the would-be line state (Calculated
    /// Amount + Allocation Trace) so the caller can render a preview. Aggregate totals
    /// are returned by var. Validation rules are still evaluated and will raise the same
    /// errors as ValidateRechargeRequest — simulation is a dry run, not a way to bypass
    /// the rules. The caller may pass a Header.Status of Draft (typical) or any status;
    /// no status transition is performed.
    /// </summary>
    procedure SimulateAllocation(var Header: Record "MIR Recharge Header"; var TempLineBuffer: Record "MIR Recharge Line" temporary; var TotalAllocated: Decimal; var TotalPercent: Decimal; var IsBalanced: Boolean)
    var
        Line: Record "MIR Recharge Line";
        LineCount: Integer;
        UsesFixedPercent: Boolean;
    begin
        // Clear any existing buffer state from a prior simulation so the caller never
        // sees stale rows mixed with the new run.
        TempLineBuffer.Reset();
        TempLineBuffer.DeleteAll();

        // Non-committing path. ComputeAndTrace writes nothing — instead we re-loop here
        // over the live lines, copy them into the temporary buffer, and re-apply the same
        // math so the buffer holds the simulated result. The committing path computes
        // totals; we mirror that here to populate the temp buffer.
        ComputeAndTrace(Header, false, TotalAllocated, TotalPercent, LineCount, UsesFixedPercent);

        // Materialise the simulated lines into the temporary buffer.
        Line.SetRange("Document No.", Header."No.");
        Line.SetCurrentKey("Document No.", "Line No.");
        if Line.FindSet() then
            repeat
                TempLineBuffer.Init();
                TempLineBuffer.TransferFields(Line, true);
                TempLineBuffer."Calculated Amount" := ComputeLineAmount(Header, Line);
                TempLineBuffer."Allocation Trace" := BuildLineTrace(Header, Line);
                TempLineBuffer.Insert();
            until Line.Next() = 0;

        // Run the same validation gauntlet the committing path runs. This makes
        // simulation a true dry-run of the validation logic — if the user would be
        // blocked at SetValidated, they're blocked here too, with the same error text.
        RunValidationChecks(Header, TotalAllocated, TotalPercent, LineCount, UsesFixedPercent, IsBalanced);
    end;

    /// <summary>
    /// Core engine. Loops through the lines of the header, computes the Calculated Amount
    /// and the Allocation Trace text per line, and accumulates the totals. When Commit is
    /// true each line is Modify'd so the persisted state matches the engine's view. When
    /// Commit is false the database is untouched and the caller is expected to materialise
    /// the result into a temporary buffer (see SimulateAllocation).
    /// </summary>
    local procedure ComputeAndTrace(var Header: Record "MIR Recharge Header"; Commit: Boolean; var TotalAllocated: Decimal; var TotalPercent: Decimal; var LineCount: Integer; var UsesFixedPercent: Boolean)
    var
        Line: Record "MIR Recharge Line";
        ComputedAmount: Decimal;
        TraceText: Text[250];
    begin
        TotalAllocated := 0;
        TotalPercent := 0;
        LineCount := 0;
        UsesFixedPercent := false;

        // The header must exist; defensive Get is cheap and gives a clear error path
        // if a caller hands us a zero-PK record by accident.
        if Header."No." = '' then
            exit;

        Line.SetRange("Document No.", Header."No.");
        Line.SetCurrentKey("Document No.", "Line No.");
        if not Line.FindSet() then
            exit;

        // Single pass: compute amount + trace, accumulate running totals. The spec's
        // technical hint asks for exactly this — a loop with a running total — so the
        // accumulator is visible and auditable rather than buried inside CalcSums.
        repeat
            // Per-line guard: a missing partner or negative value is a data error that
            // we surface immediately with the document + line number named, rather than
            // letting it propagate into a confusing aggregate error later.
            if Line."Target Partner" = '' then
                Error(LineMissingPartnerErr, Header."No.", Line."Line No.");
            if Line."Allocation Value" < 0 then
                Error(NegativeAllocationErr, Header."No.", Line."Line No.", Line."Allocation Value");

            ComputedAmount := ComputeLineAmount(Header, Line);
            TraceText := BuildLineTrace(Header, Line);

            // Detect whether ANY line uses Fixed % — if so, the percentage-sum check
            // applies to the whole document. Mixed-basis documents (some Fixed %, some
            // Amount) are not in scope for the MVP; the percent check still runs over
            // the Fixed-% lines only.
            if Line."Allocation Basis" = Line."Allocation Basis"::"Fixed %" then begin
                UsesFixedPercent := true;
                TotalPercent += Line."Allocation Value";
            end;

            TotalAllocated += ComputedAmount;
            LineCount += 1;

            // Persist if we are in committing mode. The line table's OnModify enforces
            // the field-lock policy (only Draft headers may have line edits), so this
            // Modify will Error early if a caller misuses the engine on a frozen doc.
            if Commit then begin
                Line."Calculated Amount" := ComputedAmount;
                Line."Allocation Trace" := TraceText;
                Line.Modify(true);
            end;
        until Line.Next() = 0;
    end;

    /// <summary>
    /// Pure function: given a header and one line, what Calculated Amount should the line
    /// hold? Encapsulates the basis-by-basis math so the calc rule lives in exactly one
    /// place (and the simulation path can reuse it without touching the database).
    /// </summary>
    local procedure ComputeLineAmount(Header: Record "MIR Recharge Header"; Line: Record "MIR Recharge Line"): Decimal
    begin
        case Line."Allocation Basis" of
            Line."Allocation Basis"::"Fixed %":
                exit(Round(Header."Source Amount" * Line."Allocation Value" / 100, 0.01));
            Line."Allocation Basis"::Amount:
                exit(Round(Line."Allocation Value", 0.01));
            Line."Allocation Basis"::Dimension,
            Line."Allocation Basis"::Headcount:
                // MVP behaviour matches the table-side default: the entered value is the
                // computed amount. A future driver-based engine will replace this branch.
                exit(Round(Line."Allocation Value", 0.01));
        end;
        exit(0);
    end;

    /// <summary>
    /// Build the human-readable trace string that goes into the line's Allocation Trace
    /// field. The spec gives '1000 * 25%' as the canonical example for Fixed %; we follow
    /// that pattern for every basis so an auditor can read a line and reconstruct the
    /// calculation without opening the engine code.
    /// </summary>
    local procedure BuildLineTrace(Header: Record "MIR Recharge Header"; Line: Record "MIR Recharge Line"): Text[250]
    var
        Result: Text;
        ComputedAmount: Decimal;
    begin
        ComputedAmount := ComputeLineAmount(Header, Line);
        case Line."Allocation Basis" of
            Line."Allocation Basis"::"Fixed %":
                // Spec example shape: '1000 * 25% = 250.00'. Including the result on the
                // right side makes the trace self-checking without consulting Calculated
                // Amount separately.
                Result := StrSubstNo('%1 * %2%% = %3', FormatAmount(Header."Source Amount"), FormatPercent(Line."Allocation Value"), FormatAmount(ComputedAmount));
            Line."Allocation Basis"::Amount:
                Result := StrSubstNo('Fixed amount = %1', FormatAmount(ComputedAmount));
            Line."Allocation Basis"::Dimension:
                Result := StrSubstNo('Dimension-driven (value %1) = %2', FormatAmount(Line."Allocation Value"), FormatAmount(ComputedAmount));
            Line."Allocation Basis"::Headcount:
                Result := StrSubstNo('Headcount-driven (value %1) = %2', FormatAmount(Line."Allocation Value"), FormatAmount(ComputedAmount));
            else
                Result := StrSubstNo('Unknown basis = %1', FormatAmount(ComputedAmount));
        end;

        // Allocation Trace is Text[250]; truncate defensively so the engine cannot blow
        // up on a particularly verbose future basis. CopyStr is the BC idiom.
        exit(CopyStr(Result, 1, 250));
    end;

    /// <summary>
    /// Apply the two business rules from the spec:
    ///   1. Sum of Calculated Amount must not exceed Source Amount. Equality means
    ///      balanced; below means partial (allowed). Above means over-allocated (error).
    ///   2. If any line uses Fixed %, the sum of Allocation Value across Fixed-% lines
    ///      must equal exactly 100.
    /// Errors name the document and the numeric variance so the user can fix the input
    /// without having to compute the gap themselves.
    /// </summary>
    local procedure RunValidationChecks(Header: Record "MIR Recharge Header"; TotalAllocated: Decimal; TotalPercent: Decimal; LineCount: Integer; UsesFixedPercent: Boolean; var IsBalanced: Boolean)
    var
        Variance: Decimal;
    begin
        // A header with no lines cannot be validated — the user needs to add lines first.
        if LineCount = 0 then
            Error(EmptyLinesErr, Header."No.");

        // A zero Source Amount makes the percentage math meaningless and the balance
        // check trivially-true; reject it explicitly so the user fixes the header first.
        if Header."Source Amount" = 0 then
            Error(SourceAmountErr, Header."No.");

        // Rule 1: total allocation must not exceed source amount.
        if TotalAllocated > Header."Source Amount" then begin
            Variance := TotalAllocated - Header."Source Amount";
            Error(OverAllocationErr, Header."No.", FormatAmount(TotalAllocated), FormatAmount(Header."Source Amount"), FormatAmount(Variance));
        end;

        // Rule 2: percentages over Fixed-% lines must total exactly 100. We use a tiny
        // tolerance (0.01) to absorb rounding noise from user input — five-decimal entry
        // can produce sums of 99.99999 which the user reads as 100.
        if UsesFixedPercent then
            if Abs(TotalPercent - 100) > 0.01 then begin
                Variance := TotalPercent - 100;
                Error(PercentSumErr, Header."No.", FormatPercent(TotalPercent), FormatPercent(Variance));
            end;

        // "Balanced" means the user has allocated 100% of the source amount. Below that,
        // the document is a partial allocation — still valid per spec, but the caller
        // (e.g. card page Simulate) may want to surface the difference to the user.
        IsBalanced := (Header."Source Amount" - TotalAllocated) <= 0.01;
    end;

    local procedure FormatAmount(Value: Decimal): Text
    begin
        // Use a stable 2-decimal format so error messages and trace strings line up
        // visually regardless of regional formatting. <Precision,2:2> = exactly 2 dp.
        exit(Format(Value, 0, '<Precision,2:2><Sign><Integer><Decimals>'));
    end;

    local procedure FormatPercent(Value: Decimal): Text
    begin
        // Percentages may legitimately carry more decimal places than amounts (e.g. a
        // 33.33333% three-way split). Allow up to 5 dp so the trace tells the truth.
        exit(Format(Value, 0, '<Precision,2:5><Sign><Integer><Decimals>'));
    end;
}
