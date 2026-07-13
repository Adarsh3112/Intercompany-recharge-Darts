permissionset 50105 "ICR Finance"
{
    Assignable = true;
    Caption = 'ICR Finance - Posting Rights';

    Permissions =
        tabledata "ICR Recharge Request" = RIM,
        table "ICR Recharge Request" = X,
        page "ICR Recharge Request" = X,
        tabledata "ICR Recharge Line" = RIM,
        table "ICR Recharge Line" = X,
        page "ICR Recharge Lines" = X,
        tabledata "ICR Setup" = R,
        page "ICR Setup" = X,
        tabledata "ICR Partner Mapping" = R,
        table "ICR Partner Mapping" = X,
        page "ICR Partner Mappings" = X,
        tabledata "ICR Dim Mapping" = R,
        table "ICR Dim Mapping" = X,
        page "ICR Dim Mappings" = X,
        tabledata "ICR Reconciliation Buffer" = RIM,
        table "ICR Reconciliation Buffer" = X,
        page "ICR Reconciliation Result" = X,
        report "ICR Reconciliation" = X,
        tabledata "ICR Audit Log" = RI,
        table "ICR Audit Log" = X,
        page "ICR Audit Logs" = X,
        codeunit "ICR Management" = X,
        codeunit "ICR Batch Processor" = X,
        tabledata "Approval Entry" = R;
}
