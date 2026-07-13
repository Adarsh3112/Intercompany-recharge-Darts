permissionset 50107 "ICR Auditor"
{
    Assignable = true;
    Caption = 'ICR Auditor - Read Only';

    Permissions =
        tabledata "ICR Setup" = R,
        page "ICR Setup" = X,
        tabledata "ICR Recharge Request" = R,
        table "ICR Recharge Request" = X,
        page "ICR Recharge Request" = X,
        tabledata "ICR Recharge Line" = R,
        table "ICR Recharge Line" = X,
        page "ICR Recharge Lines" = X,
        tabledata "ICR Partner Mapping" = R,
        table "ICR Partner Mapping" = X,
        page "ICR Partner Mappings" = X,
        tabledata "ICR Dim Mapping" = R,
        table "ICR Dim Mapping" = X,
        page "ICR Dim Mappings" = X,
        tabledata "ICR Reconciliation Buffer" = R,
        table "ICR Reconciliation Buffer" = X,
        page "ICR Reconciliation Result" = X,
        report "ICR Reconciliation" = X,
        tabledata "ICR Audit Log" = R,
        table "ICR Audit Log" = X,
        page "ICR Audit Logs" = X,
        tabledata "Approval Entry" = R;
}
