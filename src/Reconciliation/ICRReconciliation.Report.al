/// <summary>
/// 'ICR Reconciliation' report.
///
/// Compares three views of the same intercompany recharge activity so a
/// finance user can spot unreconciled allocations at a glance:
///   * Source amounts    — taken from each Recharge Request header (the
///                         source ledger entry / total to be recharged).
///   * Allocation totals — summed from ICR Recharge Line per Target Partner.
///   * Posted amounts    — summed from ICR Recharge Line rows flagged Posted
///                         (the intercompany entries actually written to the
///                         G/L / IC Outbox by the posting logic).
///
/// The request page exposes filters for Company (Source Company), Partner
/// (Target Partner on the lines), Period (Period From / Period To against a
/// posting date proxy — the request's No. Series is date-driven, so the
/// filter targets the header's rolling document date field via the standard
/// Dimension Set / creation timeline; in this MVP the period filter is
/// applied against the header's status timeline captured in the filter
/// group), and Status (Recharge Request lifecycle status OR reconciliation
/// classification).
///
/// Technical hint: results are aggregated into a temporary table
/// (ICR Reconciliation Buffer) at run time and displayed via the
/// ICR Reconciliation Result list page. Processing = true, so no RDLC
/// layout is required — the user sees the buffer directly.
/// </summary>
report 50100 "ICR Reconciliation"
{
    Caption = 'ICR Reconciliation';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    ProcessingOnly = true;

    dataset
    {
        dataitem(RechargeRequest; "ICR Recharge Request")
        {
            DataItemTableView = sorting("No.");
            RequestFilterFields = "Source Company", "Recharge Type", "Status";

            trigger OnPreDataItem()
            begin
                // Reset the temporary buffer for a fresh run and re-apply the
                // header-level filters chosen on the request page.
                ReconBuffer.Reset();
                ReconBuffer.DeleteAll();
                NextEntryNo := 0;

                if CompanyFilter <> '' then
                    RechargeRequest.SetFilter("Source Company", CompanyFilter);
                if RechargeTypeFilter <> '' then
                    RechargeRequest.SetFilter("Recharge Type", RechargeTypeFilter);
                if RequestStatusFilter <> '' then
                    RechargeRequest.SetFilter("Status", RequestStatusFilter);
            end;

            trigger OnAfterGetRecord()
            begin
                AggregatePartners(RechargeRequest);
            end;

            trigger OnPostDataItem()
            begin
                ApplyReconciliationStatusFilter();
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(Content)
            {
                group(Filters)
                {
                    Caption = 'Filters';

                    field(CompanyFilterCtl; CompanyFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Company';
                        ToolTip = 'Specifies the Source Company filter. Enter a company name or leave blank to include every source company.';
                    }
                    field(PartnerFilterCtl; PartnerFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Partner';
                        ToolTip = 'Specifies the Target Partner filter used against the recharge lines. Enter a partner code or leave blank to include every partner.';
                        TableRelation = "IC Partner";
                    }
                    field(PeriodFromCtl; PeriodFrom)
                    {
                        ApplicationArea = All;
                        Caption = 'Period From';
                        ToolTip = 'Specifies the first date of the reconciliation period. Rows whose Recharge Request falls before this date are excluded.';
                    }
                    field(PeriodToCtl; PeriodTo)
                    {
                        ApplicationArea = All;
                        Caption = 'Period To';
                        ToolTip = 'Specifies the last date of the reconciliation period. Rows whose Recharge Request falls after this date are excluded.';
                    }
                    field(RequestStatusFilterCtl; RequestStatusFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Request Status Filter';
                        ToolTip = 'Specifies a filter expression applied to the Recharge Request Status field, for example ''Posted|Approved''.';
                    }
                    field(ReconStatusCtl; ReconStatusFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Status';
                        ToolTip = 'Specifies the reconciliation classification filter shown in the result page: All, Balanced, Unbalanced, Posted, or Unposted.';
                    }
                    field(RechargeTypeCtl; RechargeTypeFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Recharge Type';
                        ToolTip = 'Specifies an optional Recharge Type filter applied to the Recharge Request header.';
                    }
                }
            }
        }
    }

    trigger OnPostReport()
    var
        ResultPage: Page "ICR Reconciliation Result";
    begin
        // Present the aggregated buffer through the result list page.
        // The page is bound to a temporary source table, so we transfer the
        // in-memory rows via SetTableView / SetRecord and invoke RunModal.
        if ReconBuffer.IsEmpty() then
            exit;

        ReconBuffer.Reset();
        ReconBuffer.SetCurrentKey("Entry No.");
        ResultPage.SetSourceRecords(ReconBuffer);
        ResultPage.RunModal();
    end;

    var
        ReconBuffer: Record "ICR Reconciliation Buffer" temporary;
        NextEntryNo: Integer;
        CompanyFilter: Text[250];
        PartnerFilter: Code[20];
        PeriodFrom: Date;
        PeriodTo: Date;
        RequestStatusFilter: Text[250];
        ReconStatusFilter: Enum "ICR Reconciliation Status";
        RechargeTypeFilter: Text[250];

    /// <summary>
    /// Walks the recharge lines that belong to the supplied header, groups
    /// them by Target Partner, and inserts one buffer row per partner
    /// containing the source share, the allocation total and the posted
    /// total. Applies the Partner and Period filters from the request page.
    /// </summary>
    local procedure AggregatePartners(var Header: Record "ICR Recharge Request")
    var
        LineIter: Record "ICR Recharge Line";
        PartnerLines: Record "ICR Recharge Line";
        PostedLines: Record "ICR Recharge Line";
        SeenPartner: Text;
        PartnerList: Text;
        Separator: Char;
    begin
        // Skip requests that fall outside the period filter. The period is
        // matched against SystemCreatedAt because the header does not have
        // an explicit posting date column in this MVP — SystemCreatedAt is a
        // guaranteed BC-provided timestamp on every record.
        if not RequestInPeriod(Header) then
            exit;

        LineIter.Reset();
        LineIter.SetRange("Document No.", Header."No.");
        if PartnerFilter <> '' then
            LineIter.SetRange("Target Partner", PartnerFilter);
        if not LineIter.FindSet() then
            exit;

        // Build a de-duplicated partner list using a delimited text — the
        // recharge line table is small per document so a linear scan is
        // both fast and dependency-free.
        Separator := '|';
        PartnerList := '';

        repeat
            SeenPartner := Format(Separator) + LineIter."Target Partner" + Format(Separator);
            if StrPos(PartnerList, SeenPartner) = 0 then begin
                PartnerList += SeenPartner;

                // Sum allocated amount for this partner on this document.
                PartnerLines.Reset();
                PartnerLines.SetRange("Document No.", Header."No.");
                PartnerLines.SetRange("Target Partner", LineIter."Target Partner");
                PartnerLines.CalcSums("Allocated Amount");

                // Sum posted amount for this partner (Posted = true).
                PostedLines.Reset();
                PostedLines.SetRange("Document No.", Header."No.");
                PostedLines.SetRange("Target Partner", LineIter."Target Partner");
                PostedLines.SetRange("Posted", true);
                PostedLines.CalcSums("Allocated Amount");

                InsertBufferRow(Header,
                    LineIter."Target Partner",
                    Header."Total Amount",
                    PartnerLines."Allocated Amount",
                    PostedLines."Allocated Amount");
            end;
        until LineIter.Next() = 0;
    end;

    /// <summary>
    /// Inserts one buffer row and classifies it using ClassifyStatus so the
    /// Reconciliation Status column is populated consistently.
    /// </summary>
    local procedure InsertBufferRow(var Header: Record "ICR Recharge Request"; PartnerCode: Code[20]; SourceAmount: Decimal; AllocatedAmount: Decimal; PostedAmount: Decimal)
    begin
        NextEntryNo += 1;

        ReconBuffer.Init();
        ReconBuffer."Entry No." := NextEntryNo;
        ReconBuffer."Source Company" := Header."Source Company";
        ReconBuffer."Recharge Request No." := Header."No.";
        ReconBuffer."Recharge Type" := Header."Recharge Type";
        ReconBuffer."Target Partner" := PartnerCode;
        ReconBuffer."Period Start" := PeriodFrom;
        ReconBuffer."Period End" := PeriodTo;
        ReconBuffer."Request Status" := Header."Status";
        ReconBuffer."Source Amount" := SourceAmount;
        ReconBuffer."Allocated Amount" := AllocatedAmount;
        ReconBuffer."Posted Amount" := PostedAmount;
        ReconBuffer."Currency Code" := Header."Currency Code";
        ReconBuffer.ClassifyStatus();
        ReconBuffer.Insert();
    end;

    /// <summary>
    /// Returns TRUE when the supplied Recharge Request falls inside the
    /// Period From / Period To window. Blank period filters mean "no bound".
    /// </summary>
    local procedure RequestInPeriod(var Header: Record "ICR Recharge Request"): Boolean
    var
        HeaderDate: Date;
    begin
        if (PeriodFrom = 0D) and (PeriodTo = 0D) then
            exit(true);

        HeaderDate := DT2Date(Header.SystemCreatedAt);
        if HeaderDate = 0D then
            HeaderDate := WorkDate();

        if (PeriodFrom <> 0D) and (HeaderDate < PeriodFrom) then
            exit(false);
        if (PeriodTo <> 0D) and (HeaderDate > PeriodTo) then
            exit(false);

        exit(true);
    end;

    /// <summary>
    /// Applies the request page's Reconciliation Status filter after all rows
    /// have been aggregated. When the filter is 'All' every row survives;
    /// otherwise rows that do not match the selected classification are
    /// removed from the temporary buffer.
    /// </summary>
    local procedure ApplyReconciliationStatusFilter()
    begin
        if ReconStatusFilter = ReconStatusFilter::All then
            exit;

        ReconBuffer.Reset();
        ReconBuffer.SetFilter("Reconciliation Status", '<>%1', ReconStatusFilter);
        if not ReconBuffer.IsEmpty() then
            ReconBuffer.DeleteAll();

        // Restore an unfiltered view for the result page.
        ReconBuffer.Reset();
    end;
}
