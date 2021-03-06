{...............................................................................}
{ CableGen V 15.1                                                               }
{-----------------------                                                        }
{ Description:                                                                  }
{-----------------------                                                        }
{ Created by: Mark Evans                                                        }
{  Date Created: 11 MAR 2016                                                 	}
{...............................................................................}
{ Known Outstanding Bugs:                                                       }
{   * Return value from CompareStrings gets overridden                          }
{       - Current work-around is to use global boolean CompareStringsResult     }
{           which doesn't get overridden.                                       } 
{   * Sorting does not work correctly - BOM                                     }
{   * Multi-core cable gets (nWire) ^ 2 entries in connection table (16 core    }
{      has 256 entries!)                                                        }
{                                                                               }
{...............................................................................}



Const
    PixelsPerChar          = 45;        // NOTE: Average for mix upper/lower text. Multiply by 1.1 for all upper case.
    LineHeight             = 150;
    FontSize               = 10;
    StartLocationX         = 300;

    NetTabBotLeftLocationX = StartLocationX;
    NetTabBotLeftLocationY = 300;
    FirstConnLocationX     = 2100;     // X of the first item in the connectivity table

    MaxDesignatorLength    = 7;        // Most number of characters accepted in a designator
Var
    SchDoc                  : ISch_Document;
    StartLocationY          : Integer;
    NetTabBotRightLocationX : Integer;
    WorkSpace               : IWorkSpace;

    //for connectivity
    FileName                : TDynamicString;
    PackingList             : TStringList;
    Project                 : IProject;

    // CompsList representing the list of components of a Schematic Project
    // Each entry in the CompsKist contains two objects:
    // 1. component designator string object
    // 2. CompData as a TList object
    CompsList               : TStringList;

    //CompData (TList) contains CompStrings and PadsStrings (TSTringLIsts)
    CompData                : TList;
    CompStrings             : TStringList;
    PadsStrings             : TStringList;

    I,J,K,NetCount,NetCountOut,UniqueNetCount  : Integer;
    ConnectorCount          :Integer;
    Doc                     : IDocument;
    PinNum                  : Integer;
    NetSet                  : Boolean;
    NetInArray              : Boolean;

    DesignatorArray         : Array[0..50] of string;//holds only the designators
    ComponentNumPinsArray   : Array[0..50] of integer;//holds only the designators
    PinNetArray             : Array[0..50,0..100] of string;//holds the pin connection info for the designators

    NetArray                : Array[0..100] of string;//holds only the nets
    NetOccurances           : Array[0..100] of integer;//holds only the number of pins a net connects to, used for check if net should be in table
    NetArrayOut             : Array[0..100] of string;//holds only the nets to be output to the schematic

    MaxLines                : Integer;
    ReturnLines             : Integer;
    LineLocationY           : Integer;

    InputComponentArray     : Array[0..5,0..100] of string;
    OutputComponentArray    : Array[0..5,0..50] of string;
    OutputComponentQty      : Array[0..50] of Integer;
    ArrayCount              : Integer;
    OutputArrayCount        : Integer;


    CompareStringsResult    : Integer;

{..............................................................................}

Procedure PlaceASchLine(Const StartX : Integer,
                              StartY : Integer,
                              FinishX : Integer,
                              FinishY : Integer);
Var
    SchLine : ISch_Line;
    SchemText : ISch_ComplexText;
Begin
     SchLine := SchServer.SchObjectFactory(eLine,eCreate_GlobalCopy);
     If SchLine = Nil Then Exit;

     SchLine.Location  := Point(MilsToCoord(StartX), MilsToCoord(StartY));
     SchLine.Corner    := Point(MilsToCoord(FinishX), MilsToCoord(FinishY));
     //SchLine.LineWidth := eMedium;
     SchLine.LineWidth := eSmall;
     SchLine.LineStyle := eLineStyleSolid;
     SchLine.Color := $000000;
     SchDoc.RegisterSchObjectInContainer(SchLine);
End;
{..............................................................................}

{..............................................................................}
Procedure PlaceString(PosX : Integer, PosY : Integer, TheText : String, Bold : Boolean);
Var
    Schlabel : ISch_Label;
Begin
    Schlabel := SchServer.SchObjectFactory(eLabel,eCreate_GlobalCopy);
    If Schlabel = Nil Then Exit;

    Schlabel.Location    := Point(MilsToCoord(PosX), MilsToCoord(PosY));
    SchLabel.FontID := SchServer.FontManager.GetFontID(FontSize,0,False,False,Bold,False,'Times New Roman');
    Schlabel.Text        := TheText;
    Schlabel.Orientation :=0;
    Schlabel.color       := 8388608;
    SchLabel.SetState_IsMirrored(0);
    SchLabel.Justification := 0;

    SchDoc.RegisterSchObjectInContainer(Schlabel);
End;
{..............................................................................}

{..............................................................................}

Function PlaceStringMultiLine(PosX : Integer, PosY : Integer, TheText : String, Bold : Boolean, CharWide:Integer) : Integer;
Var
   TextPos : integer;
   NumOfLines : integer;
Begin
     // Make sure the text ends with a white space.
     NumOfLines := 0;
     While Length(TheText)>0 Do
     Begin
          If Length(TheText)>CharWide Then
          Begin
               TextPos:=CharWide+1;
               While ( TextPos > 0 ) Do
               Begin
                    // If we see a space/EOL, draw the text & go to newline
                    If ( Copy(TheText,TextPos,1) = ' ' ) Then
                    Begin
                         PlaceString(PosX, PosY, Copy(TheText,1,TextPos), Bold);
                         NumOfLines:=NumOfLines+1;
                         TheText := Copy(TheText,TextPos+1,99999);
                         Posy := Posy - LineHeight;
                         TextPos :=0;
                    End
                    Else If TextPos <= 0 Then
                    Begin  //No spaces just put whole string out anyway so data is available
                         PlaceString(PosX, PosY, TheText, Bold);
                         NumOfLines:=NumOfLines+1;
                         TheText := '';
                         Posy := Posy- LineHeight;
                         TextPos :=0;
                    End;
                    TextPos := TextPos-1;
               End;
          End
          Else
          Begin
               PlaceString(PosX, PosY, TheText, Bold);
               NumOfLines:=NumOfLines+1;
               TheText := '';
               Posy := Posy- LineHeight;
          End;

     End;
     Result := NumOfLines;

End;
{..............................................................................}

{..............................................................................}
Function StrIntTest(TheText : String) : boolean;
Var
   TextPos : integer;
   StrChar : string;
   IsNumber : boolean;
Begin

     IsNumber:=True;
     for TextPos:=1 to Length(TheText) do
     begin
          if Ord(TheText[TextPos])>=58 then
          begin
             IsNumber:=False;
             TextPos:= Length(TheText);
          end;
          if Ord(TheText[TextPos])<=48 then
          begin
             IsNumber:=False;
             TextPos:= Length(TheText);
          end;
     end;

     Result:=IsNumber;
End;
{..............................................................................}

{..............................................................................}
Function AddQty(CurrentQty : Integer, AddQtyStr : String) : Integer;
Var
   OutputQty : integer;
   TestBool : boolean;
Begin
Try
   //TestBool := TryStrToInt('10',OutputQty);
   //OutputQty := CurrentQty + StrToInt('hello');
Except //exception it must be a non valid number eg text 'As Required'
       OutputComponentQty[OutputArrayCount] := -1;
End;

     OutputQty:=-1;
     if CurrentQty>=0 then
    begin

        if AddQtyStr ='' then
        begin
             OutputQty := CurrentQty + 1;
        end
        else
        begin
             if StrIntTest(AddQtyStr) = true then
             begin
                OutputQty := CurrentQty + StrToInt(AddQtyStr);
             end
             else  //it must be a non valid number eg text 'As Required'
             begin
                    OutputComponentQty[OutputArrayCount] := -1;
             End;
        end;


    end;
    Result := OutputQty;

End;
{..............................................................................}

{..............................................................................}
FUNCTION Find(Const Needle, Haystack : String) : Integer;
Begin
    Result := pos( Needle, Haystack );
End;
{..............................................................................}

{..............................................................................}
FUNCTION IsAlpha(CheckString : STRING) : Boolean;
Var
    ALPHA_CHARS : String;
Begin
    ALPHA_CHARS := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if CheckString = '' THEN
        Result := TRUE
    ELSE If pos( copy( CheckString, 1, 1), ALPHA_CHARS ) > 0 THEN
        Result := TRUE
    ELSE
        Result := FALSE;
End;
{..............................................................................}

{..............................................................................}
FUNCTION IsNum(CheckString : STRING) : Boolean;
Var
    NUM_CHARS   : String;
Begin
    NUM_CHARS   := '0123456789';
    if CheckString = '' THEN
        Result := TRUE
    ELSE If pos( copy( CheckString, 1, 1), NUM_CHARS ) > 0 THEN
        Result := TRUE
    ELSE
        Result := FALSE
End;
{..............................................................................}

{..............................................................................}
Function CompareStrings(String1, String2 : STRING) : Integer;
Var
   i                : Integer;
   j                : Integer;
   k                : Integer;
   sSec_Strings     : Array[1..2,0..15] OF STRING;
   sInputStrings    : ARRAY[1..2] OF STRING;
   sChar            : String;
Begin
    // Loop through each character in the string first
    sInputStrings[1] := String1;
    sInputStrings[2] := String2;
    // Loop through each input string
    FOR k := 1 TO 2 DO BEGIN
        j := 0;
        // Loop through each character in the input string
        FOR i := 1 TO length(sInputStrings[k]) DO BEGIN
            sChar := Copy(sInputStrings[k], i, 1);
            // If it is an alphabetical character
            if IsAlpha(sChar) THEN BEGIN
                // If the last character stored NOT Alphabetical, move to next section
                if NOT IsAlpha(sSec_Strings[k,j]) THEN
                    j := j + 1;
                // Store the character
                sSec_Strings[k,j] := sSec_Strings[k,j] + sChar;
            // If it is a numerical character in the string
            END ELSE IF IsNum(sChar) THEN BEGIN
                // If the last character stored NOT numerical, move to next section
                if NOT IsNum(sSec_Strings[k,j]) THEN
                    j := j + 1;
                // Store the character
                sSec_Strings[k,j] := sSec_Strings[k,j] + sChar;
                // If we have too many sections, exit
                IF j >= 15 THEN BEGIN
                    ShowMessage('ERROR: STRING TOO LONG');
                    Exit;
                END;
            // No alphabetical/numerical characters (i.e. ._- characters)
            END ELSE BEGIN
                // Move to the next section
                if sSec_Strings[k,j] <> '' THEN
                    j := j + 1;
            END;
        END;
    END;

    // Compare each section
    Result := 0;
    FOR i := 0 to j DO BEGIN
        // If a string section is empty, it goes first
        IF sSec_Strings[1,i] = '' THEN
            Result := -1
        ELSE IF sSec_Strings[2,i] = '' Then
            Result := 1
        // Alphabetical goes before Numerical
        ELSE IF IsAlpha(sSec_Strings[1,i]) AND NOT IsAlpha(sSec_Strings[2,i]) Then
            Result := 1
        ELSE IF IsAlpha(sSec_Strings[2,i]) AND NOT IsAlpha(sSec_Strings[1,i]) Then
            Result := -1
        // Compare alphabetical
        ELSE IF IsAlpha(sSec_Strings[1,i]) THEN
            Result := CompareText(sSec_Strings[1,i], sSec_Strings[2,i])
        // Compare Numerical
        ELSE If IsNum(sSec_Strings[1,i]) THEN BEGIN
            if StrToInt(sSec_Strings[1,i]) > StrToInt(sSec_Strings[2,i]) THEN
                Result := 1
            ELSE IF StrToInt(sSec_Strings[1,i]) < StrToInt(sSec_Strings[2,i]) THEN
                Result := -1
            // Else: Strings are identical, go to next section
            END;
        // If a result has been found, end the loop
        IF Result <> 0 THEN BEGIN
            break;
        END;
    END;
    (*
        BUG: For some reason the Result from CompareStrings is not being returned
             correctly, which annoys the shit out of me.
             My current solution is to store the result in a global variable, but
             I'm not happy with this.
             Unfortunately I have a simple solution, so I need to use it for the moment.
    *)
    CompareStringsResult := Result;
    Result := Result;
End;
{..............................................................................}

{..............................................................................}
Function StringListJoin(const str_list : TStringList;
                              str_join : String
                              ) : String;
Var
    i                       : Integer;
    str                     : String;
Begin
     str := '';
     For i := 0 To (str_list.Count - 1) Do
     Begin
          str := str + str_list[i];
          if i <> str_list.Count - 1 Then
            str := str + str_join;
     End;
     Result := str;
End;
{..............................................................................}

{..............................................................................}
Function TableExists(const TableName : String) : Boolean;
Var
    SchDoc                  : ISch_Document;
    Iterator                : ISch_Iterator;
    AComponent              : ISch_Component;
Begin
    // Check If schematic server exists or not.
    If SchServer = Nil Then Exit;
    // Obtain the current schematic document interface.
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then Exit;
    // Iterate through each object.
    Iterator := SchDoc.SchIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eLabel));
    Result := False;
    Try
        AComponent := Iterator.FirstSchObject;
        While AComponent <> Nil Do
        Begin
            If AComponent.GetState_Text = TableName Then
            Begin
               Result := True;
               Break;
            End;
            AComponent := Iterator.NextSchObject;
        End;
    Finally
        SchDoc.SchIterator_Destroy(Iterator);
    End;
End;
{..............................................................................}

{..............................................................................}
{             _____                _         ____        __  __                }
{            / ____|              | |       |  _ \      |  \/  |               }
{           | |     _ __ ___  __ _| |_ ___  | |_) | ___ | \  / |               }
{           | |    | '__/ _ \/ _` | __/ _ \ |  _ < / _ \| |\/| |               }
{           | |____| | |  __/ (_| | ||  __/ | |_) | (_) | |  | |               }
{            \_____|_|  \___|\__,_|\__\___| |____/ \___/|_|  |_|               }
{                                                                              }
{..............................................................................}
Procedure CreateBOM;
Const
    ItemID                  = 0;
    Designator              = 1;
    Description             = 2;
    MFG                     = 3;
    PartNumber              = 4;
    Qty                     = 5;
    CheckedBy               = 6;
    PartType                = 7;
    nMaxBOMLength           = 100;
    
    ItemIdWidth             = 500;
    //DesignatorWidth      := AsBigAsPossible;
    DescriptionWidth        = 5400;
    MFGWidth                = 1500;
    PartNumWidth            = 1500;
    QtyWidth                = 800;

Var
    i, j                    : Integer;
    bubble_swapped          : Boolean;
    nLineY                  : Integer;

    DesignatorWidth         : Integer;
    DesignatorLocationX     : Integer;
    QTYLocationX            : Integer;
    PartNumLocationX        : Integer;
    MFGLocationX            : Integer;
    DescriptionLocationX    : Integer;
    TableEndLocationX       : Integer;
    nLinesDrawn             : Integer;   // Used as feedback from multi-line strings

    ComponentIterator       : ISch_Iterator;
    ParameterIterator       : ISch_Iterator;
    Component               : ISch_Component;
    Parameter               : ISch_Parameter;
    SchDocument             : IServerDocument;
    Doc                     : IDocument;
    Project                 : IProject;
    ComponentParameters     : Array[1..7] of String;
    BOM                     : Array[0..nMaxBOMLength,0..7] of String;
Begin
    // Check If schematic server exists or not.
    If SchServer = Nil Then Exit;
    // do a compile so the logical documents get expanded into physical documents.
    Project := GetWorkspace.DM_FocusedProject;
    If Project = Nil Then Exit;
    Project.DM_Compile;
    
    // Loop through each schematic in the project.
    For i := Project.DM_PhysicalDocumentCount - 1 downto 0 Do
    Begin
        Doc := Project.DM_PhysicalDocuments(i);
        // Open this doc and focus it.
        SchDocument := Client.OpenDocument('Sch', Doc.DM_FullPath);
        If SchDocument = Nil Then Exit;
        Client.ShowDocument(SchDocument);
        // Obtain the current schematic document interface.
        SchDoc := SchServer.GetCurrentSchDocument;
        If SchDoc = Nil Then Exit;
///////////////////////////////////////////////////////
// Collect all the components parameters
///////////////////////////////////////////////////////
        Begin
            // Loop through each component
            ComponentIterator := SchDoc.SchIterator_Create;
            If ComponentIterator = Nil Then Exit;
            ComponentIterator.AddFilter_ObjectSet(MkSet(eSchComponent));
            Try
                Component := ComponentIterator.FirstSchObject;
                While Component <> Nil Do
                Begin
                    // Get the component Designator & Library
                    If( Length( Component.Designator.Text ) > MaxDesignatorLength ) Then
                    Begin
                        ShowMessage( 'ERROR: DESIGNATOR ' + Component.Designator.Text + ' IS TOO LONG');
                        ShowMessage( 'BOM did not generate successfully' );
                        Exit;
                    End;
                    ComponentParameters[Designator]  := Component.Designator.Text;
                    ComponentParameters[MFG]         := '';
                    ComponentParameters[PartNumber]  := '';
                    ComponentParameters[Description] := '';
                    ComponentParameters[Qty]         := '1';
                    ComponentParameters[CheckedBy]   := '';
                    ComponentParameters[PartType]    := '';
                    // Loop through each parameter in each component
                    ParameterIterator := Component.SchIterator_Create;
                    ParameterIterator.AddFilter_ObjectSet(MkSet(eParameter));
                    Parameter := ParameterIterator.FirstSchObject;
                    Try
                        Parameter := ParameterIterator.FirstSchObject;
                        While Parameter <> Nil Do
                        Begin
                            Case uppercase(Parameter.Name) Of
                            'MFG'          , 'MANUFACTURER'  : ComponentParameters[MFG]          := Parameter.Text;
                            'PARTNUM'      , 'PARTNUMBER'    : ComponentParameters[PartNumber]   := Parameter.Text;
                            'DESCRIPTIONIN','PART FIELD 1'   : ComponentParameters[Description]  := Parameter.Text;  
                            'QTY'                            : ComponentParameters[Qty]          := Parameter.Text;
                            'CHECKED BY'   , 'CHECKEDBY'     : ComponentParameters[CheckedBy]    := Parameter.Text;
                            'PARTTYPE'                       : ComponentParameters[PartType]     := Parameter.Text;
                            //BOMGen assume 1
                            End;
                            Parameter := ParameterIterator.NextSchObject;
                        End;
                    Finally
                        Component.SchIterator_Destroy(ParameterIterator);
                    End;
                    // If the part is wire then have the length 'As Required'.
                    If( ComponentParameters[PartType] = 'Wire' ) THEN
                      ComponentParameters[Qty] := 'As Required.';
                    // Add the component parameters to the BOM.
                    For j := 1 to nMaxBOMLength Do
                    Begin
                        If (BOM[j, MFG] = '') OR
                        ((BOM[j, PartNumber] = ComponentParameters[PartNumber]) AND (BOM[j, MFG] = ComponentParameters[MFG])) Then
                        Begin
                            // Set-up the designator to be a TStringList
                            if BOM[j, MFG] = '' Then
                            Begin
                                BOM[j, Designator] := TStringList.Create;
                                BOM[j, Designator].Sorted := True;
                                BOM[j, Designator].Duplicates := dupIgnore;
                            End;
                            // Add the component to the BOM
                            BOM[j, Designator].Add(ComponentParameters[Designator]);
                            BOM[j, MFG]         := ComponentParameters[MFG];
                            BOM[j, PartNumber]  := ComponentParameters[PartNumber];
                            BOM[j, Description] := ComponentParameters[Description];
                            if IsNum(ComponentParameters[Qty]) THEN
                                BOM[j, Qty]     := BOM[j, Qty] + 1
                            else
                                BOM[j, Qty]     := ComponentParameters[Qty];
                            BOM[j, CheckedBy]   := ComponentParameters[CheckedBy];
                            BOM[j, PartType]    := ComponentParameters[PartType];
                            
                            Break;
                        End;
                    End;
                    // Go to the next component
                    Component := ComponentIterator.NextSchObject;
                End;
            Finally
                SchDoc.SchIterator_Destroy(ComponentIterator);
            End;
        End;
    End;
    // Exit if the sheet has no components
    If BOM[1,MFG] = '' Then Exit;
///////////////////////////////////////////////////////
// Sort the BOM by Designator
///////////////////////////////////////////////////////
    Begin
        Repeat
            bubble_swapped := False;
            For i := 1 to nMaxBOMLength-1 Do
            Begin
                // If there is a next item
                if BOM[i+1, MFG] <> '' Then
                Begin
                    // Check whether it needs to swap
                    if CompareText(BOM[i,   Designator][0],
                                   BOM[i+1, Designator][0]) > 0 Then
                    Begin
                        // Swap
                        ComponentParameters[Designator ] := BOM[i, Designator ];
                        ComponentParameters[Description] := BOM[i, Description];
                        ComponentParameters[MFG        ] := BOM[i, MFG        ];
                        ComponentParameters[PartNumber ] := BOM[i, PartNumber ];
                        ComponentParameters[Qty        ] := BOM[i, Qty        ];
                        ComponentParameters[CheckedBy  ] := BOM[i, CheckedBy  ];
                        ComponentParameters[PartType   ] := BOM[i, PartType   ];
                        
                        BOM[i, Designator   ] := BOM[i+1, Designator ];
                        BOM[i, Description  ] := BOM[i+1, Description];
                        BOM[i, MFG          ] := BOM[i+1, MFG        ];
                        BOM[i, PartNumber   ] := BOM[i+1, PartNumber ];
                        BOM[i, Qty          ] := BOM[i+1, Qty        ];
                        BOM[i, CheckedBy    ] := BOM[i+1, CheckedBy  ];
                        BOM[i, PartType     ] := BOM[i+1, PartType   ];

                        BOM[i+1, Designator ] := ComponentParameters[Designator ];
                        BOM[i+1, Description] := ComponentParameters[Description];
                        BOM[i+1, MFG        ] := ComponentParameters[MFG        ];
                        BOM[i+1, PartNumber ] := ComponentParameters[PartNumber ];
                        BOM[i+1, Qty        ] := ComponentParameters[Qty        ];
                        BOM[i+1, CheckedBy  ] := ComponentParameters[CheckedBy  ];
                        BOM[i+1, PartType   ] := ComponentParameters[PartType   ];
                        
                        bubble_swapped := True;
                    End;
                End;
            End;
        Until Not bubble_swapped;
    End;
///////////////////////////////////////////////////////
// Set-up the Table
///////////////////////////////////////////////////////
    Begin
        // Set the Y location & dimensions of the BOM relative to the sheet size
        StartLocationY:=SchDoc.SheetSizeY / 10000 - 500;
        // Get the x location of everything
        DesignatorLocationX  := StartLocationX+ItemIDWidth;
        TableEndLocationX    := SchDoc.SheetSizeX / 10000 - 2500; // Set the table width to page width, leave room for library names
        QTYLocationX         := TableEndLocationX - QtyWidth;
        PartNumLocationX     := QTYLocationX - PartNumWidth;
        MFGLocationX         := PartNumLocationX - MFGWidth;
        DescriptionLocationX := MFGLocationX - DescriptionWidth;
        DesignatorWidth      := DescriptionLocationX - DesignatorLocationX;
        // Titles
        BOM[0, ItemID]      := 'Item ID'      ;
        BOM[0, Designator]  := TStringList.Create;
        BOM[0, Designator].Add('Designator'  );
        BOM[0, MFG]         := 'Manufacturer' ;
        BOM[0, PartNumber]  := 'Part Number'  ;
        BOM[0, Description] := 'Description'  ;
        BOM[0, Qty]         := 'Quantity'     ;
        BOM[0, CheckedBy]   := ''             ;
        for i := 1 To nMaxBOMLength Do
            BOM[i, ItemID] := Format('%d.0', [i]);
        
    End;
///////////////////////////////////////////////////////
// Draw all the components
///////////////////////////////////////////////////////
    Begin
        PlaceString(    StartLocationX + 100,
                        StartLocationY,
                        'BILL OF MATERIALS',
                        True);
        PlaceASchLine(  StartLocationX,
                        StartLocationY,
                        TableEndLocationX,
                        StartLocationY);
        nLineY := StartLocationY - LineHeight;
        nLinesDrawn := 1;
        for i := 0 to nMaxBOMLength Do
        Begin
            if( BOM[i, MFG] <> '' ) THEN
            Begin
                // Draw the item ID
                nLinesDrawn := 1;
                nLinesDrawn := max(PlaceStringMultiLine(
                                                StartLocationX+100,
                                                nLineY,
                                                BOM[i, ItemID],
                                                i = 0,
                                                ItemIDWidth/PixelsPerChar)
                                    , nLinesDrawn);
                // Draw the Designator
                nLinesDrawn := max(PlaceStringMultiLine(
                                                DesignatorLocationX+100,
                                                nLineY,
                                                StringListJoin(BOM[i, Designator], ', '),
                                                i = 0,
                                                DesignatorWidth/PixelsPerChar)
                                    , nLinesDrawn);
                // Draw the Description
                nLinesDrawn := max(PlaceStringMultiLine(
                                                DescriptionLocationX+100,
                                                nLineY,
                                                BOM[i, Description],
                                                i = 0,
                                                DescriptionWidth/PixelsPerChar)
                                    , nLinesDrawn);
                // Draw the MFG
                nLinesDrawn := max(PlaceStringMultiLine(
                                                MFGLocationX+100,
                                                nLineY,
                                                BOM[i, MFG],
                                                i = 0,
                                                MFGWidth/PixelsPerChar)
                                    , nLinesDrawn);
                // Draw the PartNum
                nLinesDrawn := max(PlaceStringMultiLine(
                                                PartNumLocationX+100,
                                                nLineY,
                                                BOM[i, PartNumber],
                                                i = 0,
                                                PartNumWidth/PixelsPerChar)
                                    , nLinesDrawn);
                // Draw the Quantity
                nLinesDrawn := max(PlaceStringMultiLine(
                                                QtyLocationX+100,
                                                nLineY,
                                                BOM[i, Qty],
                                                i = 0,
                                                QtyWidth/PixelsPerChar)
                                    , nLinesDrawn);
                // Draw the Library
                if( (Length(BOM[i, CheckedBy]) <> 3) and (Length(BOM[i, CheckedBy]) <> 4) and (i <> 0) ) THEN
                   PlaceStringMultiLine(   TableEndLocationX+100,
                                           nLineY,
                                           'Unchecked',
                                           i = 0,
                                           100);
                // Move the y down
                nLineY := nLineY - max(nLinesDrawn, 1) * LineHeight;
                // Draw the horizontal separator
                PlaceASchLine(StartLocationX,
                              nLineY + LineHeight,
                              TableEndLocationX,
                              nLineY + LineHeight);
            End;
            //if BOM[i, MFG] <> '' THEN
            //   ShowMessage(StringListJoin(BOM[i, Designator], ', '));
            //End;
        End;
        nLineY := nLineY + LineHeight;
        // Draw the vertical line before the ItemID
        PlaceASchLine(StartLocationX,
                      StartLocationY,
                      StartLocationX,
                      nLineY);
        // Draw the vertical line before the Designator
        PlaceASchLine(DesignatorLocationX,
                      StartLocationY,
                      DesignatorLocationX,
                      nLineY);
        // Draw the vertical line before the Description
        PlaceASchLine(DescriptionLocationX,
                      StartLocationY,
                      DescriptionLocationX,
                      nLineY);
        // Draw the vertical line before the MFG
        PlaceASchLine(MFGLocationX,
                      StartLocationY,
                      MFGLocationX,
                      nLineY);
        // Draw the vertical line before the PartNum
        PlaceASchLine(PartNumLocationX,
                      StartLocationY,
                      PartNumLocationX,
                      nLineY);
        // Draw the vertical line before the Quantity
        PlaceASchLine(QtyLocationX,
                      StartLocationY,
                      QtyLocationX,
                      nLineY);
        // Draw the vertical line before the Library
        PlaceASchLine(TableEndLocationX,
                      StartLocationY,
                      TableEndLocationX,
                      nLineY);
    End;
    // Free memory
    for i := 0 To nMaxBOMLength Do
    Begin
        IF BOM[i, MFG] <> '' THEN
           BOM[i, Designator].Free;
    End;
End;
{..............................................................................}

{..............................................................................}
{   _    _ _     _         _____                                     _         }
{  | |  | (_)   | |       / ____|                                   | |        }
{  | |__| |_  __| | ___  | |     ___  _ __ ___  _ __ ___   ___ _ __ | |_ ___   }
{  |  __  | |/ _` |/ _ \ | |    / _ \| '_ ` _ \| '_ ` _ \ / _ \ '_ \| __/ __|  }
{  | |  | | | (_| |  __/ | |___| (_) | | | | | | | | | | |  __/ | | | |_\__ \  }
{  |_|  |_|_|\__,_|\___|  \_____\___/|_| |_| |_|_| |_| |_|\___|_| |_|\__|___/  }
{                                                                              }
{..............................................................................}
Procedure HideComments;
Var
    Iterator   : ISch_Iterator;
    PIterator  : ISch_Iterator;
    AComponent : ISch_Component;
    Parameter  : ISch_Parameter;
    sDebugString    : STRING;
Begin

    // Check if schematic server exists or not.
    If SchServer = Nil Then Exit;

    // Obtain the current schematic document interface.
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then Exit;

    // Look for components only
    Iterator := SchDoc.SchIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

/////////////////////////////////////////////
//Find all the components - Hide comments
//////////////////////////////////////////////
    Try
        //SchServer.ProcessControl.PreProcess(SchDoc, '');
        AComponent := Iterator.FirstSchObject;
        While AComponent <> Nil Do
        Begin
            Try
                PIterator := AComponent.SchIterator_Create;
                PIterator.AddFilter_ObjectSet(MkSet(eParameter));

                Parameter := PIterator.FirstSchObject;
                While Parameter <> Nil Do
                Begin

                    if Parameter.Name = 'Comment' THEN Begin
                        Parameter.IsHidden := TRUE;
                    End;
                    Parameter := PIterator.NextSchObject;
                End;
            Finally
                AComponent.SchIterator_Destroy(PIterator);
            End;
            AComponent := Iterator.NextSchObject;
        End;
    Finally
        SchDoc.SchIterator_Destroy(Iterator);
    End;
END;
{..............................................................................}

{..............................................................................}
{             _           _          _   _______    _     _                    }
{            | |         | |        | | |__   __|  | |   | |                   }
{            | |     __ _| |__   ___| |    | | __ _| |__ | | ___               }
{            | |    / _` | '_ \ / _ \ |    | |/ _` | '_ \| |/ _ \              }
{            | |___| (_| | |_) |  __/ |    | | (_| | |_) | |  __/              }
{            |______\__,_|_.__/ \___|_|    |_|\__,_|_.__/|_|\___|              }
{                                                                              }
{..............................................................................}
Procedure CreateLabels;

Var
    i                       : Integer;
    Iterator                : ISch_Iterator;
    PIterator               : ISch_Iterator;
    AComponent              : ISch_Component;
    Parameter               : ISch_Parameter;
    SchDocument             : IServerDocument;
    Doc                     : IDocument;
    Project                 : IProject;

    descriptionField        : Boolean;

    StringDesignatorArray   : Array[0..100] of String;
    numLabels               : Integer;
    labelIndex              : Integer;

    bubble_i                : Integer;
    bubble_temp             : String;
    bubble_swapped          : Boolean;

    connectivityTableY      : Integer;
    tableStartLocationY     : Integer;
    tableEndLocationY       : Integer;
    tableEndLocationX       : Integer;
	
	locStr					: String;
Begin
    // Check If schematic server exists or not.
    If SchServer = Nil Then Exit;
    // do a compile so the logical documents get expanded into physical documents.
    Project := GetWorkspace.DM_FocusedProject;
    If Project = Nil Then Exit;
    Project.DM_Compile;
    
    numLabels := 0;
    // Loop through each schematic in the project.
    For i := Project.DM_PhysicalDocumentCount - 1 downto 0 Do
    Begin
        Doc := Project.DM_PhysicalDocuments(i);
        // Open this doc and focus it.
        SchDocument := Client.OpenDocument('Sch', Doc.DM_FullPath);
        If SchDocument = Nil Then Exit;
        Client.ShowDocument(SchDocument);
        // Obtain the current schematic document interface.
        SchDoc := SchServer.GetCurrentSchDocument;
        If SchDoc = Nil Then Exit;
        
        // Look for components only
        Iterator := SchDoc.SchIterator_Create;
        Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

/////////////////////////////////////////////
//Find all the labels
//////////////////////////////////////////////
        Try
            AComponent := Iterator.FirstSchObject;
            While AComponent <> Nil Do
            Begin
                Try
                    PIterator := AComponent.SchIterator_Create;
                    PIterator.AddFilter_ObjectSet(MkSet(eParameter));
        
                    Parameter := PIterator.FirstSchObject;
                    While Parameter <> Nil Do
                    Begin
                        // Find it is the description field
                        descriptionField := False;
                        If ( Uppercase( Parameter.Name ) = 'DESCRIPTIONIN' ) Then
                          descriptionField := True;
                        If ( Uppercase( Parameter.Name ) = 'DESCRIPTION' ) Then Begin
                            If ( Uppercase( Parameter.text ) <> '=DESCRIPTIONIN' ) Then
                                    descriptionField := True;
                        End;

                        If descriptionField Then
                        Begin
                            // If the Description has the text 'Label'
                            If Pos('Label', Parameter.Text) > 0 Then
                            Begin
                                // Store the designator
                                StringDesignatorArray[numLabels] := AComponent.Designator.Text;
                                numLabels := numLabels + 1;
                            End;
                        End;
                        Parameter := PIterator.NextSchObject;
                    End;
                Finally
                    AComponent.SchIterator_Destroy(PIterator);
                End;
                AComponent := Iterator.NextSchObject;
            End;
        Finally
            SchDoc.SchIterator_Destroy(Iterator);
        End;
    End;
/////////////////////////////////////////////
//Sort all the labels
//////////////////////////////////////////////
    Repeat
        bubble_swapped := False;
        For bubble_i := 1 to numLabels - 1 Do
        Begin
        CompareStrings(StringDesignatorArray[bubble_i], StringDesignatorArray[bubble_i - 1]);
            If CompareStringsResult < 0 Then
            Begin
                bubble_temp := StringDesignatorArray[bubble_i];
                StringDesignatorArray[bubble_i] := StringDesignatorArray[bubble_i - 1];
                StringDesignatorArray[bubble_i - 1] := bubble_temp;
                bubble_swapped := True;
            End;
        End;
    Until not bubble_swapped;
/////////////////////////////////////////////
//Find where to display all the labels
//////////////////////////////////////////////
    connectivityTableY := NetTabBotLeftLocationY - LineHeight;
    Iterator := SchDoc.SchIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eLabel));
    Try
        AComponent := Iterator.FirstSchObject;
        While AComponent <> Nil Do
        Begin
            If AComponent.GetState_Text = 'CONNECTION TABLE' Then
            Begin
               connectivityTableY := AComponent.Location.Y / 10000 + 100;
               Break;
            End;
            AComponent := Iterator.NextSchObject;
        End;
    Finally
        SchDoc.SchIterator_Destroy(Iterator);
    End;
/////////////////////////////////////////////
//Display all the labels
//////////////////////////////////////////////
    If numLabels > 0 Then
    Begin
        // Draw the table outline
        tableStartLocationY := (numLabels + 4) * LineHeight + connectivityTableY;
        tableEndLocationY := tableStartLocationY - LineHeight * (numLabels + 3);
        tableEndLocationX := StartLocationX+3700;
        PlaceASchLine(StartLocationX,tableStartLocationY,TableEndLocationX,tableStartLocationY);
        PlaceASchLine(StartLocationX,tableStartLocationY,StartLocationX,tableEndLocationY);
        PlaceASchLine(tableEndLocationX,tableStartLocationY,tableEndLocationX,tableEndLocationY);
        PlaceASchLine(StartLocationX,tableEndLocationY,TableEndLocationX,tableEndLocationY);
        // Separator between Designators & Labels
        PlaceASchLine(StartLocationX+800,tableStartLocationY,StartLocationX+800,tableEndLocationY);
		// Separator between Labels & Locations
		PlaceASchLine(StartLocationX+2700,tableStartLocationY,StartLocationX+2700,tableEndLocationY);
        // Add the headers
        PlaceString(StartLocationX+100,tableStartLocationY,'LABELS',true);
        PlaceString(StartLocationX+100,tableStartLocationY-LineHeight,'Designator',true);
        PlaceString(StartLocationX+900,tableStartLocationY-LineHeight,'Label',true);
        PlaceString(StartLocationX+2800,tableStartLocationY-LineHeight,'Location',true);
        // Draw the Loom PN Information (Designator & Location filled in during while loop)
        PlaceString(  StartLocationX+900,
                        tableEndLocationY+2*LineHeight,
                        '=SchemNum+''.''+Copy(SchemRev,1,1)',
                        false
                     );
        PlaceStringMultiLine(StartLocationX+900,
                                   tableEndLocationY+LineHeight,
                                   'DD-MMM-YY                 Supplier Code',
                                   false,
                                   26);
						
        // Whittle away at the labels
        labelIndex := numLabels - 1;
        While labelIndex >= 0 Do
        Begin
            // Designator
             PlaceString(StartLocationX+100,
                               tableStartLocationY - LineHeight * (labelIndex+2),
                               StringDesignatorArray[labelIndex],
                               false);
            // Default Label Text (Except last label)
            If labelIndex <> numLabels - 1 THEN BEGIN
                PlaceString(StartLocationX+900,
                                tableStartLocationY - LineHeight * (labelIndex+2),
                                'Label '+Format('%d', [labelIndex+1]),
                                false);
            END;
			// Location
			locStr := ' from H';
			If labelIndex <> numLabels - 1 Then Begin
				locStr := '25mm' + locStr;
				locStr := locStr + Copy(StringDesignatorArray[labelIndex],2,Length(StringDesignatorArray[labelIndex])-1);
			End Else Begin
				locStr := '50mm' + locStr + '1';
			End;
			PlaceString(StartLocationX+2800,
                                tableStartLocationY - LineHeight * (labelIndex+2),
                                locStr,
                                false);
             // Draw the separation bar above the label
             PlaceASchLine(StartLocationX,
                           tableStartLocationY - LineHeight * (labelIndex+1),
                           TableEndLocationX,
                           tableStartLocationY - LineHeight * (labelIndex+1));
             labelIndex := labelIndex - 1;
        End;
    End;
End;
{..............................................................................}

{..............................................................................}
Procedure CompileProject(Value);
Begin
    Project := GetWorkspace.DM_FocusedProject;

    // do a compile so the logical documents get expanded into physical documents.
    Project.DM_Compile;

    FileName := Project.DM_ProjectFullPath;
    FileName := ChangeFileExt(FileName,'.SCHPCK');
End;
{..............................................................................}


{..............................................................................}
{       _                      _   _           _______    _     _              }
{      | |                    | | | |         |__   __|  | |   | |             }
{      | |     ___ _ __   __ _| |_| |__  ___     | | __ _| |__ | | ___         }
{      | |    / _ \ '_ \ / _` | __| '_ \/ __|    | |/ _` | '_ \| |/ _ \        }
{      | |___|  __/ | | | (_| | |_| | | \__ \    | | (_| | |_) | |  __/        }
{      |______\___|_| |_|\__, |\__|_| |_|___/    |_|\__,_|_.__/|_|\___|        }
{                         __/ |                                                }
{                        |___/                                                 }
{..............................................................................}


{..............................................................................}
{        _____ ____  _   _ _   _ ______ _____ _______ _____ ____  _   _        }
{       / ____/ __ \| \ | | \ | |  ____/ ____|__   __|_   _/ __ \| \ | |       }
{      | |   | |  | |  \| |  \| | |__ | |       | |    | || |  | |  \| |       }
{      | |   | |  | | . ` | . ` |  __|| |       | |    | || |  | | . ` |       }
{      | |___| |__| | |\  | |\  | |___| |____   | |   _| || |__| | |\  |       }
{       \_____\____/|_| \_|_| \_|______\_____|  |_|  |_____\____/|_| \_|       }
{                         _______       ____  _      ______                    }
{                        |__   __|/\   |  _ \| |    |  ____|                   }
{                           | |  /  \  | |_) | |    | |__                      }
{                           | | / /\ \ |  _ <| |    |  __|                     }
{                           | |/ ____ \| |_) | |____| |____                    }
{                           |_/_/    \_\____/|______|______|                   }
{..............................................................................}
procedure DrawConnectionTable(Value);
Var
    bWireFound                   : Boolean;
    nWiresFound                  : Integer;
    nPosSpace                    : Integer;            // Position of the space in the pin designator
    MaxConnectionStringLength    : Integer;
    I, J, K, L                   : Integer;
    MultiPartCnt                 : Integer;
    
    WireNets                     : String;
    WireNet                      : String;
    WireNameMaxWidth             : Integer;             // Max width of the wire names.
    NetNameMaxWidth              : Integer;
    sWireName                    : String;

    Project                      : IProject;
    Comp                         : IComponent;
    MultiPart                    : IPart;
    Pin, PartPin                 : IPin;

    PinDisplayName               : ARRAY[0..50,0..100] OF String;
    sWireNets                    : ARRAY[0..1000,0..1] OF String;
    
    WireLocationX                : Integer;
    ConnectorLocationX           : Integer;            // Where to draw the connector (X pos)
Begin
/////////////////////////////////////////////////////////////
// Get the net connectivity into arrays so we can use them
/////////////////////////////////////////////////////////////
    Project := GetWorkspace.DM_FocusedProject;
    ConnectorCount:=0;
    UniqueNetCount:=0;
    For I := 0 to Project.DM_PhysicalDocumentCount - 1 Do
    Begin
        // Loop through each component on the schematic
        Doc := Project.DM_PhysicalDocuments(I);
        For J := 0 to Doc.DM_ComponentCount - 1 Do
        Begin
            NetSet:=False;
            Comp := Doc.DM_Components(J);

            if Comp.DM_PinCount >=100 then Begin
               ShowMessage('Too many pins for program');
               Exit;
            END;
            // Loop through each pin on the component
            For K := 0 to Comp.DM_PinCount - 1 Do
            Begin
                // Look at the net attached to the pin
                Pin := Comp.DM_Pins(K);
                If Pin.DM_FlattenedNetName <> '?' Then
                begin
                    (*
                        Store Wire info
                    *)
                    If Copy(Comp.DM_PhysicalDesignator, 1, 1) = 'W' THEN Begin
                        // If it is a multi-part component wire (i.e. multi-core wire)
                        if Comp.DM_SubPartCount > 1 Then
                        Begin
                            For MultiPartCnt := 0 to Comp.DM_SubPartCount - 1 Do
                            Begin
                                MultiPart := Comp.DM_SubParts(MultiPartCnt);
                                For L := 0 to MultiPart.DM_PinCount - 1 Do
                                Begin
                                    PartPin := MultiPart.DM_Pins(L);
                                    If PartPin.DM_FlattenedNetName <> '?' Then
                                    Begin
                                        // If there is a description in the Pin's Name, add it to the text shown
                                        If( IsAlpha( PartPin.DM_PinName) ) Then
                                        Begin
                                            sWireNets[nWiresFound,0] := MultiPart.DM_FullLogicalDesignator + ' - ' + PartPin.DM_PinName;
                                        End Else Begin
                                            sWireNets[nWiresFound,0] := MultiPart.DM_FullLogicalDesignator
                                        End;
                                        sWireNets[nWiresFound,1] := PartPin.DM_FlattenedNetName;
                                        nWiresFound := nWiresFound + 1;
                                    End;
                                End;
                            End;
                        End
                        // Not a multi-part component wire
                        Else
                        Begin
                            sWireNets[nWiresFound,0] := Comp.DM_PhysicalDesignator;
                            sWireNets[nWiresFound,1] := Pin.DM_FlattenedNetName;
                            // Increment the number of wires found
                            nWiresFound := nWiresFound + 1;
                        End;
                    END ELSE BEGIN
                        (*
                            Store PinDisplayName
                        *)
                         PinNum := Pin.DM_PinNumber;
                         if( IsAlpha( PinNum ) ) Then
                            PinNum := StrToInt(PinNum);
                         // Get the net name
                         // ZMZE-Bug - If the designator is NOT a number this will crash
                         If ( IsAlpha( PinNum ) ) Then
                         Begin
                             ShowMessage( 'Connector ' + Comp.DM_PhysicalDesignator + ' has invalid pin designator ' + PinNum );
                             ShowMessage( 'Connection Table did not generate correctly' );
                             Exit;
                         End;
                         PinNetArray[ConnectorCount,PinNum] := Pin.DM_FlattenedNetName;
                         // Record the Pin Name (the first word of the pin name)
                         if Pin.DM_PinName <> '' THEN BEGIN
                            // If there is a space in the pin name
                            nPosSPace := Pos( ' ', Pin.DM_PinName );
                            if nPosSpace > 0 THEN BEGIN
                                // Just get the first word
                                PinDisplayName[ConnectorCount,PinNum] := Copy(Pin.DM_PinName, 1, nPosSpace-1);
                            END ELSE BEGIN
                                // If there are no spaces, display the full text
                                PinDisplayName[ConnectorCount,PinNum] := Pin.DM_PinName;
                            END;
                         END
                         ELSE BEGIN
                            // If the pin name is empty display the component designator
                            PinDisplayName[ConnectorCount,PinNum] := Pin.Designator;
                         END;
                         NetSet:=False;
                         NetCount:=0;
                        (*
                            Store Net Name (no link to anything yet)
                        *)
                        While NetSet = FALSE Do
                        Begin
                            if NetArray[NetCount]='' then
                            begin
                               NetArray[NetCount] := Pin.DM_FlattenedNetName;
                               NetOccurances[NetCount] :=1;
                               NetSet:=true;
                               UniqueNetCount:=UniqueNetCount+1;//count of unique nets
                            END
                            else if NetArray[NetCount]=Pin.DM_FlattenedNetName then
                            begin
                                NetOccurances[NetCount] := NetOccurances[NetCount]+1;
                                NetSet:=true;
                            END;

                            NetCount := NetCount + 1;//count of unique nets

                            if NetCount >= 99 then
                            begin
                                NetSet := TRUE;
                                ShowMessage('Too Many Nets for the program');
                                EXIT;
                            END;
                        END;    // Store Net Name
                    END;        // Wire
                END;            // Net attached to each pin.
            END;                // Loop through each pin
            // If there was a net attached any pin on the connector
             if NetSet then
             Begin
                (*
                    Store the designator
                *)
                DesignatorArray[ConnectorCount] := Comp.DM_PhysicalDesignator;
                (*
                    Store the number of pins attached to the connector
                *)
                ComponentNumPinsArray[ConnectorCount] := Comp.DM_PinCount;
                // Increment the number of connectors (with nets attached) found
                ConnectorCount := ConnectorCount+1;
             end;
        End;
    End;

////////////////////////////
// Remove single ended nets (i.e. nets where the wire isn't attached at the far end)
////////////////////////////
    NetCountOut:=0;
    For I := 0 to UniqueNetCount - 1 Do
    Begin
        // If there is more than 1 side to the net, add the net to the out array
        If NetOccurances[I]>1 Then
        Begin
            NetArrayOut[NetCountOut] := NetArray[I];
            NetCountOut := NetCountOut+1;
        // If the net has wire attached, draw it in the connectivity table
        End Else BEGIN
            For J := 0 to nWireSFound - 1 Do
            Begin
                If sWireNets[J,1] = NetArray[I] Then
                Begin
                    NetArrayOut[NetCountOut] := NetArray[I];
                    NetCountOut := NetCountOut+1;
                    break;
                End;
            End;
        // If the wire has a flying lead
       // End Else BEGIN
         //   for J := 0 to 
        End;
    End;

////////////////////////////
// Concatenate multiple wires to a single net
////////////////////////////
    WireNameMaxWidth := 5;                // Min width, 5 chars (title)
    NetNameMaxWidth := 4;                 // Min width, 4 chars (title)
    For I := 0 to nWiresFound - 1 Do
    Begin
      For J := I+1 to nWiresFound - 1 Do
      Begin
          // If the net names match
          If( sWireNets[I, 1] = sWireNets[J, 1] ) Then
          Begin
              // If the wire isn't already there (multicore wire)
              If( pos(sWireNets[J, 0] + ', ', sWireNets[I, 0] + ', ') = 0 ) Then
              Begin
                  sWireNets[I, 0] := sWireNets[I, 0] + ', ' + sWireNets[J, 0];
                  sWireNets[J, 0] := '';
                  sWireNets[J, 1] := '';
               End;
          End;
          if( Length(sWireNets[I, 0]) > WireNameMaxWidth ) Then
                  WireNameMaxWidth := Length(sWireNets[I, 0]);
          if( Length(sWireNets[I, 1]) > NetNameMaxWidth ) Then
                  NetNameMaxWidth := Length(sWireNets[I, 1]);
      End;
    End;

////////////////////////////
// Draw the table
////////////////////////////
    if NetCountOut>0 then
    begin
        // Display the headers
        PlaceString(  NetTabBotLeftLocationX+100
                            ,(NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight))
                            ,'CONNECTION TABLE'
                            ,True);
        
        PlaceString(  NetTabBotLeftLocationX+100
                            ,(NetTabBotLeftLocationY+((NetCountOut+0)*LineHeight))
                            ,'Net'
                            ,True);
        WireLocationX := NetTabBotLeftLocationX+NetNameMaxWidth*PixelsPerChar*1.1 + 300;
        PlaceString(  WireLocationX + 100
                            ,(NetTabBotLeftLocationY+((NetCountOut+0)*LineHeight))
                            ,'Wire'
                            ,True);

        // Get the width of the connectivity table
        NetTabBotRightLocationX:=SchDoc.SheetSizeX * 3 / 5 / 10000;
        If ((NetTabBotRightLocationX > (SchDoc.SheetSizeX / 10000 - 8000)) and (Project.DM_PhysicalDocumentCount > 1)) Then
        Begin
            NetTabBotRightLocationX := SchDoc.SheetSizeX / 10000 - 8000;
        End;
        // Draw the outer rectangle (left -> right)
        PlaceASchLine(  NetTabBotLeftLocationX
                        ,(NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight))
                        ,NetTabBotRightLocationX
                        ,(NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight)));
        PlaceASchLine(  NetTabBotLeftLocationX
                        ,(NetTabBotLeftLocationY+((NetCountOut+0)*LineHeight))
                        ,NetTabBotRightLocationX
                        ,(NetTabBotLeftLocationY+((NetCountOut+0)*LineHeight)));
        // Where to draw the connectors
        ConnectorLocationX:= WireLocationX + WireNameMaxWidth * PixelsPerChar*1.1 + 300;
        // Loop through each connector
        For I := 0 to ConnectorCount - 1 Do
        Begin
             // Draw the separating (vertical) line between this connector and the next
             PlaceASchLine( ConnectorLocationX
                            ,NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight)
                            ,ConnectorLocationX
                            ,NetTabBotLeftLocationY);
            // Draw the connector name
             PlaceString( ConnectorLocationX+100
                                ,NetTabBotLeftLocationY+((NetCountOut+0)*LineHeight)
                                ,DesignatorArray[I]
                                ,True
                               );
             MaxConnectionStringLength:=length(DesignatorArray[I]);
             // Loop through each net
             For J := 0 to NetCountOut-1 Do
             Begin
                    WireNets :='';
                    // Loop through each pin on the connector
                    For K := 1 to ComponentNumPinsArray[I] Do
                    Begin
                         // If the pin is connected to this net
                         If NetArrayOut[J]=PinNetArray[I,K] Then
                         Begin
                              If WireNets <> '' Then
                                 WireNets := WireNets + ', ';
                              WireNets := WireNets + PinDisplayName[I,K];
                         End;
                    End;
                    // Draw the pins attached to the net
                    PlaceString(  ConnectorLocationX+100
                                        ,(NetTabBotLeftLocationY+((NetCountOut-J-1)*LineHeight))
                                        ,WireNets,
                                        False);
                    If MaxConnectionStringLength < Length(WireNets) Then
                    Begin
                       MaxConnectionStringLength := length(WireNets);
                    End;
             End;
             ConnectorLocationX := ConnectorLocationX + ( MaxConnectionStringLength * PixelsPerChar*1.1 ) + 200;

        end;
        // After the last connector draw the 'Notes' section
        PlaceASchLine(  ConnectorLocationX
                        ,NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight)
                        ,ConnectorLocationX
                        ,NetTabBotLeftLocationY
                        );
        PlaceString(ConnectorLocationX+100
                          ,NetTabBotLeftLocationY+((NetCountOut+0)*LineHeight)
                          ,'Notes'
                          ,True
                          );
        // Draw the nets & wires
        For I := 0 to NetCountOut - 1 Do
        Begin
            // Draw the wire names
            bWireFound := FALSE;
            FOR J := 0 TO nWireSFound - 1 DO BEGIN
                IF sWireNets[J,1] = NetArrayOut[I] THEN BEGIN
                    PlaceString(  WireLocationX + 100
                                        ,NetTabBotLeftLocationY+((NetCountOut-I-1)*LineHeight)
                                        ,sWireNets[J,0]
                                        ,FALSE
                                    );
                    bWireFound := TRUE;
                    Break;
                END;
            End;
            // Draw the net name
            PlaceString(  StartLocationX + 100
                                ,NetTabBotLeftLocationY+((NetCountOut-I-1)*LineHeight)
                                ,NetArrayOut[I]
                                ,False
                                );
            // Draw the horizontal line between each net
            PlaceASchLine(  NetTabBotLeftLocationX
                            ,NetTabBotLeftLocationY+((NetCountOut-I-1)*LineHeight)
                            ,NetTabBotRightLocationX
                            ,NetTabBotLeftLocationY+((NetCountOut-I-1)*LineHeight)
                            );
        End;
        // Separation line between Nets & Wires
        PlaceASchLine(  WireLocationX,
                        NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight),
                        WireLocationX,
                        NetTabBotLeftLocationY
                        );
        // Draw the left & right end vertical lines
        PlaceASchLine(  NetTabBotLeftLocationX
                        ,NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight)
                        ,NetTabBotLeftLocationX
                        ,NetTabBotLeftLocationY
                        );
        PlaceASchLine(  NetTabBotRightLocationX
                        ,NetTabBotLeftLocationY+((NetCountOut+1)*LineHeight)
                        ,NetTabBotRightLocationX
                        ,NetTabBotLeftLocationY
                        );
    end;
End;
{..............................................................................}

{..............................................................................}

Procedure CreateConnectionTable;
Var
    I       : Integer;
    SL1,SL2 : TStringList;
    L1      : TList;
Begin

    // Check if schematic server exists or not.
    If SchServer = Nil Then Exit;
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then Exit;

    // BeginHourGlass;
    PackingList := TStringList.Create;

    //Store components here.
    CompsList := TStringList.Create;
    CompsList.Sorted        := False;
    CompsList.CaseSensitive := False;

    CompileProject(1);
    DrawConnectionTable(2);

    If CompsList.Count > 0 Then
    Begin
        //Go through pin lists and comp lists and free them respectively...
        For I := 0 to CompsList.Count - 1 Do
        Begin
            L1 := TList(CompsList.Objects[I]);
            L1.Free;
        End;
    End;
    CompsList.Free;

    PackingList.Free;
    EndHourGlass;
End;
{..............................................................................}

{..............................................................................}
Interface
Type
  CableGenForm = class(TForm)
    CheckBoxGenerateBOM      : TCheckBox;
    CheckBoxConnectionTable  : TCheckBox;
    CheckBoxCreateLabels     : TCheckBox;
    CheckBoxHideComments     : TCheckBox;
    ButtonBegin              : TButton;

    procedure CheckBoxGenerateBOMClick     (Sender: TObject);
    procedure CheckBoxConnectionTableClick (Sender: TObject);
    procedure CheckBoxCreateLabelsClick    (Sender: TObject);
    procedure CheckBoxHideCommentsClick    (Sender: TObject);
    procedure ButtonBeginClick             (Sender: TObject);
  End;

Var
    CableGenForm : TCableGenForm;
{..............................................................................}


{..............................................................................}
Procedure TCableGenForm.CheckBoxGenerateBOMClick(Sender: TObject);
Begin
    //
End;
{..............................................................................}

{..............................................................................}
Procedure TCableGenForm.CheckBoxConnectionTableClick(Sender: TObject);
Begin
    //
End;
{..............................................................................}

{..............................................................................}
Procedure TCableGenForm.CheckBoxCreateLabelsClick(Sender: TObject);
Begin
    //
End;
{..............................................................................}

{..............................................................................}
Procedure TCableGenForm.CheckBoxHideCommentsClick(Sender: TObject);
Begin
    //
End;
{..............................................................................}

{..............................................................................}
Procedure TCableGenForm.ButtonBeginClick(Sender: TObject);
Var
    Project   : IProject;
    SchDoc    : ISch_Document;
Begin
    // Check whether multi-sheets have been used.
    Project := GetWorkspace.DM_FocusedProject;
    If Project = Nil Then Exit;
    Project.DM_Compile;
    If Project.DM_PhysicalDocumentCount > 1 Then
    Begin
        ShowMessage( 'Error: multiple schematic sheets detected. Reduce design to single sheet' );
        Exit;
    End;
    // Change text to running
    ButtonBegin.Caption := 'Running...';
    if CheckBoxGenerateBOM.State = cbChecked THEN
        CreateBOM;
    if CheckBoxConnectionTable.State = cbChecked THEN
        CreateConnectionTable;
    if CheckBoxCreateLabels.State    = cbChecked THEN
        CreateLabels;
    if CheckBoxHideComments.State = cbChecked THEN
        HideComments;
    // Call to refresh the schematic document.
    SchServer.GetCurrentSchDocument.GraphicallyInvalidate;
    // Finish
    ShowMessage('Finished Processing');
    Close;
End;
{..............................................................................}

{..............................................................................}
{                  _____  _    _ _   _     _    _ __  __ _____                 }
{                 |  __ \| |  | | \ | |   | |  | |  \/  |_   _|                }
{                 | |__) | |  | |  \| |   | |__| | \  / | | |                  }
{                 |  _  /| |  | | . ` |   |  __  | |\/| | | |                  }
{                 | | \ \| |__| | |\  |   | |  | | |  | |_| |_                 }
{                 |_|  \_\\____/|_| \_|   |_|  |_|_|  |_|_____|                }
{..............................................................................}
Procedure RunHMI;
Begin
    If SchServer = Nil Then Exit;
    SchDoc := SchServer.GetCurrentSchDocument;
    If SchDoc = Nil Then Exit;

    // check if it is a schematic library document
    If Not SchDoc.IsLibrary Then Exit;
    // Setup the default checked/unchedked states
    If TableExists('BILL OF MATERIALS') THEN
       CheckBoxGenerateBOM.State := cbUnChecked;
    If TableExists('CONNECTION TABLE') THEN
       CheckBoxConnectionTable.State := cbUnChecked;
    If TableExists('LABELS') THEN
       CheckBoxCreateLabels.State := cbUnChecked;
    // Run HMI
    CableGenForm.ShowModal;
End;
{..............................................................................}

