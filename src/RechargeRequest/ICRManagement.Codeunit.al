codeunit 50100 "ICR Management"
{
    var
        ExceedsErr: Label 'Recharge Request %1: Total allocated %2 exceeds source amount %3. Adjust the recharge lines so that the total allocated amount does not exceed the source Total Amount.', Comment = '%1 = Document No., %2 = Sum of Allocated Amount, %3 = Header Total Amount';
        PercentageNot100Err: Label 'Recharge Request %1: Allocation percentages must sum to 100 but sum to %2. Adjust the recharge lines so that the Allocation %% column totals exactly 100.', Comment = '%1 = Document No., %2 = Sum of Allocation %';
        AmountNotTotalErr: Label 'Recharge Request %1: Allocated amounts must sum to %2 but sum to %3. Adjust the recharge lines so that the Allocated Amount column totals the header Total Amount.', Comment = '%1 = Document No., %2 = Header Total Amount, %3 = Sum of Allocated Amount';
        UnmappedDimensionErr: Label 'Recharge Request %1, line %2: no ICR Dim Mapping exists for partner %3 with Source Dim. Code %4 and Source Dim. Value %5. Add the mapping on the ICR Dim Mappings page before posting.', Comment = '%1 = Document No., %2 = Line No., %3 = Partner Code, %4 = Source Dim. Code, %5 = Source Dim. Value';
        MissingPartnerErr: Label 'Recharge Request %1, line %2: the Target Partner field is blank. Dimension mapping validation requires every recharge line to reference a partner.', Comment = '%1 = Document No., %2 = Line No.';
        AlreadyPostedErr: Label 'Recharge Request %1 has already been posted (Status = Posted) and cannot be posted again. Use the reversal flow to correct a posted request.', Comment = '%1 = Document No.';
        NotApprovedErr: Label 'Recharge Request %1 cannot be posted because its current Status is %2. Only Approved requests may be posted. Send the request for approval first.', Comment = '%1 = Document No., %2 = Status';
        AuditPostedLbl: Label 'Recharge Request posted (transitioned from Approved to Posted). Total Amount: %1 %2.', Comment = '%1 = Total Amount, %2 = Currency Code';

    /// <summary>
    /// Sums the Allocated Amount of every ICR Recharge Line that belongs to the
    /// supplied Recharge Request header and blocks the calculation when the
    /// summed value exceeds the header's Total Amount. Per-line traceability is
    /// preserved because the filter is (Document No. = Header."No.") and each
    /// line's own primary key and amounts remain untouched.
    /// </summary>
    procedure CalculateAllocations(var Header: Record "ICR Recharge Request")
    var
        Line: Record "ICR Recharge Line";
    begin
        Line.SetRange("Document No.", Header."No.");
        Line.CalcSums("Allocated Amount");
        if Line."Allocated Amount" > Header."Total Amount" then
            Error(ExceedsErr, Header."No.", Line."Allocated Amount", Header."Total Amount");
    end;

    /// <summary>
    /// Validates that the recharge lines belonging to the supplied header
    /// balance to the value dictated by the header's Allocation Basis:
    ///   * Fixed Percentage → sum of Allocation % must equal 100
    ///   * Amount-Based    → sum of Allocated Amount must equal Total Amount
    /// Dimension-Driven and Headcount are validated using the same
    /// Allocated Amount = Total Amount rule as Amount-Based.
    /// </summary>
    procedure CheckBalancing(var Header: Record "ICR Recharge Request")
    var
        Line: Record "ICR Recharge Line";
    begin
        Line.SetRange("Document No.", Header."No.");
        case Header."Allocation Basis" of
            Header."Allocation Basis"::"Fixed Percentage":
                begin
                    Line.CalcSums("Allocation %");
                    if Line."Allocation %" <> 100 then
                        Error(PercentageNot100Err, Header."No.", Line."Allocation %");
                end;
            Header."Allocation Basis"::"Amount-Based",
            Header."Allocation Basis"::"Dimension-Driven",
            Header."Allocation Basis"::Headcount:
                begin
                    Line.CalcSums("Allocated Amount");
                    if Line."Allocated Amount" <> Header."Total Amount" then
                        Error(AmountNotTotalErr, Header."No.", Header."Total Amount", Line."Allocated Amount");
                end;
        end;
    end;

    /// <summary>
    /// Validates that every dimension carried on the supplied Recharge Request
    /// header (via the standard Dimension Set ID on the header) has a
    /// corresponding ICR Dim Mapping row for each recharge line's Target
    /// Partner. Called as part of the posting sequence so that unmapped
    /// dimensions block the posting attempt with an actionable error naming
    /// the document, the line, the partner and the offending Dimension
    /// Code/Value pair.
    ///
    /// The validation walks every line, loads the source dimensions from the
    /// header's Dimension Set (or the line's Dimension Set if that field is
    /// added in a later task), and for each Dimension Code / Dimension Value
    /// combination calls the FindMapping procedure on the ICR Dim Mapping
    /// table. When no mapping is found the posting is stopped immediately.
    ///
    /// Behaviour:
    ///   * A line with a blank Target Partner is rejected (MissingPartnerErr)
    ///     because dimension mappings are keyed by Partner Code.
    ///   * A missing ICR Dim Mapping row raises UnmappedDimensionErr naming
    ///     the document, line, partner, source dimension code and value.
    ///   * If the header carries no dimensions at all the validation is a
    ///     silent no-op.
    /// </summary>
    procedure ValidateDimensionMappings(var Header: Record "ICR Recharge Request")
    var
        Line: Record "ICR Recharge Line";
        DimSetEntry: Record "Dimension Set Entry";
        HeaderRecRef: RecordRef;
        DimSetIDFieldRef: FieldRef;
        DimSetID: Integer;
    begin
        // Read the header's Dimension Set ID via a RecordRef so this codeunit
        // does not force the header table to expose a strongly-typed field
        // reference. When the field is absent (older builds) or its value is
        // 0 there are no dimensions to validate.
        HeaderRecRef.GetTable(Header);
        if not TryGetDimSetIDField(HeaderRecRef, DimSetIDFieldRef) then
            exit;
        DimSetID := DimSetIDFieldRef.Value();
        if DimSetID = 0 then
            exit;

        Line.SetRange("Document No.", Header."No.");
        if not Line.FindSet() then
            exit;

        repeat
            if Line."Target Partner" = '' then
                Error(MissingPartnerErr, Header."No.", Line."Line No.");

            DimSetEntry.Reset();
            DimSetEntry.SetRange("Dimension Set ID", DimSetID);
            if DimSetEntry.FindSet() then
                repeat
                    CheckDimMapping(Header."No.", Line."Line No.", Line."Target Partner",
                        DimSetEntry."Dimension Code", DimSetEntry."Dimension Value Code");
                until DimSetEntry.Next() = 0;
        until Line.Next() = 0;
    end;

    /// <summary>
    /// Attempts to fetch the standard 'Dimension Set ID' Integer field from
    /// the supplied RecordRef. Returns TRUE and populates DimSetIDFieldRef on
    /// success, FALSE when the header table does not expose the field.
    /// </summary>
    local procedure TryGetDimSetIDField(var HeaderRecRef: RecordRef; var DimSetIDFieldRef: FieldRef): Boolean
    var
        FieldRec: Record "Field";
    begin
        FieldRec.SetRange(TableNo, HeaderRecRef.Number());
        FieldRec.SetRange(FieldName, 'Dimension Set ID');
        if not FieldRec.FindFirst() then
            exit(false);
        DimSetIDFieldRef := HeaderRecRef.Field(FieldRec."No.");
        exit(true);
    end;

    /// <summary>
    /// Delegates the actual lookup to the FindMapping procedure on the
    /// ICR Dim Mapping table. Raises UnmappedDimensionErr when no row exists
    /// for the (Partner Code, Source Dim. Code, Source Dim. Value) key.
    /// </summary>
    local procedure CheckDimMapping(DocNo: Code[20]; LineNo: Integer; PartnerCode: Code[20]; SourceDimCode: Code[20]; SourceDimValue: Code[20])
    var
        DimMapping: Record "ICR Dim Mapping";
    begin
        if not DimMapping.FindMapping(PartnerCode, SourceDimCode, SourceDimValue) then
            Error(UnmappedDimensionErr, DocNo, LineNo, PartnerCode, SourceDimCode, SourceDimValue);
    end;

    /// <summary>
    /// Writes a single immutable entry to the 'ICR Audit Log' table capturing
    /// a significant action performed on an ICR Recharge Request. Callers pass
    /// a short Action code (for example CREATED, SUBMITTED, CANCELLED,
    /// APPROVED, ACTIVATED, POSTED, REVERSED, STATUS-CHANGED), the document
    /// number the action applies to and a human-readable description.
    ///
    /// The procedure is defensive:
    ///   * A blank DocumentNo is a no-op — audit rows without a document key
    ///     have no downstream value.
    ///   * The Entry No. is auto-incremented by the platform (the field is
    ///     declared AutoIncrement = true), so callers never assign it.
    ///   * UserId is captured from the running session so the log always
    ///     reflects the actual actor even if the caller forgot to set it.
    ///   * CurrentDateTime is used for the Timestamp so the log reflects the
    ///     server-side wall clock, not any client-side value.
    ///
    /// Because the target table's OnModify and OnDelete triggers raise a
    /// hard error, callers cannot subsequently mutate the row — the audit
    /// history is guaranteed immutable at the platform layer.
    /// </summary>
    procedure LogAction(ActionCode: Text[50]; DocumentNo: Code[20]; ActionDescription: Text[250])
    var
        AuditLog: Record "ICR Audit Log";
    begin
        if DocumentNo = '' then
            exit;

        AuditLog.Init();
        AuditLog."User ID" := CopyStr(UserId(), 1, MaxStrLen(AuditLog."User ID"));
        AuditLog."Action" := ActionCode;
        AuditLog."Document No." := DocumentNo;
        AuditLog."Action Timestamp" := CurrentDateTime();
        AuditLog."Description" := ActionDescription;
        AuditLog.Insert(false);
    end;

    /// <summary>
    /// Posts a Recharge Request by transitioning it from Approved to Posted.
    /// This is the single entry point that the Batch Processor, the page
    /// action, and automated tests use — so the duplicate-posting guard is
    /// enforced uniformly no matter how the posting is triggered.
    ///
    /// Guards, in order:
    ///   1. If Status = Posted the caller is attempting to post the same
    ///      document twice. Raise AlreadyPostedErr with the document number
    ///      so the operator can locate the record and use the reversal flow
    ///      instead of double-posting.
    ///   2. If Status is anything other than Approved, reject with a message
    ///      that names both the document and its current status. This blocks
    ///      Draft, Pending Approval, Rejected, Reversed and Closed requests
    ///      from being posted directly.
    ///   3. Re-validate allocation balancing via CalculateAllocations so that
    ///      a request whose lines were tampered with between approval and
    ///      posting cannot be posted with an over-allocated total.
    ///
    /// On success the header's Status is flipped to Posted, the record is
    /// persisted with Modify(true) so table triggers fire, and an immutable
    /// audit-log entry captures the event.
    /// </summary>
    procedure PostRequest(var Header: Record "ICR Recharge Request")
    begin
        // Guard 1: duplicate posting. This must be the FIRST check so that
        // an attempt to re-post a Posted document always fails fast with a
        // message that names the document number — regardless of whether
        // the caller has also tampered with the recharge lines.
        if Header.Status = Header.Status::Posted then
            Error(AlreadyPostedErr, Header."No.");

        // Guard 2: only Approved requests may be posted directly. The Batch
        // Processor filters for Approved before calling in, but manual
        // page actions or tests could reach this codeunit with any status.
        if Header.Status <> Header.Status::Approved then
            Error(NotApprovedErr, Header."No.", Format(Header.Status));

        // Guard 3: re-run the over-allocation check so a tampered request
        // cannot slip through between approval and posting.
        CalculateAllocations(Header);

        // Transition and persist.
        Header.Status := Header.Status::Posted;
        Header.Modify(true);

        // Immutable audit trail.
        LogAction('POSTED', Header."No.",
            CopyStr(StrSubstNo(AuditPostedLbl, Header."Total Amount", Header."Currency Code"), 1, 250));
    end;
}
