page 50105 "ICR Dim Mappings"
{
    Caption = 'ICR Dim Mappings';
    PageType = List;
    SourceTable = "ICR Dim Mapping";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = true;
    AboutTitle = 'ICR Dim Mappings';
    AboutText = 'Maintain dimension translation rules used when an intercompany recharge is generated. Every source Dimension Code/Value used on a recharge line must have a matching row here for the partner, otherwise posting is blocked.';

    layout
    {
        area(Content)
        {
            repeater(Mappings)
            {
                field("Partner Code"; Rec."Partner Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Intercompany Partner Mapping this dimension translation applies to. The value must exist in the ICR Partner Mappings list.';
                }
                field("Source Dim. Code"; Rec."Source Dim. Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Dimension Code used on the source recharge line. Together with Source Dim. Value it forms the key that is looked up during posting.';
                }
                field("Source Dim. Value"; Rec."Source Dim. Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Dimension Value used on the source recharge line. Together with Source Dim. Code it forms the key that is looked up during posting.';
                }
                field("Target Dim. Code"; Rec."Target Dim. Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Dimension Code that will be applied on the target partner side of the recharge. Set equal to Source Dim. Code when the Mapping Type is Same Code.';
                }
                field("Target Dim. Value"; Rec."Target Dim. Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Dimension Value that will be applied on the target partner side of the recharge.';
                }
                field("Mapping Type"; Rec."Mapping Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the target dimension is identical to the source (Same Code) or translated to a different Dimension Value (Map Value).';
                }
            }
        }
    }
}
