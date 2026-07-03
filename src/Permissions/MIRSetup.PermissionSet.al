permissionset 50100 "MIR Setup Admin"
{
    Assignable = true;
    Caption = 'MIR Setup Admin';

    Permissions =
        tabledata "MIR Setup" = RIMD,
        tabledata "MIR Partner Mapping" = RIMD,
        tabledata "MIR GL Mapping" = RIMD,
        tabledata "MIR Recharge Header" = RIMD,
        tabledata "MIR Recharge Line" = RIMD,
        tabledata "MIR Recharge Ledger Entry" = RIMD,
        table "MIR Setup" = X,
        table "MIR Partner Mapping" = X,
        table "MIR GL Mapping" = X,
        table "MIR Recharge Header" = X,
        table "MIR Recharge Line" = X,
        table "MIR Recharge Ledger Entry" = X,
        page "MIR Setup" = X,
        page "MIR Partner Mapping List" = X,
        page "MIR GL Mapping List" = X,
        page "MIR Recharge Header List" = X,
        page "MIR Recharge Header Card" = X,
        page "MIR Recharge Line Subform" = X,
        page "MIR Recharge Ledger Entries" = X,
        codeunit "MIR Install" = X,
        codeunit "MIR Recharge Status Mgt" = X,
        codeunit "MIR Allocation Engine" = X,
        codeunit "MIR Posting Management" = X;
}
