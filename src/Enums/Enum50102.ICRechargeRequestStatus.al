enum 50102 "IC Recharge Request Status"
{
    Caption = 'IC Recharge Request Status';
    Extensible = true;

    value(0; "Draft")
    {
        Caption = 'Draft';
    }
    value(1; "Validated")
    {
        Caption = 'Validated';
    }
    value(2; "Pending Approval")
    {
        Caption = 'Pending Approval';
    }
    value(3; "Approved")
    {
        Caption = 'Approved';
    }
    value(4; "Posted")
    {
        Caption = 'Posted';
    }
}
