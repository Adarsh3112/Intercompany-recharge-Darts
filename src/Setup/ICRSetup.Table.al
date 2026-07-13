table 50100 "ICR Setup"
{
    Caption = 'ICR Setup';
    DataClassification = CustomerContent;
    DataPerCompany = true;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Recharge Request Nos."; Code[20])
        {
            Caption = 'Recharge Request Nos.';
            DataClassification = CustomerContent;
            TableRelation = "No. Series";
        }
        field(20; "Last Job Status"; Text[250])
        {
            Caption = 'Last Job Status';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(21; "Last Job Run DateTime"; DateTime)
        {
            Caption = 'Last Job Run DateTime';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(22; "Batch Chunk Size"; Integer)
        {
            Caption = 'Batch Chunk Size';
            DataClassification = CustomerContent;
            MinValue = 1;
            MaxValue = 10000;
            InitValue = 50;
            ToolTip = 'Specifies how many Recharge Requests the ICR Batch Processor commits per chunk. Chunked commits avoid holding a lock on the entire Recharge Request table for large jobs.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Singleton accessor. Ensures the single ICR Setup record exists and returns it.
    /// Called from OnOpenPage of the Setup Card and from any consumer needing setup values.
    /// </summary>
    procedure GetSetup()
    begin
        Reset();
        if not Get() then begin
            Init();
            "Primary Key" := '';
            if "Batch Chunk Size" = 0 then
                "Batch Chunk Size" := 50;
            Insert(true);
        end;
    end;

    /// <summary>
    /// Writes the supplied StatusText and CurrentDateTime into the ICR Setup
    /// singleton so users and administrators can inspect the outcome of the
    /// most recent ICR Batch Processor run. Auto-creates the Setup record
    /// when absent so background jobs never fail on a missing configuration.
    /// StatusText is safely clipped to the field's maximum length.
    /// </summary>
    procedure UpdateLastJobStatus(StatusText: Text)
    begin
        Reset();
        if not Get() then begin
            Init();
            "Primary Key" := '';
            if "Batch Chunk Size" = 0 then
                "Batch Chunk Size" := 50;
            Insert(true);
        end;
        "Last Job Status" := CopyStr(StatusText, 1, MaxStrLen("Last Job Status"));
        "Last Job Run DateTime" := CurrentDateTime();
        Modify(true);
    end;
}
