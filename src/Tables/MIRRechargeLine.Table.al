table 50104 "MIR Recharge Line"
{
    Caption = 'MIR Recharge Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
            // FK to the parent header — the subform's SubPageLink will fill this in
            // automatically. The relation is what makes the line "linked to the Header".
            TableRelation = "MIR Recharge Header"."No.";
            NotBlank = true;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Target Partner"; Code[20])
        {
            Caption = 'Target Partner';
            DataClassification = CustomerContent;
            TableRelation = "IC Partner".Code;

            trigger OnValidate()
            begin
                // Default the Target IC GL account from the partner-level GL mapping when
                // a single mapping uniquely identifies the target account. The user can
                // still override afterwards.
                if (Rec."Target Partner" <> '') and (Rec."Target IC GL Acc." = '') then
                    SuggestTargetICGLAccount();
            end;
        }
        field(4; "Allocation Basis"; Enum "MIR Allocation Basis")
        {
            Caption = 'Allocation Basis';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                // Re-run the calculation whenever the basis changes so the displayed
                // Calculated Amount stays in sync with the basis/value pair.
                RecalculateCalculatedAmount();
            end;
        }
        field(5; "Allocation Value"; Decimal)
        {
            Caption = 'Allocation Value';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
            MinValue = 0;

            trigger OnValidate()
            begin
                // Spec: compute Calculated Amount in the OnValidate of Allocation Value
                // using the Header's Source Amount as the basis for Fixed % allocations.
                RecalculateCalculatedAmount();
            end;
        }
        field(6; "Calculated Amount"; Decimal)
        {
            Caption = 'Calculated Amount';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            Editable = false;
        }
        field(7; "Target IC GL Acc."; Code[20])
        {
            Caption = 'Target IC GL Acc.';
            DataClassification = CustomerContent;
            TableRelation = "IC G/L Account"."No.";
        }
        field(8; "Allocation Trace"; Text[250])
        {
            Caption = 'Allocation Trace';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Document No.", "Line No.")
        {
            Clustered = true;
        }
        key(TargetPartner; "Target Partner")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Document No.", "Line No.", "Target Partner", "Calculated Amount")
        {
        }
        fieldgroup(Brick; "Document No.", "Line No.", "Target Partner", "Allocation Basis", "Allocation Value", "Calculated Amount")
        {
        }
    }

    trigger OnInsert()
    var
        Header: Record "MIR Recharge Header";
    begin
        // Lines can only attach to a Draft header. Once the header leaves Draft, allocation
        // structure is frozen along with the rest of the document.
        if Header.Get(Rec."Document No.") then
            if Header.Status <> Header.Status::Draft then
                Error('Cannot add lines to MIR Recharge Header %1 because its status is %2. Only Draft documents accept new lines.', Header."No.", Header.Status);

        // Auto-assign Line No. as a 10000-step increment over the largest existing line
        // for this document (standard BC document-line idiom).
        if Rec."Line No." = 0 then
            Rec."Line No." := GetNextLineNo();

        // If the user already filled Allocation Basis/Value at insert time, compute the
        // Calculated Amount now so the inserted record is internally consistent.
        if Rec."Allocation Value" <> 0 then
            RecalculateCalculatedAmount();
    end;

    trigger OnModify()
    var
        Header: Record "MIR Recharge Header";
    begin
        // Field-locking parallel to the Header: once the parent leaves Draft, lines are
        // frozen too. This protects allocation history when the document is Posted/Reversed.
        if Header.Get(Rec."Document No.") then
            if Header.Status <> Header.Status::Draft then
                Error('Cannot modify lines on MIR Recharge Header %1 because its status is %2. Only Draft documents may be edited.', Header."No.", Header.Status);
    end;

    trigger OnDelete()
    var
        Header: Record "MIR Recharge Header";
    begin
        // Line deletion is governed by the same field-lock policy as OnModify: once the
        // parent header leaves Draft, the allocation structure is frozen. Allowing a delete
        // on a Validated/Approved/Pending Approval header would silently invalidate the
        // allocation totals that were stamped at SetValidated time.
        if Header.Get(Rec."Document No.") then
            if Header.Status <> Header.Status::Draft then
                Error('Cannot delete lines on MIR Recharge Header %1 because its status is %2. Only Draft documents may have lines removed.', Header."No.", Header.Status);
    end;

    local procedure GetNextLineNo(): Integer
    var
        ExistingLine: Record "MIR Recharge Line";
    begin
        ExistingLine.SetRange("Document No.", Rec."Document No.");
        if ExistingLine.FindLast() then
            exit(ExistingLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure RecalculateCalculatedAmount()
    var
        Header: Record "MIR Recharge Header";
        SourceAmount: Decimal;
    begin
        // The Calculated Amount is derived from the Header's Source Amount for the
        // percentage-based basis, and equals the entered value for amount-based bases.
        // Dimension and Headcount fall back to the entered value as a sensible default
        // for the MVP — the downstream allocation engine refines these from real drivers.
        if Rec."Document No." = '' then begin
            Rec."Calculated Amount" := 0;
            exit;
        end;

        if not Header.Get(Rec."Document No.") then begin
            Rec."Calculated Amount" := 0;
            exit;
        end;

        // Source Amount is a normal field (not a FlowField), so Header.Get already loaded it.
        // No CalcFields call is needed here.
        SourceAmount := Header."Source Amount";

        case Rec."Allocation Basis" of
            Rec."Allocation Basis"::"Fixed %":
                // Percentage of the header's source amount, rounded to 2 decimals.
                Rec."Calculated Amount" := Round(SourceAmount * Rec."Allocation Value" / 100, 0.01);
            Rec."Allocation Basis"::Amount:
                // The user-entered value IS the calculated amount.
                Rec."Calculated Amount" := Round(Rec."Allocation Value", 0.01);
            Rec."Allocation Basis"::Dimension,
            Rec."Allocation Basis"::Headcount:
                // MVP fallback: treat the entered value as the calculated amount.
                // Production engine will replace with real driver-based allocation.
                Rec."Calculated Amount" := Round(Rec."Allocation Value", 0.01);
        end;
    end;

    local procedure SuggestTargetICGLAccount()
    var
        GLMapping: Record "MIR GL Mapping";
    begin
        // If exactly one MIR GL Mapping exists for the chosen partner and it has a
        // Target IC GL Acc. defined, surface it as a sensible default. Multiple mappings
        // means the user must choose explicitly, so we leave the field blank in that case.
        GLMapping.SetRange("Partner Code", Rec."Target Partner");
        GLMapping.SetFilter("Target IC GL Acc.", '<>%1', '');
        if GLMapping.Count() = 1 then begin
            GLMapping.FindFirst();
            Rec."Target IC GL Acc." := GLMapping."Target IC GL Acc.";
        end;
    end;
}
