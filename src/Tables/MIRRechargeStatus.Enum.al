enum 50101 "MIR Recharge Status"
{
    Extensible = true;
    Caption = 'MIR Recharge Status';

    value(0; Draft)
    {
        Caption = 'Draft';
    }
    value(1; Validated)
    {
        Caption = 'Validated';
    }
    value(2; "Pending Approval")
    {
        Caption = 'Pending Approval';
    }
    value(3; Approved)
    {
        Caption = 'Approved';
    }
    value(4; Rejected)
    {
        Caption = 'Rejected';
    }
    value(5; Posted)
    {
        Caption = 'Posted';
    }
    value(6; Reversed)
    {
        Caption = 'Reversed';
    }
    value(7; Closed)
    {
        Caption = 'Closed';
    }
}
