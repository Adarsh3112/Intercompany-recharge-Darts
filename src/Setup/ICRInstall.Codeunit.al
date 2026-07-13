codeunit 50101 "ICR Install"
{
    Subtype = Install;

    var
        ICRReqSeriesCodeTok: Label 'ICR-REQ', Locked = true;
        ICRReqSeriesDescLbl: Label 'Intercompany Recharge Requests';
        ICRReqStartingNoTok: Label 'REQ-0001', Locked = true;

    /// <summary>
    /// Runs once per company when the extension is installed or upgraded.
    /// Ensures the ICR Setup record and the ICR-REQ No. Series exist so that
    /// the extension is usable immediately after deployment.
    /// </summary>
    trigger OnInstallAppPerCompany()
    begin
        InitializeSetup();
        InitializeNoSeries(ICRReqSeriesCodeTok, ICRReqSeriesDescLbl, ICRReqStartingNoTok);
        AssignDefaultSeriesToSetup();
    end;

    /// <summary>
    /// Creates the single ICR Setup record if it does not yet exist.
    /// Guarded by Get so re-installation is safe (idempotent).
    /// </summary>
    local procedure InitializeSetup()
    var
        ICRSetup: Record "ICR Setup";
    begin
        if ICRSetup.Get() then
            exit;

        ICRSetup.Init();
        ICRSetup."Primary Key" := '';
        ICRSetup.Insert(true);
    end;

    /// <summary>
    /// Creates a No. Series header and a starting No. Series Line if they do
    /// not already exist. Guarded by Get on both records so the procedure is
    /// fully idempotent across re-installation and upgrade scenarios.
    /// </summary>
    local procedure InitializeNoSeries(SeriesCode: Code[20]; SeriesDescription: Text[100]; StartingNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if not NoSeries.Get(SeriesCode) then begin
            NoSeries.Init();
            NoSeries.Code := SeriesCode;
            NoSeries.Description := SeriesDescription;
            NoSeries."Default Nos." := true;
            NoSeries."Manual Nos." := false;
            NoSeries.Insert(true);
        end;

        NoSeriesLine.SetRange("Series Code", SeriesCode);
        if not NoSeriesLine.FindFirst() then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := SeriesCode;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := StartingNo;
            NoSeriesLine."Increment-by No." := 1;
            NoSeriesLine.Insert(true);
        end;
    end;

    /// <summary>
    /// Assigns the ICR-REQ series to ICR Setup."Recharge Request Nos." only when
    /// the field is currently blank, so a manually chosen series is preserved.
    /// </summary>
    local procedure AssignDefaultSeriesToSetup()
    var
        ICRSetup: Record "ICR Setup";
    begin
        if not ICRSetup.Get() then
            exit;

        if ICRSetup."Recharge Request Nos." <> '' then
            exit;

        ICRSetup."Recharge Request Nos." := ICRReqSeriesCodeTok;
        ICRSetup.Modify(true);
    end;
}
