table 50103 "IC Recharge Request Line"
{
    Caption = 'IC Recharge Request Line';
    DataClassification = CustomerContent;
    TableType = Normal;

    fields
    {
        field(1; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            DataClassification = CustomerContent;
            NotBlank = true;
            TableRelation = "IC Recharge Request Header"."No.";

            trigger OnValidate()
            begin
                if "Request No." <> '' then begin
                    RechargeHeader.Get("Request No.");
                    RechargeHeader.TestStatusIsDraft();
                end;
            end;
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "IC Partner Code"; Code[20])
        {
            Caption = 'IC Partner Code';
            DataClassification = CustomerContent;
            TableRelation = "IC Recharge Partner"."IC Partner Code";

            trigger OnValidate()
            begin
                if "IC Partner Code" <> '' then begin
                    ICRechargePartner.Get("IC Partner Code");
                    "IC Partner Name" := ICRechargePartner."IC Partner Name";
                    if "G/L Account No." = '' then begin
                        "G/L Account No." := ICRechargePartner."Source G/L Account No.";
                        "G/L Account Name" := ICRechargePartner."Source G/L Account Name";
                    end;
                    if "Target IC G/L Account No." = '' then begin
                        "Target IC G/L Account No." := ICRechargePartner."Target IC G/L Account No.";
                        "Target IC G/L Account Name" := ICRechargePartner."Target IC G/L Account Name";
                    end;
                    if "Recharge Method" = "Recharge Method"::" " then
                        "Recharge Method" := ICRechargePartner."Recharge Method";
                    // Default Currency Code from partner Currency Rule
                    DefaultCurrencyFromPartner(ICRechargePartner);
                end else begin
                    "IC Partner Name" := '';
                end;
            end;
        }
        field(4; "IC Partner Name"; Text[100])
        {
            Caption = 'IC Partner Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(5; "G/L Account No."; Code[20])
        {
            Caption = 'G/L Account No.';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account"."No." where("Account Type" = const(Posting));

            trigger OnValidate()
            begin
                if "G/L Account No." <> '' then begin
                    GLAccount.Get("G/L Account No.");
                    "G/L Account Name" := GLAccount.Name;
                end else
                    "G/L Account Name" := '';
            end;
        }
        field(6; "G/L Account Name"; Text[100])
        {
            Caption = 'G/L Account Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(7; "Target IC G/L Account No."; Code[20])
        {
            Caption = 'Target IC G/L Account No.';
            DataClassification = CustomerContent;
            TableRelation = "IC G/L Account"."No.";

            trigger OnValidate()
            begin
                if "Target IC G/L Account No." <> '' then begin
                    ICGLAccount.Get("Target IC G/L Account No.");
                    "Target IC G/L Account Name" := ICGLAccount.Name;
                end else
                    "Target IC G/L Account Name" := '';
            end;
        }
        field(8; "Target IC G/L Account Name"; Text[100])
        {
            Caption = 'Target IC G/L Account Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(9; "Recharge Method"; Enum "IC Recharge Method")
        {
            Caption = 'Recharge Method';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                RecalcRechargeAmount();
            end;
        }
        field(10; "Source Amount"; Decimal)
        {
            Caption = 'Source Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;

            trigger OnValidate()
            begin
                RecalcRechargeAmount();
            end;
        }
        field(11; "Allocation %"; Decimal)
        {
            Caption = 'Allocation %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            MaxValue = 100;

            trigger OnValidate()
            begin
                RecalcRechargeAmount();
            end;
        }
        field(12; "Recharge Amount"; Decimal)
        {
            Caption = 'Recharge Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;

            trigger OnValidate()
            begin
                if "Source Amount" <> 0 then
                    "Allocation %" := Round("Recharge Amount" / "Source Amount" * 100, 0.00001)
                else
                    "Allocation %" := 0;
            end;
        }
        field(13; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency.Code;
        }
        field(14; "Description"; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(15; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
            DataClassification = SystemMetadata;
            Editable = false;
            TableRelation = "Dimension Set Entry";
        }
        field(16; "Shortcut Dimension 1 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 1 Code';
            CaptionClass = '1,2,1';
            DataClassification = CustomerContent;
            TableRelation = "Dimension Value".Code where("Global Dimension No." = const(1));

            trigger OnValidate()
            begin
                ValidateShortcutDimCode(1, "Shortcut Dimension 1 Code");
            end;
        }
        field(17; "Shortcut Dimension 2 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 2 Code';
            CaptionClass = '1,2,2';
            DataClassification = CustomerContent;
            TableRelation = "Dimension Value".Code where("Global Dimension No." = const(2));

            trigger OnValidate()
            begin
                ValidateShortcutDimCode(2, "Shortcut Dimension 2 Code");
            end;
        }
        field(18; "Allocation Basis"; Text[100])
        {
            Caption = 'Allocation Basis';
            DataClassification = CustomerContent;
        }
        field(19; "Allocation Calculation Note"; Text[250])
        {
            Caption = 'Allocation Calculation Note';
            DataClassification = CustomerContent;
        }
        field(20; "Exchange Rate"; Decimal)
        {
            Caption = 'Exchange Rate';
            DataClassification = CustomerContent;
            Editable = false;
            DecimalPlaces = 0 : 6;
            ToolTip = 'Specifies the exchange rate that was in effect at the time of recharge processing. Populated by the calculation engine; read-only.';
        }
        field(21; "Exchange Rate Amount"; Decimal)
        {
            Caption = 'Exchange Rate Amount';
            DataClassification = CustomerContent;
            Editable = false;
            AutoFormatType = 1;
            AutoFormatExpression = "Currency Code";
            ToolTip = 'Specifies the Recharge Amount converted to the line currency using the Exchange Rate stored at processing time.';
        }
    }

    keys
    {
        key(PK; "Request No.", "Line No.")
        {
            Clustered = true;
        }
        key(ICPartner; "Request No.", "IC Partner Code") { }
        key(GLAccount; "Request No.", "G/L Account No.") { }
    }

    var
        RechargeHeader: Record "IC Recharge Request Header";
        ICRechargePartner: Record "IC Recharge Partner";
        GLAccount: Record "G/L Account";
        ICGLAccount: Record "IC G/L Account";
        DimMgt: Codeunit DimensionManagement;

    trigger OnInsert()
    begin
        if "Line No." = 0 then
            "Line No." := GetNextLineNo();

        if "Request No." <> '' then begin
            if RechargeHeader.Get("Request No.") then begin
                if "IC Partner Code" = '' then
                    Validate("IC Partner Code", RechargeHeader."IC Partner Code");
                if "Currency Code" = '' then
                    Validate("Currency Code", RechargeHeader."Currency Code");
                RechargeHeader.CalcTotalAmount();
            end;
        end;
    end;

    trigger OnModify()
    begin
        if "Request No." <> '' then begin
            if RechargeHeader.Get("Request No.") then
                RechargeHeader.CalcTotalAmount();
        end;
    end;

    trigger OnDelete()
    begin
        if "Request No." <> '' then begin
            if RechargeHeader.Get("Request No.") then begin
                RechargeHeader.TestStatusIsDraft();
                RechargeHeader.CalcTotalAmount();
            end;
        end;
    end;

    local procedure RecalcRechargeAmount()
    begin
        case "Recharge Method" of
            "Recharge Method"::"Fixed Amount":
                exit;
            "Recharge Method"::"Percentage":
                if "Source Amount" <> 0 then
                    "Recharge Amount" := Round("Source Amount" * "Allocation %" / 100, 0.01)
                else
                    "Recharge Amount" := 0;
            "Recharge Method"::"Actual Cost":
                "Recharge Amount" := "Source Amount";
            else
                if "Source Amount" <> 0 then
                    "Recharge Amount" := Round("Source Amount" * "Allocation %" / 100, 0.01);
        end;
    end;

    local procedure GetNextLineNo(): Integer
    var
        ExistingLine: Record "IC Recharge Request Line";
    begin
        ExistingLine.SetRange("Request No.", "Request No.");
        if ExistingLine.FindLast() then
            exit(ExistingLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure ValidateShortcutDimCode(FieldNumber: Integer; var ShortcutDimCode: Code[20])
    begin
        DimMgt.ValidateShortcutDimValues(FieldNumber, ShortcutDimCode, "Dimension Set ID");
    end;

    /// <summary>
    /// Defaults the Currency Code on the line based on the partner's Currency Rule:
    ///   Use Partner Currency  → partner's own Currency Code field
    ///   Use Source Currency   → header Currency Code (blank = LCY)
    ///   Use Fixed Currency    → partner's fixed Currency Code field
    /// Only sets the code when the line's Currency Code is currently blank.
    /// </summary>
    local procedure DefaultCurrencyFromPartner(var Partner: Record "IC Recharge Partner")
    var
        Header: Record "IC Recharge Request Header";
    begin
        if "Currency Code" <> '' then
            exit; // already set — do not overwrite user's explicit choice

        case Partner."Currency Rule" of
            Partner."Currency Rule"::"Use Partner Currency":
                "Currency Code" := Partner."Currency Code";
            Partner."Currency Rule"::"Use Source Currency":
                begin
                    if RechargeHeader.Get("Request No.") then
                        "Currency Code" := RechargeHeader."Currency Code"
                    else if Header.Get("Request No.") then
                        "Currency Code" := Header."Currency Code";
                end;
            Partner."Currency Rule"::"Use Fixed Currency":
                "Currency Code" := Partner."Currency Code";
        end;
    end;
}
