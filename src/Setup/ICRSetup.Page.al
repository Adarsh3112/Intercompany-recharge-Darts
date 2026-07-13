page 50100 "ICR Setup"
{
    Caption = 'ICR Setup';
    PageType = Card;
    SourceTable = "ICR Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    AboutTitle = 'ICR Setup';
    AboutText = 'Global configuration for the Intercompany Recharge module, including numbering series and Job Queue batch processing.';

    layout
    {
        area(Content)
        {
            group(Numbering)
            {
                Caption = 'Numbering';
                field("Recharge Request Nos."; Rec."Recharge Request Nos.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series that will be used to assign numbers to new Intercompany Recharge Requests.';
                }
            }
            group(JobQueue)
            {
                Caption = 'Job Queue';
                field("Batch Chunk Size"; Rec."Batch Chunk Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many Recharge Requests the ICR Batch Processor commits per chunk. Chunked commits avoid holding a lock on the entire Recharge Request table when large volumes are processed by a Job Queue Entry.';
                }
                field("Last Job Status"; Rec."Last Job Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the outcome of the most recent ICR Batch Processor run: how many requests were processed, how many failed, and any high-level error message.';
                }
                field("Last Job Run DateTime"; Rec."Last Job Run DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the server date and time at which the ICR Batch Processor last completed a run.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Primary Key" := '';
            if Rec."Batch Chunk Size" = 0 then
                Rec."Batch Chunk Size" := 50;
            Rec.Insert(true);
        end;
    end;
}
