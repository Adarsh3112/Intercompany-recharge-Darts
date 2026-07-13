permissionset 50106 "ICR Admin"
{
    Assignable = true;
    Caption = 'ICR Administrator - Full Setup Access';

    Permissions =
        tabledata "ICR Setup" = RIMD,
        table "ICR Setup" = X,
        page "ICR Setup" = X,
        tabledata "ICR Recharge Request" = RIMD,
        table "ICR Recharge Request" = X,
        page "ICR Recharge Request" = X,
        tabledata "ICR Recharge Line" = RIMD,
        table "ICR Recharge Line" = X,
        page "ICR Recharge Lines" = X,
        tabledata "ICR Partner Mapping" = RIMD,
        table "ICR Partner Mapping" = X,
        page "ICR Partner Mappings" = X,
        tabledata "ICR Dim Mapping" = RIMD,
        table "ICR Dim Mapping" = X,
        page "ICR Dim Mappings" = X,
        tabledata "ICR Reconciliation Buffer" = RIMD,
        table "ICR Reconciliation Buffer" = X,
        page "ICR Reconciliation Result" = X,
        report "ICR Reconciliation" = X,
        tabledata "ICR Audit Log" = RIMD,
        table "ICR Audit Log" = X,
        page "ICR Audit Logs" = X,
        codeunit "ICR Install" = X,
        codeunit "ICR Management" = X,
        codeunit "ICR Approval Workflow" = X,
        codeunit "ICR Batch Processor" = X,
        codeunit "ICR Recharge Request Tests" = X,
        codeunit "Workflow Management" = X,
        codeunit "Approvals Mgmt." = X,
        tabledata "Approval Entry" = RIMD;
}
