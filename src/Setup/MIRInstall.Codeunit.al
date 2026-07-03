codeunit 50100 "MIR Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        InitializeNoSeriesData();
        InitializeSetup();
    end;

    local procedure InitializeNoSeriesData()
    begin
        InitializeNoSeries('MIR-REQ', 'Intercompany Recharge Requests', 'MIR-REQ-0001');
        InitializeNoSeries('MIR-PMAP', 'Intercompany Partner Mappings', 'MIR-PMAP-0001');
    end;

    local procedure InitializeSetup()
    var
        MIRSetup: Record "MIR Setup";
        SeriesChanged: Boolean;
    begin
        // Singleton: "Primary Key" Code[10] = ''. Get('') is the canonical lookup.
        if not MIRSetup.Get('') then begin
            MIRSetup.Init();
            MIRSetup."Primary Key" := '';
            MIRSetup."Recharge Request Nos." := 'MIR-REQ';
            MIRSetup."Partner Mapping Nos." := 'MIR-PMAP';
            MIRSetup."Auto-Send Flag" := false;
            MIRSetup."Auto-Accept Flag" := false;
            MIRSetup.Insert();
            exit;
        end;

        // Setup record already exists (re-install / upgrade). Only fill blanks —
        // never overwrite an admin-configured series code. Modify only when something changed.
        SeriesChanged := false;
        if MIRSetup."Recharge Request Nos." = '' then begin
            MIRSetup."Recharge Request Nos." := 'MIR-REQ';
            SeriesChanged := true;
        end;
        if MIRSetup."Partner Mapping Nos." = '' then begin
            MIRSetup."Partner Mapping Nos." := 'MIR-PMAP';
            SeriesChanged := true;
        end;
        if SeriesChanged then
            MIRSetup.Modify();
    end;

    local procedure InitializeNoSeries(SeriesCode: Code[20]; SeriesDescription: Text[100]; StartingNo: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        // Idempotent: only insert the No. Series header if it does not already exist.
        if not NoSeries.Get(SeriesCode) then begin
            NoSeries.Init();
            NoSeries.Code := SeriesCode;
            NoSeries.Description := SeriesDescription;
            NoSeries."Default Nos." := true;
            NoSeries."Manual Nos." := true;
            NoSeries.Insert();
        end;

        // Idempotent: only insert a Line for this series when no line exists yet.
        NoSeriesLine.Reset();
        NoSeriesLine.SetRange("Series Code", SeriesCode);
        if NoSeriesLine.IsEmpty() then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := SeriesCode;
            NoSeriesLine."Line No." := 10000;
            NoSeriesLine."Starting No." := StartingNo;
            NoSeriesLine."Increment-by No." := 1;
            NoSeriesLine.Insert();
        end;
    end;
}
