(**

  This module contains often used code for use through out this application.

  @Version 1.0
  @Author  David Hoyle
  @Date    30 Dec 2017

**)
unit ITHelper.TestingHelperUtils;

interface

{$INCLUDE 'CompilerDefinitions.inc'}

Uses
  SysUtils,
  {$IFNDEF CONSOLE_TESTRUNNER} ToolsAPI, {$ENDIF}
  Windows,
  Graphics,
  Classes,
  Contnrs,
  Menus;

Type
  (** An enumerate to define the type of information to be returned from
      GetProcInfo. **)
  TProcInfoType = (pitEXE, pitParam, pitDir);

  {$IFNDEF CONSOLE_TESTRUNNER}
  (** This class defined a custom message for the IDE. **)
  TCustomMessage = Class(TInterfacedObject, IOTACustomMessage, INTACustomDrawMessage)
  {$IFDEF D2005} Strict {$ENDIF} Private
    FMsg : String;
    FFontName   : String;
    FForeColour : TColor;
    FStyle : TFontStyles;
    FBackColour : TColor;
    FMessagePntr : Pointer;
  {$IFDEF D2005} Strict {$ENDIF} Protected
    Procedure SetForeColour(Const iColour : TColor);
  Public
    Constructor Create(Const strMsg : String; Const FontName : String;
      Const ForeColour : TColor = clBlack; Const Style : TFontStyles = [];
      Const BackColour : TColor = clWindow);
    (**
      This allows the colour of the font to be updated.
      @precon  None.
      @postcon Updates the font colour of the message.
      @return  a TColor
    **)
    Property ForeColour : TColor Write SetForeColour;
    (**
      This property returns the message pointer to be used as the parent for
      sub messages.
      @precon  None.
      @postcon Returns the message pointer to be used as the parent for
      @return  a Pointer
    **)
    Property MessagePntr: Pointer Read FMessagePntr Write FMessagePntr;
    // IOTACustomMessage
    Function GetColumnNumber: Integer;
    Function GetFileName: String;
    Function GetLineNumber: Integer;
    Function GetLineText: String;
    Procedure ShowHelp;
    // INTACustomDrawMessage
    Function CalcRect(Canvas: TCanvas; MaxWidth: Integer; Wrap: Boolean): TRect;
    Procedure Draw(Canvas: TCanvas; Const Rect: TRect; Wrap: Boolean);
  End;
  {$ENDIF}

  (** An enumerate to defien which message should be cleared from the IDE
      message window. **)
  TClearMessage = (cmCompiler, cmSearch, cmTool, cmGroup);
  (** A set of the above message types. **)
  TClearMessages = Set of TClearMessage;

  (** A record to hold version information. **)
  TVersionInfo = Record
    iMajor  : Integer;
    iMinor  : Integer;
    iBugfix : Integer;
    iBuild  : Integer;
  End;

  {$IFNDEF CONSOLE_TESTRUNNER}
  Function ProjectGroup: IOTAProjectGroup;
  Function ActiveProject : IOTAProject;
  Function ProjectModule(Const Project : IOTAProject) : IOTAModule;
  Function ActiveSourceEditor : IOTASourceEditor;
  Function SourceEditor(Const Module : IOTAMOdule) : IOTASourceEditor;
  Function EditorAsString(Const SourceEditor : IOTASourceEditor) : String;
  Procedure OutputText(Const Writer : IOTAEditWriter; Const iIndent : Integer; Const strText : String);
  Function GetProjectName(Const Project : IOTAProject) : String;
  Procedure OutputMessage(Const strText : String); Overload;
  Procedure OutputMessage(Const strFileName, strText, strPrefix : String; Const iLine,
    iCol : Integer); Overload;
  Function ExpandMacro(Const strPath : String; Const Project : IOTAProject) : String;
  {$IFDEF D0006}
  Procedure OutputMessage(Const strText : String; Const strGroupName : String); Overload;
  {$ENDIF}
  {$IFDEF D0006}
  Procedure ShowMessages(Const strGroupName : String = '');
  {$ENDIF}
  Function AddMsg(Const strText: String; Const boolGroup, boolAutoScroll: Boolean;
    Const strFontName: String; Const iForeColour: TColor; Const fsStyle: TFontStyles;
    Const iBackColour: TColor = clWindow; Const ptrParent: Pointer = Nil): Pointer;
  Function AddImageToIDE(Const strImageName : String; Const iMaskColour : TColor) : Integer;
  Function CreateMenuItem(Const strName, strCaption, strParentMenu : String;
    Const ClickProc, UpdateProc : TNotifyEvent; Const boolBefore, boolChildMenu : Boolean;
    Const strShortCut : String; Const iMaskColour : TColor = clLime) : TMenuItem;
  Procedure PatchActionShortcuts(Sender : TObject);
  Procedure ClearMessages(Const Msg : TClearMessages);
  Procedure ShowHelperMessages(Const boolITHGroup : Boolean);
  {$ENDIF}
  Procedure BuildNumber(Var VersionInfo : TVersionInfo);
  Function GetProcInfo(Const strText : String; Const ProcInfoType : TProcInfoType) : String;
  Function ResolvePath(Const strFName, strPath : String) : String;
  Function Actions : TObjectList;
  Function ITHHTMLHelpFile(Const strContext : String = '') : String;

{$IFNDEF D2005}
Const
  (** HTML Constant to display a Topic **)
  HH_DISPLAY_TOPIC = $0000;
  (** HTML Constant to display a the Table of Contents **)
  HH_DISPLAY_TOC = $0001;
  (** HTML Constant to close all HTML files **)
  HH_CLOSE_ALL = $0012;

Function HtmlHelp(hwndCaller: HWND; pszFile: PChar; uCommand: UINT;
  dwData: DWORD): HWND; StdCall; external 'HHCTRL.OCX' Name 'HtmlHelpA';
{$ENDIF}

Implementation

Uses
  Forms,
  Controls,
  ActnList,
  ComCtrls;

ResourceString
  (** This is a resourcestring for the message tab name. **)
  strITHelperGroup = 'ITHelper Messages';

Var
  (** A private variable to is used to hold action reference so that they
      can be removed from the IDE. **)
  FOTAActions : TObjectList;

Const
  strBuild = 'Build';

(**

  This function returns either the EXE, Params or Working Directory of the external tool information. 
  strText should be 3 fields of information, EXE, Params and Working Dir separated by pipes (|).

  @precon  None.
  @postcon Returns either the EXE, Params or Working Directory of the external tool information.

  @param   strText      as a String as a constant
  @param   ProcInfoType as a TProcInfoType as a constant
  @return  a String

**)
Function GetProcInfo(Const strText : String; Const ProcInfoType : TProcInfoType) : String;

Var
  iPos : Integer;
  strNewText : String;

Begin
  Result := '';
  strNewText := strText;
  iPos := Pos('|', strNewText);
  If iPos > 0 Then
    Begin
      Result := Copy(strNewText, 1, iPos - 1);
      If ProcInfoType = pitEXE Then
        Exit;
      Delete(strNewText, 1, iPos);
      iPos := Pos('|', strNewText);
      If iPos > 0 Then
        Begin
          Result := Copy(strNewText, 1, iPos - 1);
          If ProcInfoType = pitParam Then Exit;
          Delete(strNewText, 1, iPos);
          Result := strNewText;
        End;
    End;
End;

{$IFNDEF CONSOLE_TESTRUNNER}
(**

  This method displays the package`s message tab.

  @precon  None.
  @postcon Displays the package`s message tab.

  @param   boolITHGroup as a Boolean as a constant

**)
Procedure ShowHelperMessages(Const boolITHGroup : Boolean);

Var
  G : IOTAMessageGroup;

Begin
  With (BorlandIDEServices As IOTAMessageServices) Do
    Begin
      G := Nil;
      If boolITHGroup Then
        G := GetGroup(strITHelperGroup)
      Else
        G := GetGroup(strBuild);
      If Application.MainForm.Visible Then
        ShowMessageView(G);
    End;
End;

(**

  This function returns a project name with the DPRP or DPK extension.

  @precon  Project must be a valid instance of a IOTAProject interface.
  @postcon Returns a project name with the DPRP or DPK extension.

  @param   Project as an IOTAProject as a constant
  @return  a String

**)
Function GetProjectName(Const Project : IOTAProject) : String;

Var
  i : Integer;
  strExt: String;

Begin
  Result := ExtractFileName(Project.FileName);
  For i := 0 To Project.ModuleFileCount - 1 Do
    Begin
      strExt := LowerCase(ExtractFileExt(Project.ModuleFileEditors[i].FileName));
      If (strExt = '.dpr') Or (strExt = '.dpk') Then
        Begin
          Result := ChangeFileExt(Result, strExt);
          Break;
        End;
    End;
End;

(**

  This function returns the passed path / filename with any of the below macros expanded. {$PROJPATH$} 
  The project path including the trailing backslash {$PROJDRIVE$} The project drive including the colon.

  @precon  Project must be a valid instance.
  @postcon Returns the passed path / filename with any macros expanded.

  @param   strPath as a String as a constant
  @param   Project as an IOTAProject as a constant
  @return  a String

**)
Function ExpandMacro(Const strPath : String; Const Project : IOTAProject) : String;

Begin
  Result := strPath;
  Result := StringReplace(Result, '{$PROJPATH$}', ExtractFilePath(Project.FileName),
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{$PROJDRIVE$}', ExtractFileDrive(Project.FileName),
    [rfReplaceAll, rfIgnoreCase]);
End;
{$ENDIF}

(**

  This function resolve the path of the file name with respect to the
  path given to produce a full path to the file name.

  @precon  None.
  @postcon Resolve the path of the file name with respect to the
           path given to produce a full path to the file name

  @param   strFName as a String as a constant
  @param   strPath  as a String as a constant
  @return  a String

**)
Function ResolvePath(Const strFName, strPath : String) : String;

Var
  strFileName : String;
  strPathName :String;

Begin
  strFileName := strFName;
  strPathName := strPath;
  If strFileName[1] = '.' Then
    Begin
      Repeat
        If Copy(strFileName, 1, 2) = '.\' Then
          strFileName := Copy(strFileName, 3, Length(strFileName) - 2);
        If Copy(strFileName, 1, 3) = '..\' Then
          Begin
            strFileName := Copy(strFileName, 4, Length(strFileName) - 3);
            strPathName := ExtractFilePath(Copy(strPathName, 1, Length(strPathName) - 1));
          End;
      Until strFileName[1] <> '.';
      Result := strPathName + strFileName;
    End Else
    Begin
      If ExtractFilePath(strFileName) = '' Then
        Result := strPathName + strFileName
      Else
        Result := strFileName;
    End;
End;

(**

  This method extracts the Major, Minor, Bugfix and Build version numbers from
  this modules resource information.

  @precon  None.
  @postcon Returns the version information in the var parameter.

  @param   VersionInfo as a TVersionInfo as a reference

**)
Procedure BuildNumber(Var VersionInfo: TVersionInfo);

Var
  VerInfoSize: DWORD;
  VerInfo: Pointer;
  VerValueSize: DWORD;
  VerValue: PVSFixedFileInfo;
  Dummy: DWORD;
  strBuffer: Array [0 .. MAX_PATH] Of Char;

Begin
  GetModuleFileName(hInstance, strBuffer, MAX_PATH);
  VerInfoSize := GetFileVersionInfoSize(strBuffer, Dummy);
  If VerInfoSize <> 0 Then
    Begin
      GetMem(VerInfo, VerInfoSize);
      Try
        GetFileVersionInfo(strBuffer, 0, VerInfoSize, VerInfo);
        VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
        With VerValue^ Do
          Begin
            VersionInfo.iMajor := dwFileVersionMS Shr 16;
            VersionInfo.iMinor := dwFileVersionMS And $FFFF;
            VersionInfo.iBugfix := dwFileVersionLS Shr 16;
            VersionInfo.iBuild := dwFileVersionLS And $FFFF;
          End;
      Finally
        FreeMem(VerInfo, VerInfoSize);
      End;
    End;
End;

{$IFNDEF CONSOLE_TESTRUNNER}
(**

  This method outputs the given message to the IDEs message window.

  @precon  None.
  @postcon Outputs the given message to the IDEs message window.

  @param   strText as a String

**)
Procedure OutputMessage(Const strText : String);

Begin
  (BorlandIDEServices As IOTAMessageServices).AddTitleMessage(strText);
End;

(**

  This method outputs the given message with file and cursor position to the
  IDEs message window so that if the message is double clicked then the position
  in the file will be displayed by the IDE.

  @precon  None.
  @postcon Displays a tool message in the IDE.

  @param   strFileName as a String
  @param   strText     as a String
  @param   strPrefix   as a String
  @param   iLine       as an Integer
  @param   iCol        as an Integer

**)
Procedure OutputMessage(Const strFileName, strText, strPrefix : String; Const iLine, iCol : Integer);

Begin
  (BorlandIDEServices As IOTAMessageServices).AddToolMessage(strFileName,
    strText, strPrefix, iLine, iCol);
End;

{$IFDEF D0006}
(**

  This method outputs the given message to the named message group.

  @precon  None.
  @postcon Outputs the given message to the named message group.

  @param   strText      as a String as a constant
  @param   strGroupName as a String as a constant

**)
Procedure OutputMessage(Const strText : String; Const strGroupName : String);

Var
  Group : IOTAMessageGroup;

Begin
  With (BorlandIDEServices As IOTAMessageServices) Do
    Begin
      Group := GetGroup(strGroupName);
      If Group = Nil Then
        Group := AddMessageGroup(strGroupName);
      AddTitleMessage(strText, Group);
    End;
End;
{$ENDIF}

(**

  This method clears the IDE message window of the given message types.

  @precon  None.
  @postcon Clears the IDE message window of the given message types.

  @param   Msg as a TClearMessages as a constant

**)
Procedure ClearMessages(Const Msg : TClearMessages);

Var
  MS : IOTAMessageServices;
  Group : IOTAMessageGroup;
  
Begin
  If Supports(BorlandIDEServices, IOTAMessageServices, MS) Then
    Begin
      //: @bug Does not clear ITHelper custom messages from its own message group.
      If cmCompiler In Msg Then
        MS.ClearCompilerMessages;
      If cmSearch In Msg Then
        MS.ClearSearchMessages;
      If cmTool In Msg Then
        MS.ClearToolMessages;
      If cmGroup In Msg Then
        Begin
          Group := MS.GetGroup(strITHelperGroup);
          If Assigned(Group) Then
            Begin
              MS.ClearMessageGroup(Group);
              MS.ClearToolMessages(Group);
            End;
        End;
    End;
End;

{$IFDEF D0006}
(**

  This method displays the named message group in the IDE. If no group is provided then the main message 
  window is displayed.

  @precon  None.
  @postcon Displays the named message group in the IDE.

  @param   strGroupName as a String as a constant

**)
Procedure ShowMessages(Const strGroupName : String = '');

Var
  MS : IOTAMessageServices;
  G : IOTAMessageGroup;

Begin
  If Supports(BorlandIDEServices, IOTAMessageServices, MS) Then
    Begin
      G := MS.GetGroup(strGroupName);
      MS.ShowMessageView(G);
    End;
End;
{$ENDIF}

(**

  This method returns the current project group reference or nil if there is no
  project group open.

  @precon  None.
  @postcon Returns the current project group reference or nil if there is no
           project group open.

  @return  an IOTAProjectGroup

**)
Function ProjectGroup: IOTAProjectGroup;

Var
  AModuleServices: IOTAModuleServices;
  AModule: IOTAModule;
  i: integer;
  AProjectGroup: IOTAProjectGroup;

Begin
  Result := Nil;
  AModuleServices := (BorlandIDEServices as IOTAModuleServices);
  For i := 0 To AModuleServices.ModuleCount - 1 Do
    Begin
      AModule := AModuleServices.Modules[i];
      If (AModule.QueryInterface(IOTAProjectGroup, AProjectGroup) = S_OK) Then
       Break;
    End;
  Result := AProjectGroup;
end;

(**

  This method returns the active project in the IDE else returns Nil if there is
  no active project.

  @precon  None.
  @postcon Returns the active project in the IDE else returns Nil if there is
           no active project.

  @return  an IOTAProject

**)
Function ActiveProject : IOTAProject;

var
  G : IOTAProjectGroup;

Begin
  Result := Nil;
  G := ProjectGroup;
  If G <> Nil Then
    Result := G.ActiveProject;
End;

(**

  This method returns the project module for the given project.

  @precon  Project must be a valid instance.
  @postcon Returns the project module for the given project.

  @param   Project as an IOTAProject as a constant
  @return  an IOTAModule

**)
Function ProjectModule(Const Project : IOTAProject) : IOTAModule;

Var
  AModuleServices: IOTAModuleServices;
  AModule: IOTAModule;
  i: integer;
  AProject: IOTAProject;

Begin
  Result := Nil;
  AModuleServices := (BorlandIDEServices as IOTAModuleServices);
  For i := 0 To AModuleServices.ModuleCount - 1 Do
    Begin
      AModule := AModuleServices.Modules[i];
      If (AModule.QueryInterface(IOTAProject, AProject) = S_OK) And
        (Project = AProject) Then
        Break;
    End;
  Result := AProject;
End;

(**

  This method returns the Source Editor interface for the active source editor
  else returns nil.

  @precon  None.
  @postcon Returns the Source Editor interface for the active source editor
           else returns nil.

  @return  an IOTASourceEditor

**)
Function ActiveSourceEditor : IOTASourceEditor;

Var
  CM : IOTAModule;

Begin
  Result := Nil;
  If BorlandIDEServices = Nil Then
    Exit;
  CM := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  Result := SourceEditor(CM);
End;

(**

  This method returns the source editor for the given module.

  @precon  Module must be a valid instance.
  @postcon Returns the source editor for the given module.

  @param   Module as an IOTAMOdule as a constant
  @return  an IOTASourceEditor

**)
Function SourceEditor(Const Module : IOTAMOdule) : IOTASourceEditor;

Var
  iFileCount : Integer;
  i : Integer;

Begin
  Result := Nil;
  If Module = Nil Then Exit;
  With Module Do
    Begin
      iFileCount := GetModuleFileCount;
      For i := 0 To iFileCount - 1 Do
        If GetModuleFileEditor(i).QueryInterface(IOTASourceEditor,
          Result) = S_OK Then
          Break;
    End;
End;

(**

  This method returns the editor code as a string from the given source editor reference.

  @precon  SourceEditor must be a valid instance.
  @postcon returns the editor code as a string from the given source editor reference.

  @param   SourceEditor as an IOTASourceEditor as a constant
  @return  a String

**)
Function EditorAsString(Const SourceEditor : IOTASourceEditor) : String;

Const
  iBufferSize : Integer = 1024;

Var
  Reader : IOTAEditReader;
  iRead : Integer;
  iPosition : Integer;
  strBuffer : AnsiString;

Begin
  Result := '';
  Reader := SourceEditor.CreateReader;
  Try
    iPosition := 0;
    Repeat
      SetLength(strBuffer, iBufferSize);
      iRead := Reader.GetText(iPosition, PAnsiChar(strBuffer), iBufferSize);
      SetLength(strBuffer, iRead);
      Result := Result + String(strBuffer); //: @bug Needs to be Unicode compliant!
      Inc(iPosition, iRead);
    Until iRead < iBufferSize;
  Finally
    Reader := Nil;
  End;
End;

(**

  This method adds a custom message to the IDE and returns a POINTER to that message.

  @precon  ptrParent must be a POINTER to another message not a reference.
  @postcon Adds a custom message to the IDE and returns a POINTER to that message.

  @param   strText        as a String as a constant
  @param   boolGroup      as a Boolean as a constant
  @param   boolAutoScroll as a Boolean as a constant
  @param   strFontName    as a String as a constant
  @param   iForeColour    as a TColor as a constant
  @param   fsStyle        as a TFontStyles as a constant
  @param   iBackColour    as a TColor as a constant
  @param   ptrParent      as a Pointer as a constant
  @return  a Pointer

**)
Function AddMsg(Const strText: String; Const boolGroup, boolAutoScroll: Boolean;
  Const strFontName: String; Const iForeColour: TColor; Const fsStyle: TFontStyles;
  Const iBackColour: TColor = clWindow; Const ptrParent: Pointer = Nil): Pointer;

Var
  M: TCustomMessage;
  {$IFDEF D0006}
  G: IOTAMessageGroup;
  {$ENDIF}

Begin
  With (BorlandIDEServices As IOTAMessageServices) Do
    Begin
      M := TCustomMessage.Create(strText, strFontName, iForeColour, fsStyle, iBackColour);
      Result := M;
      If ptrParent = Nil Then
        Begin
          {$IFDEF D0006}
          G := Nil;
          If boolGroup Then
            G := AddMessageGroup(strITHelperGroup)
          Else
            G := GetMessageGroup(0);
          {$IFDEF D2005}
          If boolAutoScroll <> G.AutoScroll Then
            G.AutoScroll := boolAutoScroll;
          {$ENDIF}
          {$IFDEF D2005}
          M.MessagePntr := AddCustomMessagePtr(M As IOTACustomMessage, G);
          {$ELSE}
          AddCustomMessage(M As IOTACustomMessage, G);
          {$ENDIF}
          {$ELSE}
          AddCustomMessage(M As IOTACustomMessage);
          {$ENDIF}
        End
      Else
        {$IFDEF D2005}
        AddCustomMessage(M As IOTACustomMessage, ptrParent);
        {$ELSE}
        AddCustomMessage(M As IOTACustomMessage);
        {$ENDIF}
    End;
End;

(**

  This method outputs text to the given IOTAEditWriter interface.

  @precon  Writer must be a valid instance.
  @postcon Outputs text to the given IOTAEditWriter interface.

  @param   Writer  as an IOTAEditWriter as a constant
  @param   iIndent as an Integer as a constant
  @param   strText as a String as a constant

**)
Procedure OutputText(Const Writer : IOTAEditWriter; Const iIndent : Integer; Const strText : String);

Begin
  {$IFNDEF D2009}
  Writer.Insert(PAnsiChar(StringOfChar(#32, iIndent) + strText));
  {$ELSE}
  Writer.Insert(PAnsiChar(AnsiString(StringOfChar(#32, iIndent) + strText)));
  {$ENDIF}
End;

{ TCustomMessage Methods }

(**

  Returns the column number.

  GetColumnNumber returns the column number in the associated source file. When
  the user double-clicks the message in the message view, the IDE shows the
  source file and positions the cursor at the location given by the line number
  and column number.

  @precon  None.
  @postcon We does use this in this implementation but you would return the
           column number for your message here.

  @return  an Integer

**)
Function TCustomMessage.GetColumnNumber: Integer;

Begin
  Result := 0;
End;

(**

  Returns the source file name.

  GetFileName returns the complete path to the associated source file. When the
  user double-clicks the message in the message view, the IDE shows the source
  file and positions the cursor at the location given by the line number and
  column number.

  Return an empty string if the message is not associated with a source file.

  @precon  None.
  @postcon We return an empty string for this implementation othereise you would
           return the full name and path of the file associated with the
           message.

  @return  a String

**)
Function TCustomMessage.GetFileName: String;

Begin
  Result := '';
End;

(**

  Returns the line number.

  GetLineNumber returns the line number in the associated source file. When the
  user double-clicks the message in the message view, the IDE shows the source
  file and positions the cursor at the location given by the line number and
  column number.

  @precon  None.
  @postcon We return 0 for out implementation but you would return the line
           number of the message here.

  @return  an Integer

**)
Function TCustomMessage.GetLineNumber: Integer;

Begin
  Result := 0;
End;

(**

  Returns the text of the message.

  GetLineText returns the text of the custom message.

  @precon  None.
  @postcon Here we return the message

  @return  a String

**)
Function TCustomMessage.GetLineText: String;

Begin
  Result := FMsg;
End;

(**

  This is a setter method for the ForeColour property.

  @precon  None.
  @postcon Sets the message fore colour.

  @param   iColour as a TColor as a constant

**)
Procedure TCustomMessage.SetForeColour(Const iColour: TColor);

Begin
  If FForeColour <> iColour Then
    FForeColour := iColour;
End;

(**

  Provides help for the message.

  When the user selects the custom message and presses the F1 key, the IDE calls
  the ShowHelp function to provide help to the user.

  @precon  None.
  @postcon Not implemented but you would display the custom help for the message
           here.

**)
Procedure TCustomMessage.ShowHelp;

Begin
  //
End;

(**

  This is the constructor for the TCustomMessage class.

  @precon  None.
  @postcon Creates a custom message with fore and background colours and font styles.

  @param   strMsg     as a String as a constant
  @param   FontName   as a String as a constant
  @param   ForeColour as a TColor as a constant
  @param   Style      as a TFontStyles as a constant
  @param   BackColour as a TColor as a constant

**)
Constructor TCustomMessage.Create(Const strMsg: String; Const FontName: String;
  Const ForeColour: TColor = clBlack; Const Style: TFontStyles = [];
  Const BackColour: TColor = clWindow);

Const
  strValidChars: Set Of AnsiChar = [#10, #13, #32 .. #128];

Var
  i: Integer;
  iLength: Integer;

Begin
  SetLength(FMsg, Length(strMsg));
  iLength := 0;
  For i := 1 To Length(strMsg) Do
    {$IFDEF D2009}
    If CharInSet(strMsg[i], strValidChars) Then
    {$ELSE}
    If strMsg[i] In strValidChars Then
    {$ENDIF}
      Begin
        FMsg[iLength + 1] := strMsg[i];
        Inc(iLength);
      End;
  SetLength(FMsg, iLength);
  FFontName := FontName;
  FForeColour := ForeColour;
  FStyle := Style;
  FBackColour := BackColour;
  FMessagePntr := Nil;
End;

(**

  Calculates the bounding rectangle. CalcRect computes the bounding box required by the entire message. 
  The message view itself always displays messages in a single line of a fixed size. If the user hovers 
  the cursor over a long message, a tooltip displays the entire message. CalcRect returns the size of the
  tooltip window. The Canvas parameter is the canvas for drawing the message. The MaxWidth parameter is 
  the maximum allowed width of the bounding box (e.g., the screen width). The Wrap Parameter is true to 
  word-wrap the message onto multiple lines. It is false if the message must be kept to one line. The 
  Return value is the bounding rectangle required by the message.

  @precon  None.
  @postcon We calculate the size of the message here.

  @param   Canvas   as a TCanvas as a constant
  @param   MaxWidth as an Integer as a constant
  @param   Wrap     as a Boolean as a constant
  @return  a TRect

**)
Function TCustomMessage.CalcRect(Canvas: TCanvas; MaxWidth: Integer; Wrap: Boolean): TRect;

Begin
  Canvas.Font.Name := FFontName;
  Canvas.Font.Style := FStyle;
  Result := Canvas.ClipRect;
  Result.Bottom := Result.Top + Canvas.TextHeight('Wp');
  Result.Right := Result.Left + Canvas.TextWidth(FMsg);
End;

(**

  Draws the message. Draw draws the message in the message view window or in a tooltip window. The Canvas
  parameter is the canvas on which to draw the message. The Rect parameter is the bounding box for the 
  message. If you draw outside this rectangle, you might obscure other messages. The Wrap Parameter is 
  true to word-wrap the message on multiple lines or false to keep the message on a single line. The 
  message view window always uses a single line for each message, but the tooltip (which the user sees by
  hovering the cursor over the message) can be multiple lines. The drawing objects (brush, pen, and font
  ) are set up appropriately for drawing messages that look like all the other messages in the message 
  view. In particular, the brush and font colors are set differently depending on whether the message is 
  selected. A custom-drawn message should not alter the colors or other graphic parameters without good 
  reason.

  @precon  None.
  @postcon This is where we draw the message on the canvas.

  @param   Canvas as a TCanvas as a constant
  @param   Rect   as a TRect as a constant
  @param   Wrap   as a Boolean as a constant

**)
Procedure TCustomMessage.Draw(Canvas: TCanvas; Const Rect: TRect; Wrap: Boolean);

Begin
  If Canvas.Brush.Color = clWindow Then
    Begin
      Canvas.Font.Color := FForeColour;
      Canvas.Brush.Color := FBackColour;
      Canvas.FillRect(Rect);
    End;
  Canvas.Font.Name := FFontName;
  Canvas.Font.Style := FStyle;
  Canvas.TextOut(Rect.Left, Rect.Top, FMsg);
End;

(**

  This method adds an image from the projects resource (bitmap) to the IDEs image list. The image name in
  the resource must end in Image as this is appended to the given name. An integer for the position of 
  that image in the IDEs image list is returned.

  @precon  None.
  @postcon The named image is loaded from the projects resource and put into the IDEs image list and its
           index returned.

  @Note    Different technicals are used for the different IDE version.
  @Note    The way described in Delphi 2010s ToppsAPI file causes an exception and there is not used.

  @param   strImageName as a String as a constant
  @param   iMaskColour  as a TColor as a constant
  @return  an Integer

**)
Function AddImageToIDE(Const strImageName : String; Const iMaskColour : TColor) : Integer;

Var
  NTAS : INTAServices;
  ilImages : TImageList;
  BM : TBitMap;

begin
  Result := -1;
  If FindResource(hInstance, PChar(strImageName + 'Image'), RT_BITMAP) > 0 Then
    Begin
      NTAS := (BorlandIDEServices As INTAServices);
      // Create image in IDE image list
      ilImages := TImageList.Create(Nil);
      Try
        BM := TBitMap.Create;
        Try
          BM.LoadFromResourceName(hInstance, strImageName + 'Image');
          {$IFDEF D2005}
          ilImages.AddMasked(BM, iMaskColour);
          // EXCEPTION: Operation not allowed on sorted list
          // Result := NTAS.AddImages(ilImages, 'OTATemplateImages');
          Result := NTAS.AddImages(ilImages);
          {$ELSE}
          Result := NTAS.AddMasked(BM, iMaskColour);
          {$ENDIF}
        Finally
          BM.Free;
        End;
      Finally
        ilImages.Free;
      End;
    End;
end;

(**

  This method finds and returns a reference to the named menu item in the IDE else returns nil.

  @precon  None.
  @postcon Finds and returns a reference to the named menu item in the IDE else returns nil.

  @param   strParentMenu as a String as a constant
  @return  a TMenuItem

**)
function FindMenuItem(Const strParentMenu : String): TMenuItem;

  (**

    This method iterates the submenus of a main menu item.

    @precon  Menu must be a valid menu item.
    @postcon Iterates the submenus of a main menu item.

    @param   Menu as a TMenuItem as a constant
    @return  a TMenuItem

  **)
  Function IterateSubMenus(Const Menu : TMenuItem) : TMenuItem;

  Var
    iSubMenu : Integer;

  Begin
    Result := Nil;
    For iSubMenu := 0 To Menu.Count - 1 Do
      Begin
        If CompareText(strParentMenu, Menu[iSubMenu].Name) = 0 Then
          Result := Menu[iSubMenu]
        Else
          Result := IterateSubMenus(Menu[iSubMenu]);
        If Result <> Nil Then
          Break;
      End;
  End;

Var
  iMenu : Integer;
  NTAS : INTAServices;
  Items : TMenuItem;

begin
  Result := Nil;
  NTAS := (BorlandIDEServices As INTAServices);
  For iMenu := 0 To NTAS.MainMenu.Items.Count - 1 Do
    Begin
      Items := NTAS.MainMenu.Items;
      If CompareText(strParentMenu, Items[iMenu].Name) = 0 Then
        Result := Items[iMenu]
      Else
        Result := IterateSubMenus(Items);
      If Result <> Nil Then
        Break;
    End;
end;

(**

  This method does the following: Adds an image to the IDE if found in the project resource, creates a 
  menu item, creates an action in the IDE for the menu if one is required, associated the action with the
  menu and adds the menu to the IDE as a sibiling or underneath the parent item as required.

  @precon  None.
  @postcon Returns a reference to the menu.

  @note    You should always keep a reference to the Main menu item you create so you can remove you 
           menus from the IDE.

  @param   strName       as a String as a constant
  @param   strCaption    as a String as a constant
  @param   strParentMenu as a String as a constant
  @param   ClickProc     as a TNotifyEvent as a constant
  @param   UpdateProc    as a TNotifyEvent as a constant
  @param   boolBefore    as a Boolean as a constant
  @param   boolChildMenu as a Boolean as a constant
  @param   strShortCut   as a String as a constant
  @param   iMaskColour   as a TColor as a constant
  @return  a TMenuItem

**)
Function CreateMenuItem(Const strName, strCaption, strParentMenu : String;
  Const ClickProc, UpdateProc : TNotifyEvent; Const boolBefore, boolChildMenu : Boolean;
  Const strShortCut : String; Const iMaskColour : TColor = clLime) : TMenuItem;

Var
  NTAS : INTAServices;
  CA : TAction;
  //{$IFNDEF D2005}
  miMenuItem : TMenuItem;
  //{$ENDIF}
  iImageIndex : Integer;

begin
  NTAS := (BorlandIDEServices As INTAServices);
  // Add Image to IDE
  iImageIndex := AddImageToIDE(strName, iMaskColour);
  // Create the IDE action (cached for removal later)
  CA := Nil;
  Result := TMenuItem.Create(NTAS.MainMenu);
  If Assigned(ClickProc) Then
    Begin
      CA := TAction.Create(NTAS.ActionList);
      CA.ActionList := NTAS.ActionList;
      CA.Name := strName + 'Action';
      CA.Caption := strCaption;
      CA.OnExecute := ClickProc;
      CA.OnUpdate := UpdateProc;
      CA.ShortCut := TextToShortCut(strShortCut);
      CA.Tag := TextToShortCut(strShortCut);
      CA.ImageIndex := iImageIndex;
      CA.Category := 'ITHelperMenus';
      FOTAActions.Add(CA);
    End Else
  If strCaption <> '' Then
    Begin
      Result.Caption := strCaption;
      Result.ShortCut := TextToShortCut(strShortCut);
      Result.ImageIndex := iImageIndex;
    End Else
      Result.Caption := '-';
  // Create menu (removed through parent menu)
  Result.Action := CA;
  Result.Name := strName + 'Menu';
  // Create Action and Menu.
  //{$IFDEF D2005}
  // This is the new way to do it BUT doesn't create icons for the menu.
  //NTAS.AddActionMenu(strParentMenu + 'Menu', CA, Result, boolBefore, boolChildMenu);
  //{$ELSE}
  miMenuItem := FindMenuItem(strParentMenu + 'Menu');
  If miMenuItem <> Nil Then
    Begin
      If Not boolChildMenu Then
        Begin
          If boolBefore Then
            miMenuItem.Parent.Insert(miMenuItem.MenuIndex, Result)
          Else
            miMenuItem.Parent.Insert(miMenuItem.MenuIndex + 1, Result);
        End Else
          miMenuItem.Add(Result);
    End;
  //{$ENDIF}
end;

(**

  This method can be called (and should from Delphi 7 IDE and lower) to patch
  the shortcuts to the menu / action items as they are lost be the IDE. A copy
  of the shortcut is stored in the TAG property of the action.

  @precon  None.
  @postcon Patches the action shortcuts for added action item.

  @param   Sender as a TObject

**)
Procedure PatchActionShortcuts(Sender : TObject);

Var
  iAction : Integer;
  A : TAction;

Begin
  For iAction := 0 To FOTAActions.Count - 1 Do
    Begin
      A := FOTAActions[iAction] As TAction;
      A.ShortCut := A.Tag;
    End;
End;

(**

  This method removes any tool bar buttons that correpsond to actions from this
  expert so that there are no access violations once it is removed.

  @precon  None.
  @postcon Removes any tool bar buttons that correpsond to actions from this
           expert so that there are no access violations once it is removed.

**)
Procedure RemoveToolbarButtonsAssociatedWithActions;

  (**

    This function checks to see whether the given action is in our action list
    and returns true if it is.

    @precon  None.
    @postcon Checks to see whether the given action is in our action list
             and returns true if it is.

    @param   Action as a TBasicAction
    @return  a Boolean

  **)
  Function IsCustomAction(Action : TBasicAction) : Boolean;

  Var
    i: Integer;

  Begin
    Result := False;
    For i := 0 To FOTAActions.Count - 1 Do
      If Action = FOTAActions[i] Then
        Begin
          Result := True;
          Break;
        End;
  End;

  (**

    This method iterates over the buttons on a toolbar and removed the button if
    its action corresponds to an action from this expert.

    @precon  None.
    @postcon Iterates over the buttons on a toolbar and removed the button if
             its action corresponds to an action from this expert.

    @param   TB as a TToolbar

  **)
  Procedure RemoveAction(TB : TToolbar);

  Var
    i: Integer;

  Begin
    If TB <> Nil Then
      For i := TB.ButtonCount - 1 DownTo 0 Do
        Begin
          If IsCustomAction(TB.Buttons[i].Action) Then
            TB.RemoveControl(TB.Buttons[i]);
        End;
  End;

Var
  NTAS : INTAServices;

Begin
  NTAS := (BorlandIDEServices As INTAServices);
  RemoveAction(NTAS.ToolBar[sCustomToolBar]);
  RemoveAction(NTAS.Toolbar[sStandardToolBar]);
  RemoveAction(NTAS.Toolbar[sDebugToolBar]);
  RemoveAction(NTAS.Toolbar[sViewToolBar]);
  RemoveAction(NTAS.Toolbar[sDesktopToolBar]);
  {$IFDEF D0006}
  RemoveAction(NTAS.Toolbar[sInternetToolBar]);
  RemoveAction(NTAS.Toolbar[sCORBAToolBar]);
  {$IFDEF D2009}
  RemoveAction(NTAS.Toolbar[sAlignToolbar]);
  RemoveAction(NTAS.Toolbar[sBrowserToolbar]);
  RemoveAction(NTAS.Toolbar[sHTMLDesignToolbar]);
  RemoveAction(NTAS.Toolbar[sHTMLFormatToolbar]);
  RemoveAction(NTAS.Toolbar[sHTMLTableToolbar]);
  RemoveAction(NTAS.Toolbar[sPersonalityToolBar]);
  RemoveAction(NTAS.Toolbar[sPositionToolbar]);
  RemoveAction(NTAS.Toolbar[sSpacingToolbar]);
  {$ENDIF}
  {$ENDIF}
End;
{$ENDIF}

(**

  This function returns a reference to the Experts actions.

  @precon  None.
  @postcon Returns a reference to the Experts actions.

  @return  a TObjectList

**)
Function Actions : TObjectList;

Begin
  Result := FOTAActions;
End;

(**

  This function returns the ITHelpers HTML Help file with an optional page reference.

  @precon  None.
  @postcon Returns the ITHelpers HTML Help file with an optional page reference.

  @param   strContext as a String as a constant
  @return  a String

**)
Function ITHHTMLHelpFile(Const strContext : String = '') : String;

Var
  iSize: Cardinal;

Begin
  SetLength(Result, MAX_PATH);
  iSize := GetModuleFileName(hInstance, PChar(Result), MAX_PATH);
  SetLength(Result, iSize);
  Result := ExtractFilePath(Result) + 'ITHelper.chm';
  If strContext <> '' Then
    Result := Result + Format('::/%s.html', [strContext]);
End;

(** Creates an object list for storing all action reference so they can be
    removed from the IDE. **)
Initialization
  FOTAActions := TObjectList.Create(True);
(** Frees the actions and in doing so removes them from the IDE. **)
Finalization
  {$IFNDEF CONSOLE_TESTRUNNER}
  RemoveToolbarButtonsAssociatedWithActions;
  {$ENDIF}
  FOTAActions.Free;
end.

