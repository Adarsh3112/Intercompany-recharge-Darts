enum 50104 "ICR Dim Mapping Type"
{
    Extensible = true;
    Caption = 'ICR Dim Mapping Type';

    /// <summary>
    /// Same Code: the target dimension uses the same Dimension Code and
    /// Dimension Value as the source (no translation applied).
    /// </summary>
    value(0; "Same Code")
    {
        Caption = 'Same Code';
    }
    /// <summary>
    /// Map Value: the source Dimension Code/Value is translated to a
    /// possibly different target Dimension Code/Value as defined by the
    /// mapping row.
    /// </summary>
    value(1; "Map Value")
    {
        Caption = 'Map Value';
    }
}
