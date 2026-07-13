permissionset 50102 "ICR Recharge Request"
{
    Assignable = true;
    Caption = 'ICR Recharge Request';

    Permissions =
        tabledata "ICR Recharge Request" = RIMD,
        table "ICR Recharge Request" = X,
        page "ICR Recharge Request" = X,
        tabledata "ICR Recharge Line" = RIMD,
        table "ICR Recharge Line" = X,
        page "ICR Recharge Lines" = X,
        tabledata "ICR Setup" = RIM,
        tabledata "ICR Dim Mapping" = RIMD,
        table "ICR Dim Mapping" = X,
        page "ICR Dim Mappings" = X,
        codeunit "ICR Management" = X,
        codeunit "Workflow Management" = X,
        codeunit "Approvals Mgmt." = X,
        codeunit "ICR Approval Workflow" = X,
        codeunit "ICR Batch Processor" = X,
        tabledata "Approval Entry" = R,
        tabledata "ICR Reconciliation Buffer" = RIMD,
        table "ICR Reconciliation Buffer" = X,
        page "ICR Reconciliation Result" = X,
        report "ICR Reconciliation" = X,
        tabledata "ICR Audit Log" = RI,
        table "ICR Audit Log" = X,
        page "ICR Audit Logs" = X;
}
