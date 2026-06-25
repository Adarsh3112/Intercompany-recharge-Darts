codeunit 50100 "IC Recharge Calculation"
{

    /// <summary>
    /// Main entry point: calculates and writes Recharge Amount on every line
    /// belonging to the given IC Recharge Request Header.
    ///
    /// Rules applied per line:
    ///   • Recharge Method = "Fixed Amount"  → Recharge Amount is left as-is (user-entered).
    ///     The engine only validates that the sum does not exceed Source Amount on the header.
    ///   • Recharge Method = "Percentage"    → Recharge Amount = Round(Source Amount × Allocation % / 100, 0.01).
    ///     After calculating all lines, any rounding residual is pushed onto the last Percentage line.
    ///   • Recharge Method = "Actual Cost"   → Recharge Amount = Source Amount (full pass-through).
    ///   • Recharge Method = " " (blank)     → treated the same as Percentage.
    ///
    /// After calculating amounts, the engine resolves the currency for each line
    /// using the partner-specific Currency Rule, looks up the exchange rate from
    /// the Currency Exchange Rate table, stores it on the line, and computes
    /// Exchange Rate Amount (Recharge Amount converted to the line currency).
    ///
    /// Excess-amount guard: if the running sum of Fixed Amount lines already exceeds
    /// the header Source Amount the procedure raises an error before writing anything.
    /// </summary>
    procedure CalculateAllocations(var RechargeHeader: Record "IC Recharge Request Header")
    var
        ReqLine: Record "IC Recharge Request Line";
        LastPctLine: Record "IC Recharge Request Line";
        SourceAmt: Decimal;
        TotalFixed: Decimal;
        TotalPct: Decimal;
        RemainingForPct: Decimal;
        RunningPctAmt: Decimal;
        LastPctLineNo: Integer;
        HasLastPct: Boolean;
    begin
        // ── 1. Determine the source amount to distribute ──────────────────────────
        SourceAmt := GetSourceAmount(RechargeHeader);
        if SourceAmt = 0 then
            exit; // Nothing to distribute

        // ── 2. First pass: accumulate Fixed Amount totals & guard against excess ──
        TotalFixed := 0;
        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        if ReqLine.FindSet() then
            repeat
                if ReqLine."Recharge Method" = ReqLine."Recharge Method"::"Fixed Amount" then
                    TotalFixed += ReqLine."Recharge Amount";
            until ReqLine.Next() = 0;

        if (SourceAmt > 0) and (TotalFixed > SourceAmt + GetRoundingPrecision()) then
            Error(TotalFixedExceedsSourceErr, TotalFixed, SourceAmt);

        // ── 3. Calculate remaining budget for Percentage lines ────────────────────
        RemainingForPct := SourceAmt - TotalFixed;

        // ── 4. Second pass: compute Percentage / Actual Cost lines ────────────────
        RunningPctAmt := 0;
        HasLastPct := false;
        LastPctLineNo := 0;

        ReqLine.Reset();
        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        ReqLine.SetCurrentKey("Request No.", "Line No.");
        if ReqLine.FindSet() then
            repeat
                case ReqLine."Recharge Method" of
                    ReqLine."Recharge Method"::"Fixed Amount":
                        begin
                            // Fixed Amount lines: user already entered Recharge Amount.
                            // Recalculate Allocation % for display consistency.
                            if SourceAmt <> 0 then
                                ReqLine."Allocation %" := Round(ReqLine."Recharge Amount" / SourceAmt * 100, 0.00001)
                            else
                                ReqLine."Allocation %" := 0;
                            ReqLine.Modify(false);
                        end;
                    ReqLine."Recharge Method"::"Actual Cost":
                        begin
                            // Full pass-through of the source amount.
                            ReqLine."Recharge Amount" := SourceAmt;
                            ReqLine."Allocation %" := 100;
                            ReqLine.Modify(false);
                            RunningPctAmt += ReqLine."Recharge Amount";
                        end;
                    else begin
                        // "Percentage" and blank: compute proportionally.
                        ReqLine."Recharge Amount" := Round(RemainingForPct * ReqLine."Allocation %" / 100, GetRoundingPrecision());
                        RunningPctAmt += ReqLine."Recharge Amount";
                        // Track last Percentage line for rounding correction.
                        LastPctLineNo := ReqLine."Line No.";
                        HasLastPct := true;
                        ReqLine.Modify(false);
                    end;
                end;
            until ReqLine.Next() = 0;

        // ── 5. Rounding correction: push residual onto last Percentage line ───────
        if HasLastPct then begin
            TotalPct := RunningPctAmt;
            if TotalPct <> RemainingForPct then begin
                LastPctLine.Get(RechargeHeader."No.", LastPctLineNo);
                LastPctLine."Recharge Amount" := LastPctLine."Recharge Amount" + (RemainingForPct - TotalPct);
                if SourceAmt <> 0 then
                    LastPctLine."Allocation %" := Round(LastPctLine."Recharge Amount" / SourceAmt * 100, 0.00001)
                else
                    LastPctLine."Allocation %" := 0;
                LastPctLine."Allocation Calculation Note" :=
                    CopyStr(StrSubstNo(RoundingAdjNoteMsg, RemainingForPct - TotalPct), 1, MaxStrLen(LastPctLine."Allocation Calculation Note"));
                LastPctLine.Modify(false);
            end;
        end;

        // ── 6. Currency conversion pass: resolve rate and stamp Exchange Rate fields
        ApplyCurrencyConversion(RechargeHeader);

        // ── 7. Refresh the header total ───────────────────────────────────────────
        RechargeHeader.CalcTotalAmount();
    end;

    /// <summary>
    /// Validates that allocations are consistent before the document status
    /// can move from Draft → Validated.
    ///
    /// For Percentage-type lines the sum of Allocation % must equal 100
    /// (within the rounding precision tolerance).
    /// For Fixed Amount lines the sum of Recharge Amount must equal or be
    /// less than the source total (the engine never distributes more than the source).
    /// Mixed documents must satisfy both conditions per their respective line groups.
    ///
    /// Additionally validates that every line carrying a non-LCY Currency Code
    /// has a valid exchange rate in the Currency Exchange Rate table as of the
    /// header Posting Date.  Raises an error on unmapped currency or missing rate.
    ///
    /// Raises an error with a descriptive message on any violation.
    /// </summary>
    procedure ValidateAllocations(var RechargeHeader: Record "IC Recharge Request Header")
    var
        ReqLine: Record "IC Recharge Request Line";
        SourceAmt: Decimal;
        TotalPct: Decimal;
        TotalFixed: Decimal;
        TotalActual: Decimal;
        HasPctLines: Boolean;
        HasFixedLines: Boolean;
        HasActualLines: Boolean;
    begin
        SourceAmt := GetSourceAmount(RechargeHeader);

        TotalPct := 0;
        TotalFixed := 0;
        TotalActual := 0;
        HasPctLines := false;
        HasFixedLines := false;
        HasActualLines := false;

        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        if ReqLine.FindSet() then
            repeat
                case ReqLine."Recharge Method" of
                    ReqLine."Recharge Method"::"Fixed Amount":
                        begin
                            HasFixedLines := true;
                            TotalFixed += ReqLine."Recharge Amount";
                        end;
                    ReqLine."Recharge Method"::"Actual Cost":
                        begin
                            HasActualLines := true;
                            TotalActual += ReqLine."Recharge Amount";
                        end;
                    else begin
                        // Percentage and blank
                        HasPctLines := true;
                        TotalPct += ReqLine."Allocation %";
                    end;
                end;

                // Validate currency mapping and rate for every line with a non-LCY currency
                if ReqLine."Currency Code" <> '' then
                    ValidateCurrencyRate(ReqLine."Currency Code", RechargeHeader."Posting Date", ReqLine."Line No.");
            until ReqLine.Next() = 0;

        // Percentage lines: allocations must sum to exactly 100 %
        if HasPctLines then
            if Abs(TotalPct - 100) > GetPctTolerance() then
                Error(PctAllocationNotBalancedErr, TotalPct);

        // Fixed Amount lines: sum must not exceed source amount
        if HasFixedLines then begin
            if TotalFixed > SourceAmt + GetRoundingPrecision() then
                Error(TotalFixedExceedsSourceErr, TotalFixed, SourceAmt);
            // In a Fixed-only document the sum should equal the source amount
            if (not HasPctLines) and (not HasActualLines) then
                if Abs(TotalFixed - SourceAmt) > GetRoundingPrecision() then
                    Error(FixedAmtNotBalancedErr, TotalFixed, SourceAmt);
        end;

        // Actual Cost lines: each line must equal the source amount (they are 1:1)
        if HasActualLines then
            if TotalActual > SourceAmt + GetRoundingPrecision() then
                Error(ActualCostExceedsSourceErr, TotalActual, SourceAmt);
    end;

    /// <summary>
    /// Iterates all lines on the request, resolves the effective currency from the
    /// partner Currency Rule, fetches the exchange rate from the Currency Exchange
    /// Rate table as of the header Posting Date, and writes:
    ///   • Line."Currency Code"       – the resolved currency (if not already set)
    ///   • Line."Exchange Rate"        – relational exchange rate amount / exchange rate (stored as factor)
    ///   • Line."Exchange Rate Amount" – Recharge Amount converted to line currency
    ///
    /// Raises an error if a non-LCY line has no exchange rate entry.
    /// </summary>
    procedure ApplyCurrencyConversion(var RechargeHeader: Record "IC Recharge Request Header")
    var
        ReqLine: Record "IC Recharge Request Line";
        ICRechargePartner: Record "IC Recharge Partner";
        ExchRate: Decimal;
        EffectiveCurrCode: Code[10];
        PostingDate: Date;
    begin
        PostingDate := RechargeHeader."Posting Date";
        if PostingDate = 0D then
            PostingDate := WorkDate();

        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        ReqLine.SetCurrentKey("Request No.", "Line No.");
        if not ReqLine.FindSet() then
            exit;

        repeat
            // Determine the effective currency for this line
            EffectiveCurrCode := ReqLine."Currency Code";

            // If not yet set, resolve from partner Currency Rule
            if EffectiveCurrCode = '' then
                if ICRechargePartner.Get(ReqLine."IC Partner Code") then
                    EffectiveCurrCode := ResolvePartnerCurrency(ICRechargePartner, RechargeHeader);

            if EffectiveCurrCode <> '' then begin
                // Fetch exchange rate from Currency Exchange Rate table
                ExchRate := GetCurrencyExchangeRate(EffectiveCurrCode, PostingDate, ReqLine."Line No.");

                ReqLine."Currency Code" := EffectiveCurrCode;
                ReqLine."Exchange Rate" := ExchRate;
                // Exchange Rate Amount = Recharge Amount / Exchange Rate
                // (Exchange Rate is expressed as LCY per 1 unit of foreign currency,
                //  so to convert LCY amount to FCY we divide by the rate)
                if ExchRate <> 0 then
                    ReqLine."Exchange Rate Amount" := Round(ReqLine."Recharge Amount" / ExchRate, GetRoundingPrecision())
                else
                    ReqLine."Exchange Rate Amount" := ReqLine."Recharge Amount";
            end else begin
                // LCY line — rate = 1, amount equals recharge amount
                ReqLine."Exchange Rate" := 1;
                ReqLine."Exchange Rate Amount" := ReqLine."Recharge Amount";
            end;

            ReqLine.Modify(false);
        until ReqLine.Next() = 0;
    end;

    // ─────────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Resolves the currency code for a partner line based on the partner's
    /// Currency Rule setting.
    /// </summary>
    local procedure ResolvePartnerCurrency(
        var Partner: Record "IC Recharge Partner";
        var Header: Record "IC Recharge Request Header"): Code[10]
    begin
        case Partner."Currency Rule" of
            Partner."Currency Rule"::"Use Partner Currency":
                exit(Partner."Currency Code");
            Partner."Currency Rule"::"Use Source Currency":
                exit(Header."Currency Code");
            Partner."Currency Rule"::"Use Fixed Currency":
                exit(Partner."Currency Code");
            else
                exit(Header."Currency Code");
        end;
    end;

    /// <summary>
    /// Looks up the exchange rate for CurrencyCode as of PostingDate from the
    /// standard BC "Currency Exchange Rate" table.
    ///
    /// Returns the rate as: Relational Exch. Rate Amount / Exchange Rate Amount
    /// (LCY units per 1 unit of foreign currency).
    ///
    /// Raises an error if:
    ///   • The currency code is not mapped in the Currency table, or
    ///   • No exchange rate entry exists on or before PostingDate.
    /// </summary>
    local procedure GetCurrencyExchangeRate(
        CurrencyCode: Code[10];
        PostingDate: Date;
        LineNo: Integer): Decimal
    var
        CurrExchRate: Record "Currency Exchange Rate";
        ExchRateAmt: Decimal;
        RelationalAmt: Decimal;
    begin
        if CurrencyCode = '' then
            exit(1);

        // Find the most recent exchange rate on or before PostingDate
        CurrExchRate.SetRange("Currency Code", CurrencyCode);
        CurrExchRate.SetRange("Starting Date", 0D, PostingDate);
        if not CurrExchRate.FindLast() then
            Error(MissingExchangeRateErr, CurrencyCode, PostingDate, LineNo);

        ExchRateAmt := CurrExchRate."Exchange Rate Amount";
        RelationalAmt := CurrExchRate."Relational Exch. Rate Amount";

        if (ExchRateAmt = 0) or (RelationalAmt = 0) then
            Error(InvalidExchangeRateErr, CurrencyCode, PostingDate, LineNo);

        // Rate = Relational Amount / Exchange Rate Amount
        // Example: Exchange Rate Amount = 1, Relational = 1.25 → 1 EUR = 1.25 LCY → rate = 1.25
        exit(RelationalAmt / ExchRateAmt);
    end;

    /// <summary>
    /// Validates that a currency rate exists for the given currency and date.
    /// Called from ValidateAllocations to surface errors before the status
    /// advances.  Raises descriptive errors for unmapped or missing rates.
    /// </summary>
    local procedure ValidateCurrencyRate(
        CurrencyCode: Code[10];
        PostingDate: Date;
        LineNo: Integer)
    var
        Currency: Record Currency;
        CurrExchRate: Record "Currency Exchange Rate";
    begin
        // Validate the currency code is defined
        if not Currency.Get(CurrencyCode) then
            Error(UnmappedCurrencyErr, CurrencyCode, LineNo);

        // Validate an exchange rate exists on or before the posting date
        CurrExchRate.SetRange("Currency Code", CurrencyCode);
        if PostingDate <> 0D then
            CurrExchRate.SetRange("Starting Date", 0D, PostingDate);
        if not CurrExchRate.FindLast() then
            Error(MissingExchangeRateErr, CurrencyCode, PostingDate, LineNo);

        if (CurrExchRate."Exchange Rate Amount" = 0) or (CurrExchRate."Relational Exch. Rate Amount" = 0) then
            Error(InvalidExchangeRateErr, CurrencyCode, PostingDate, LineNo);
    end;

    /// <summary>
    /// Returns the source amount pool available for distribution.
    /// Priority:
    ///   1. Header Source Amount
    ///   2. Sum of Source Amount on lines
    ///   3. Fallback: header Total Amount
    /// </summary>
    local procedure GetSourceAmount(var RechargeHeader: Record "IC Recharge Request Header"): Decimal
    var
        ReqLine: Record "IC Recharge Request Line";
        LineSourceSum: Decimal;
    begin
        // Priority 1: Header Source Amount
        if RechargeHeader."Source Amount" <> 0 then
            exit(RechargeHeader."Source Amount");

        // Priority 2: Sum of Source Amount on lines
        ReqLine.SetRange("Request No.", RechargeHeader."No.");
        ReqLine.CalcSums("Source Amount");
        LineSourceSum := ReqLine."Source Amount";

        if LineSourceSum <> 0 then
            exit(LineSourceSum);

        // Fallback: return the header total (allocated amount)
        exit(RechargeHeader."Total Amount");
    end;

    /// <summary>Returns the standard monetary rounding precision (0.01).</summary>
    local procedure GetRoundingPrecision(): Decimal
    begin
        exit(0.01);
    end;

    /// <summary>Returns the tolerance for percentage totals (0.01 percentage points).</summary>
    local procedure GetPctTolerance(): Decimal
    begin
        exit(0.01);
    end;

    var
        TotalFixedExceedsSourceErr: Label 'The total of Fixed Amount lines (%1) exceeds the source amount (%2). Reduce the line amounts so they do not exceed the source amount.';
        PctAllocationNotBalancedErr: Label 'The sum of Allocation %% on Percentage lines is %1. Allocations must total 100%% before the request can be validated.';
        FixedAmtNotBalancedErr: Label 'The total of Fixed Amount lines (%1) does not equal the source amount (%2). Adjust the line amounts to balance before validating.';
        ActualCostExceedsSourceErr: Label 'The total of Actual Cost lines (%1) exceeds the source amount (%2).';
        RoundingAdjNoteMsg: Label 'Rounding adjustment applied: %1.';
        MissingExchangeRateErr: Label 'No exchange rate found for currency %1 on or before %2 (line %3). Define an exchange rate in the Currency Exchange Rates table before processing.';
        InvalidExchangeRateErr: Label 'The exchange rate for currency %1 on %2 (line %3) has a zero amount. Correct the exchange rate entry before processing.';
        UnmappedCurrencyErr: Label 'Currency code %1 on line %2 is not defined in the Currency table. Add the currency or correct the line before validating.';
}
