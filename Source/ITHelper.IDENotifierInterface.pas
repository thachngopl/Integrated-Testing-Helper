(**

  This module contains a class that implements the IDE notifiers so that before and after
  compilation events can be handled.

  @Author  David Hoyle.
  @Version 1.0
  @Date    30 Dec 2017

**)
Unit ITHelper.IDENotifierInterface;

Interface

Uses
  ToolsAPI,
  Contnrs,
  ITHelper.TestingHelperUtils,
  ITHelper.ConfigurationForm,
  ExtCtrls,
  Classes,
  IniFiles,
  ITHelper.ExternalProcessInfo,
  ITHelper.GlobalOptions;

{$INCLUDE 'CompilerDefinitions.inc'}

Type
  (** A class to implement the IDE notifier interfaces **)
  TITHelperIDENotifier = Class(TNotifierObject, IOTANotifier, IOTAIDENotifier,
    IOTAIDENotifier50 {$IFDEF D2005}, IOTAIDENotifier80 {$ENDIF})
    {$IFDEF D2005} Strict {$ENDIF} Private
    { Private declarations }
    FMsgs: TObjectList;
    FGlobalOps: TITHGlobalOptions;
    FParentMsg: TCustomMessage;
    FLastMessage: TDateTime;
    FSuccessfulCompile: TTimer;
    FLastSuccessfulCompile: Int64;
    FShouldBuildList: TStringList;
    {$IFDEF D2005} Strict {$ENDIF} Protected
    { Protected declarations }
    Function ProcessCompileInformation(Const ProjectOps : TITHProjectOptions; Const Project: IOTAProject;
      Const strWhere: String): Integer;
    Function ZipProjectInformation(Const ProjectOps : TITHProjectOptions;
      Const Project: IOTAProject): Integer;
    Procedure IncrementBuild(Const ProjectOps : TITHProjectOptions; Const Project: IOTAProject;
      Const strProject: String);
    Procedure CopyVersionInfoFromDependency(Const Project: IOTAProject; Const strProject: String;
      Const ProjectOps: TITHProjectOptions);
    Function BuildResponseFile(Const Project: IOTAProject; Const ProjectOps: TITHProjectOptions;
      Const slResponse: TStringList; Const strBasePath, strProject, strZIPName: String): String;
    Function AddToList(Const slResponseFile: TStringList; Const strBasePath,
      strModuleName: String): Boolean;
    Procedure CheckSourceForInclude(Const strFileName, strInclude: String;
      Const slIncludeFiles: TStringList);
    Function FileList(Const slResponseFile: TStringList): String;
    Function CheckResExts(Const slResExts: TStringList; Const strFileName: String): Boolean;
    Procedure ProcessAfterCompile(Const Project: IOTAProject;
      Succeeded, IsCodeInsight: Boolean);
    Procedure CheckResponseFileAgainExclusions(Const ProjectOps: TITHProjectOptions;
      Const slReponseFile: TStringList);
    Function IsProject(Const Project: IOTAProject; Const strExtType: String): Boolean;
    Procedure BuildTargetFileName(Const slResponseFile: TStringList; Const strBasePath: String;
      Const Project: IOTAProject);
    Procedure AddProjectFilesToResponseFile(Const slResponse: TStringList; Const strBasePath: String;
      Const Project: IOTAProject);
    Procedure CheckResponseFilesForIncludeAndRes(Const Project: IOTAProject; Const strProject: String;
      Const slResponse: TStringList; Const ProjectOps: TITHProjectOptions; Const strBasePath: String);
    Procedure AddAdditionalZipFilesToResponseFile(Const ProjectOps: TITHProjectOptions;
      Const slResponse: TStringList; Const Project : IOTAProject; Const strBasePath: String);
    Procedure SuccessfulCompile(Sender: TObject);
    Function ProjectOptions(Const Project: IOTAProject; Const strOptions: Array Of String): String;
    Procedure ExpandProcessMacro(Const Processes: TITHProcessCollection; Const Project: IOTAProject);
    Procedure BuildProjectVersionResource(Const ProjectOps: TITHProjectOptions;
      Const Project: IOTAProject);
  Public
    { Public declarations }
    Constructor Create(Const GlobalOps: TITHGlobalOptions);
    Destructor Destroy; Override;
    Procedure AfterCompile(Succeeded: Boolean); Overload;
    Procedure AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean); Overload;
    {$IFDEF D2005}
    Procedure AfterCompile(Const Project: IOTAProject; Succeeded: Boolean;
      IsCodeInsight: Boolean); Overload;
    {$ENDIF}
    Procedure BeforeCompile(Const Project: IOTAProject; Var Cancel: Boolean); Overload;
    Procedure BeforeCompile(Const Project: IOTAProject; IsCodeInsight: Boolean;
      Var Cancel: Boolean); Overload;
    Procedure ProcessMsgHandler(Const strMsg: String; Var boolAbort: Boolean);
    Procedure IdleHandler;
    Procedure FileNotification(NotifyCode: TOTAFileNotification; Const FileName: String;
      Var Cancel: Boolean);
  End;

Implementation

Uses
  ITHelper.EnabledOptions,
  ITHelper.ProcessingForm,
  Windows,
  SysUtils,
  StrUtils,
  Graphics,
  Forms,
  {$IFDEF DXE20}
  CommonOptionStrs,
  {$ENDIF}
  Variants, 
  ITHelper.CommonFunctions;

{$IFDEF DXE20}
Type
  EITHException = Class(Exception);
{$ENDIF}

ResourceString
  (** This is the warning shown if there are no after compilation tools. **)
  strAfterCompileWARNING = 'WARNING: There are no Post-Compilation tools con' +
    'figured (%s).';
  (** This is the warning shown if there are no before compilation tools. **)
  strBeforeCompileWARNING = 'WARNING: There are no Pre-Compilation tools con' +
    'figured (%s).';
{$IFDEF DXE20}
  strMsgBroken = 'The Open Tools API''s ability to manipulale the build number of the ' +
    'version information is broken. Althought the number can be incremented this is ' +
    'not included in the EXE/DLL and this incrementation is lost when the project is ' +
    'closed. Please turn off the IDE''s version numbering and use ITHelper''s own ' +
    'mechanism for handling version information in the project options dialogue.';
  strMsgIncBuildDisabled = 'You have enabled the incrementation of the build number on ' +
    'successful compilation but you have not enabled ITHelper''s handling of version ' +
    'information in the project options dialogue.';
  strMsgCopyDisabled = 'You have enabled the copying of version information from an ' +
    'existing executabe but you have not enabled ITHelper''s handling of version ' +
    'information in the project options dialogue.';
{$ENDIF}

(**

  This function returns a string list contains the tokenized representation of the passed string with 
  respect to some basic object pascal grammer.

  @precon  strText si the line of text to be tokenised
  @postcon Returns a new string list of the tokenized string

  @note    The string list returned must be destroyed be the calling method.

  @param   strText as a String as a constant
  @return  a TStringList

**)
Function Tokenize(Const strText: String): TStringList;

Type
  TBADITokenType = (ttUnknown, ttWhiteSpace, ttNumber, ttIdentifier, ttLineEnd,
    ttStringLiteral, ttSymbol);
  (** State machine for block types. **)
  TBlockType = (btNoBlock, btStringLiteral);

Const
  (** Growth size of the token buffer. **)
  iTokenCapacity = 25;

Var
  (** Token buffer. **)
  strToken: String;
  CurToken: TBADITokenType;
  LastToken: TBADITokenType;
  BlockType: TBlockType;
  (** Token size **)
  iTokenLen: Integer;
  i: Integer;

Begin
  Result := TStringList.Create;
  BlockType := btNoBlock;
  strToken := '';
  CurToken := ttUnknown;
  strToken := '';

  iTokenLen := 0;
  SetLength(strToken, iTokenCapacity);

  For i := 1 To Length(strText) Do
    Begin
      LastToken := CurToken;
      {$IFNDEF D2009}
      If strText[i] In [#32, #9] Then
      {$ELSE}
      If CharInSet(strText[i], [#32, #9]) Then
        {$ENDIF}
        CurToken := ttWhiteSpace
        {$IFNDEF D2009}
      Else If strText[i] In ['#', '_', 'a' .. 'z', 'A' .. 'Z', '.', '*'] Then
        {$ELSE}
      Else If CharInSet(strText[i], ['#', '_', 'a' .. 'z', 'A' .. 'Z', '.', '*']) Then
        {$ENDIF}
        Begin
          {$IFNDEF D2009}
          If (LastToken = ttNumber) And (strText[i] In ['A' .. 'F', 'a' .. 'f']) Then
          {$ELSE}
          If (LastToken = ttNumber) And
            (CharInSet(strText[i], ['A' .. 'F', 'a' .. 'f'])) Then
            {$ENDIF}
            CurToken := ttNumber
          Else
            CurToken := ttIdentifier;
        End
        {$IFNDEF D2009}
      Else If strText[i] In ['$', '0' .. '9'] Then
        {$ELSE}
      Else If CharInSet(strText[i], ['$', '0' .. '9']) Then
        {$ENDIF}
        Begin
          CurToken := ttNumber;
          If LastToken = ttIdentifier Then
            CurToken := ttIdentifier;
        End
        {$IFNDEF D2009}
      Else If strText[i] In [#10, #13] Then
        {$ELSE}
      Else If CharInSet(strText[i], [#10, #13]) Then
        {$ENDIF}
        CurToken := ttLineEnd
        {$IFNDEF D2009}
      Else If strText[i] In ['''', '"'] Then
        {$ELSE}
      Else If CharInSet(strText[i], ['''', '"']) Then
        {$ENDIF}
        CurToken := ttStringLiteral
        {$IFNDEF D2009}
      Else If strText[i] In [#0 .. #255] - ['#', '_', 'a' .. 'z', 'A' .. 'Z', '$',
        '0' .. '9'] Then
        {$ELSE}
      Else If CharInSet(strText[i], [#0 .. #255] - ['#', '_', 'a' .. 'z', 'A' .. 'Z', '$',
        '0' .. '9']) Then
        {$ENDIF}
        CurToken := ttSymbol
      Else
        CurToken := ttUnknown;
      If (LastToken <> CurToken) Or (CurToken = ttSymbol) Then
        Begin
          If ((BlockType In [btStringLiteral]) And (CurToken <> ttLineEnd)) Then
            Begin
              Inc(iTokenLen);
              If iTokenLen > Length(strToken) Then
                SetLength(strToken, iTokenCapacity + Length(strToken));
              strToken[iTokenLen] := strText[i];
            End
          Else
            Begin
              SetLength(strToken, iTokenLen);
              If iTokenLen > 0 Then
                If Not(LastToken In [ttLineEnd, ttWhiteSpace]) Then
                  Result.AddObject(strToken, TObject(LastToken));
              BlockType := btNoBlock;
              iTokenLen := 1;
              SetLength(strToken, iTokenCapacity);
              strToken[iTokenLen] := strText[i];
            End;
        End
      Else
        Begin
          Inc(iTokenLen);
          If iTokenLen > Length(strToken) Then
            SetLength(strToken, iTokenCapacity + Length(strToken));
          strToken[iTokenLen] := strText[i];
        End;

      // Check for string literals
      If CurToken = ttStringLiteral Then
        If BlockType = btStringLiteral Then
          BlockType := btNoBlock
        Else If BlockType = btNoBlock Then
          BlockType := btStringLiteral;

    End;
  If iTokenLen > 0 Then
    Begin
      SetLength(strToken, iTokenLen);
      If Not(CurToken In [ttLineEnd, ttWhiteSpace]) Then
        Result.AddObject(strToken, TObject(CurToken));
    End;
End;

(**

  This method adds additional files list for the zip process to the responce file.

  @precon  INIFile must be a valid insyanceof a TMemIniFile class and slRepsonse must be a valid 
           instance of a TStringList.
  @postcon Adds additional files list for the zip process to the responce file.

  @param   ProjectOps  as a TITHProjectOptions as a constant
  @param   slResponse  as a TStringList as a constant
  @param   Project     as an IOTAProject as a constant
  @param   strBasePath as a String as a constant

**)
Procedure TITHelperIDENotifier.AddAdditionalZipFilesToResponseFile(
  Const ProjectOps: TITHProjectOptions; Const slResponse: TStringList; Const Project : IOTAProject;
  Const strBasePath: String);

Var
  slWildcards: TStringList;
  iModule: Integer;

Begin
  slWildcards := ProjectOps.AddZipFiles;
  For iModule := 0 To slWildcards.Count - 1 Do
    AddToList(slResponse, strBasePath, ExpandMacro(slWildcards[iModule], Project));
End;

(**

  This method adds project files to the response file for zipping.

  @precon  slRepsonse file must be a valid instance of a TStringList. Project must be a valid instance 
           of a IOTAProject interface.
  @postcon Adds project files to the response file for zipping.

  @param   slResponse  as a TStringList as a constant
  @param   strBasePath as a String as a constant
  @param   Project     as an IOTAProject as a constant

**)
Procedure TITHelperIDENotifier.AddProjectFilesToResponseFile(Const slResponse: TStringList;
  Const strBasePath: String; Const Project: IOTAProject);

Var
  iModule: Integer;
  strFileName: String;
  //: @debug Like: TDGHArrayOfString;

Begin
  For iModule := 0 To Project.ModuleFileCount - 1 Do
    Begin
      TfrmITHProcessing.ProcessFileName
        (ExtractFileName(Project.ModuleFileEditors[iModule].FileName));
      AddToList(slResponse, strBasePath, Project.ModuleFileEditors[iModule].FileName);
    End;
  For iModule := 0 To Project.GetModuleCount - 1 Do
    Begin
      strFileName := Project.GetModule(iModule).FileName;
      TfrmITHProcessing.ProcessFileName(ExtractFileName(strFileName));
      AddToList(slResponse, strBasePath, strFileName);
      // Check for DCR on Type Libraries
      If Like('*_tlb.pas', strFileName) Then
        AddToList(slResponse, strBasePath, ChangeFileExt(strFileName, '.dcr'));
      // Check for DFM files
      If Project.GetModule(iModule).FormName <> '' Then
        Begin
          If Like('*.pas', strFileName) Or Like('*.cpp', strFileName) Then
            AddToList(slResponse, strBasePath,
              ChangeFileExt(Project.GetModule(iModule).FileName, '.dfm'))
          Else
            AddToList(slResponse, strBasePath,
              ResolvePath(Project.GetModule(iModule).FormName,
              ExtractFilePath(Project.FileName)));
        End;
    End;
End;

(**

  This procedure adds the module name to the list of zip files after changing it to a relative path. If 
  the file already exists in the list true is returned else false.

  @precon  None.
  @postcon Adds the module name to the list of zip files after changing it to a relative path. If the 
           file already exists in the list true is returned else false.

  @param   slResponseFile as a TStringList as a constant
  @param   strBasePath    as a String as a constant
  @param   strModuleName  as a String as a constant
  @return  a Boolean

**)
Function TITHelperIDENotifier.AddToList(Const slResponseFile: TStringList;
  Const strBasePath, strModuleName: String): Boolean;

Var
  iIndex: Integer;
  strNewModuleName: String;

Begin
  Result := False;
  If Pos('\modelsupport_', Lowercase(strModuleName)) = 0 Then
    Begin
      strNewModuleName := strModuleName;
      If DGHPathRelativePathTo(strBasePath, strNewModuleName) Then
        Begin
          If strNewModuleName <> '' Then
            Begin
              Result := slResponseFile.Find(strNewModuleName, iIndex);
              slResponseFile.Add(strNewModuleName);
            End;
        End;
    End;
End;

(**

  This is an null implementation for the AfterCompile interface.

  @precon  None.
  @postcon Not implemented.

  @nocheck EmptyMethod MissingCONSTInParam
  @nohint  Succeeded

  @param   Succeeded as a Boolean

**)
Procedure TITHelperIDENotifier.AfterCompile(Succeeded: Boolean);

Begin
End;

(**

  This is an null implementation for the AfterCompile interface.

  @precon  None.
  @postcon Not implemented.

  @nocheck MissingCONSTInParam EmptyMethod
  @nohint  Succeeded IsCodeInsight

  @param   Succeeded     as a Boolean
  @param   IsCodeInsight as a Boolean

**)
Procedure TITHelperIDENotifier.AfterCompile(Succeeded, IsCodeInsight: Boolean);

Begin
  {$IFNDEF D2005} // For D7 and below
  ProcessAfterCompile(ActiveProject, Succeeded, IsCodeInsight);
  {$ENDIF}
End;

{$IFDEF D2005}

(**

  This is an implementation for the AfterCompile interface.

  @precon  None.
  @postcon If the compile is not from CodeInsight then the before compilation
           external tools associated with the compiled project are run.

  @nocheck MissingCONSTInParam

  @param   Project       as an IOTAProject as a constant
  @param   Succeeded     as a Boolean
  @param   IsCodeInsight as a Boolean

**)
Procedure TITHelperIDENotifier.AfterCompile(Const Project: IOTAProject;
  Succeeded, IsCodeInsight: Boolean);

Begin // For D2005 and above
  ProcessAfterCompile(Project, Succeeded, IsCodeInsight);
End;
{$ENDIF}

(**

  This is an implementation for the BeforeCompile interface.

  @precon  None.
  @postcon If the compile is not from CodeInsight then the before compilation
           external tools associated with the compiled project are run.

  @nocheck MissingCONSTInParam
  
  @param   Project       as an IOTAProject as a constant
  @param   IsCodeInsight as a Boolean
  @param   Cancel        as a Boolean as a reference

**)
Procedure TITHelperIDENotifier.BeforeCompile(Const Project: IOTAProject; IsCodeInsight: Boolean;
  Var Cancel: Boolean);

Var
  iResult: Integer;
  strProject: String;
  ProjectOps: TITHProjectOptions;
  iInterval: Int64;
  Ops: TITHEnabledOptions;

Begin
  If Project = Nil Then
    Exit;
  If IsCodeInsight Then
    Exit;
  ProjectOps := FGlobalOps.ProjectOptions(Project);
  Try
    iInterval := FGlobalOps.ClearMessages;
    If iInterval > 0 Then
      If FLastMessage < GetTickCount - iInterval * 1000 Then
        Begin
          ClearMessages([cmCompiler, cmGroup]);
          FLastMessage := GetTickCount;
        End;
    If Project.ProjectBuilder.ShouldBuild Then
      Begin
        FShouldBuildList.Add(Project.FileName);
        Ops := FGlobalOps.ProjectGroupOps;
        If eoGroupEnabled In Ops Then
          Begin
            Try
              strProject := GetProjectName(Project);
              If eoCopyVersionInfo In Ops Then
                CopyVersionInfoFromDependency(Project, strProject, ProjectOps);
              If eoBefore In Ops Then
                With (BorlandIDEServices As IOTAMessageServices) Do
                  Begin
                    iResult := ProcessCompileInformation(ProjectOps, Project, 'Pre-Compilation');
                    If iResult > 0 Then
                      Begin
                        Cancel := True;
                        TfrmITHProcessing.ShowProcessing
                          (Format('Pre-Compilation Tools Failed (%s).', [strProject]),
                          FGlobalOps.FontColour[ithfWarning], True);
                        ShowHelperMessages(FGlobalOps.GroupMessages);
                      End
                    Else If iResult < 0 Then
                      If ProjectOps.WarnBefore Then
                        Begin
                          AddMsg(Format(strBeforeCompileWARNING, [strProject]),
                            FGlobalOps.GroupMessages, FGlobalOps.AutoScrollMessages,
                            FGlobalOps.FontName[fnHeader],
                            FGlobalOps.FontColour[ithfWarning],
                            FGlobalOps.FontStyles[ithfWarning]);
                          ShowHelperMessages(FGlobalOps.GroupMessages);
                        End;
                  End;
              If eoBuildVersionResource In Ops Then
                If ProjectOps.IncITHVerInfo Then
                  BuildProjectVersionResource(Projectops, Project);
            Finally
              TfrmITHProcessing.HideProcessing;
            End;
          End;
      End;
  Finally
    ProjectOps.Free;
  End;
End;

(**

  This is an null implementation for the BeforeCompile interface.

  @precon  None.
  @postcon Not implemented.

  @nocheck EmptyMethod
  @nohint  Project Cancel

  @param   Project as an IOTAProject as a constant
  @param   Cancel  as a Boolean as a reference

**)
Procedure TITHelperIDENotifier.BeforeCompile(Const Project: IOTAProject;
  Var Cancel: Boolean);
  
Begin
End;

(**

  This method builds the ITHelper version resource for inclusion in the project.

  @precon  None.
  @postcon Builds the ITHelper version resource for inclusion in the project.

  @param   ProjectOps as a TITHProjectOptions as a constant
  @param   Project    as an IOTAProject as a constant

**)
Procedure TITHelperIDENotifier.BuildProjectVersionResource(Const ProjectOps: TITHProjectOptions;
  Const Project: IOTAProject);

Var
  sl, S: TStringList;
  i: Integer;
  strFileName : String;
  iModule : Integer;
  boolFound : Boolean;
  Process : TITHProcessInfo;
  iResult: Integer;
  j: Integer;

Begin
  sl := TStringList.Create;
  Try
    sl.Add('LANGUAGE LANG_ENGLISH,SUBLANG_ENGLISH_US');
    sl.Add('');
    sl.Add('1 VERSIONINFO LOADONCALL MOVEABLE DISCARDABLE IMPURE');
    sl.Add(Format('FILEVERSION %d, %d, %d, %d', [ProjectOps.Major, ProjectOps.Minor,
      ProjectOps.Release, ProjectOps.Build]));
    sl.Add(Format('PRODUCTVERSION %d, %d, %d, %d', [ProjectOps.Major, ProjectOps.Minor,
      ProjectOps.Release, ProjectOps.Build]));
    sl.Add('FILEFLAGSMASK VS_FFI_FILEFLAGSMASK');
    sl.Add('FILEOS VOS__WINDOWS32');
    sl.Add('FILETYPE VFT_APP');
    sl.Add('{');
    sl.Add('  BLOCK "StringFileInfo"');
    sl.Add('  {');
    sl.Add('    BLOCK "040904E4"');
    sl.Add('    {');
    S := ProjectOps.VerInfo;
    For i := 0 To S.Count - 1 Do
      Begin
        sl.Add(Format('     VALUE "%s", "%s\000"', [S.Names[i], S.ValueFromIndex[i]]));
      End;
    sl.Add('    }');
    sl.Add('  }');
    sl.Add('  BLOCK "VarFileInfo"');
    sl.Add('  {');
    sl.Add('    VALUE "Translation", 1033, 1252');
    sl.Add('  }');
    sl.Add('}');
    strFileName := ExtractFilePath(Project.FileName) + ProjectOps.ResourceName + '.RC';
    sl.SaveToFile(strFileName);
    AddMsg(Format('Version information resource %s.RC created for project %s.', [
      ProjectOps.ResourceName, GetProjectName(Project)]),
      FGlobalOps.GroupMessages,
      FGlobalOps.AutoScrollMessages,
      FGlobalOps.FontName[fnHeader],
      FGlobalOps.FontColour[ithfDefault],
      FGlobalOps.FontStyles[ithfDefault]
    );
    If ProjectOps.IncResInProj Then
      Begin
        boolFound := False;
        For iModule := 0 To Project.GetModuleCount - 1 Do
          If CompareText(Project.GetModule(iModule).FileName, strFileName) = 0 Then
            Begin
              boolFound := True;
              Break;
            End;
        If Not boolFound Then
          Begin
            Project.AddFile(strFileName, True);
            AddMsg(Format('Resource %s.RC added to project %s.', [
              ProjectOps.ResourceName, GetProjectName(Project)]),
              FGlobalOps.GroupMessages,
              FGlobalOps.AutoScrollMessages,
              FGlobalOps.FontName[fnHeader],
              FGlobalOps.FontColour[ithfDefault],
              FGlobalOps.FontStyles[ithfDefault]
            );
          End;
      End;
    If ProjectOps.CompileRes Then
      Begin
        Process.FEnabled := True;
        Process.FTitle := 'Compiling ' + ProjectOps.ResourceName + ' with BRCC32';
        Process.FEXE := 'BRCC32.exe';
        Process.FParams := '-v "' + strFileName + '"';
        Process.FDir := GetCurrentDir;
        FParentMsg :=
          AddMsg(Format('Running: %s (%s)',
            [ExtractFileName(Process.FTitle), GetProjectName(Project)]),
            FGlobalOps.GroupMessages,
            FGlobalOps.AutoScrollMessages,
            FGlobalOps.FontName[fnHeader],
            FGlobalOps.FontColour[ithfHeader],
            FGlobalOps.FontStyles[ithfHeader]);
        TfrmITHProcessing.ShowProcessing(Format('Processing %s...',
          [ExtractFileName(Process.FTitle)]));
        FMsgs.Clear;
        iResult := DGHCreateProcess(Process, ProcessMsgHandler, IdleHandler);
        For j := 0 To FMsgs.Count - 1 Do
          Case iResult Of
            0:
              (FMsgs.Items[j] As TCustomMessage).ForeColour :=
                FGlobalOps.FontColour[ithfSuccess];
          Else
            (FMsgs.Items[j] As TCustomMessage).ForeColour := FGlobalOps.FontColour
              [ithfFailure];
          End;
        If iResult <> 0 Then
          FParentMsg.ForeColour := FGlobalOps.FontColour[ithfFailure];
        ShowHelperMessages(FGlobalOps.GroupMessages);
        If iResult > 0 Then
          Abort;
          AddMsg(Format('Resource %s.RC compiled for project %s.', [
            ProjectOps.ResourceName, GetProjectName(Project)]),
            FGlobalOps.GroupMessages,
            FGlobalOps.AutoScrollMessages,
            FGlobalOps.FontName[fnHeader],
            FGlobalOps.FontColour[ithfDefault],
            FGlobalOps.FontStyles[ithfDefault]
          );
      End;
  Finally
    sl.Free;
  End;
End;

(**

  This method adds files to the response file starting with project files and then project modules.

  @precon  INIFile and slReponse should be valid instances.
  @postcon Adds files to the response file starting with project files and then project modules.

  @param   Project     as an IOTAProject as a constant
  @param   ProjectOps  as a TITHProjectOptions as a constant
  @param   slResponse  as a TStringList as a constant
  @param   strBasePath as a String as a constant
  @param   strProject  as a String as a constant
  @param   strZIPName  as a String as a constant
  @return  a String

**)
Function TITHelperIDENotifier.BuildResponseFile(Const Project: IOTAProject;
  Const ProjectOps: TITHProjectOptions; Const slResponse: TStringList;
  Const strBasePath, strProject, strZIPName: String): String;

Begin
  TfrmITHProcessing.ShowProcessing(Format('Building Filelist for %s...',
    [ExtractFileName(strProject)]));
  AddToList(slResponse, strBasePath, Project.FileName);
  AddToList(slResponse, strBasePath, ChangeFileExt(Project.FileName, '.res'));
  AddToList(slResponse, strBasePath, ChangeFileExt(Project.FileName, '.cfg'));
  BuildTargetFileName(slResponse, strBasePath, Project);
  AddProjectFilesToResponseFile(slResponse, strBasePath, Project);
  TfrmITHProcessing.ShowProcessing('Checking Filelist for Resources...');
  CheckResponseFilesForIncludeAndRes(Project, strProject, slResponse, ProjectOps,
    strBasePath);
  AddAdditionalZipFilesToResponseFile(ProjectOps, slResponse, Project, strBasePath);
  Result := ChangeFileExt(strZIPName, '.response');
  CheckResponseFileAgainExclusions(ProjectOps, slResponse);
  Try
    //ShowMessage(slResponse.Text);
    slResponse.SaveToFile(Result);
  Except
    On E: EWriteError Do
      Begin
        AddMsg(Format(E.Message + '(%s)', [strProject]), FGlobalOps.GroupMessages,
          FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnHeader],
          FGlobalOps.FontColour[ithfFailure], FGlobalOps.FontStyles[ithfFailure]);
        Exit;
      End;
  End;
End;

(**

  This method builds the target file name from scratch using project options.

  @precon  slResponse must be a valid instance of a TStringList and Project must be a valid instance of 
           a IOTAProject interface.
  @postcon Builds the target file name from scratch using project options.

  @note    This will not handle project options in INC files.

  @param   slResponseFile as a TStringList as a constant
  @param   strBasePath    as a String as a constant
  @param   Project        as an IOTAProject as a constant

**)
Procedure TITHelperIDENotifier.BuildTargetFileName(Const slResponseFile: TStringList;
  Const strBasePath: String; Const Project: IOTAProject);

Var
  strExt: String;
  i: Integer;
  strTargetName: String;
  sl: TStringList;
  iStart: Integer;
  iEnd: Integer;

Begin
  If IsProject(Project, '*.dpk') Then
    strExt := '.bpl'
  Else If IsProject(Project, '*.dpr') Then
    Begin
      strExt := '.exe';
      sl := TStringList.Create;
      Try
        sl.LoadFromFile(ChangeFileExt(Project.FileName, '.dpr'));
        For i := 0 To sl.Count - 1 Do
          Begin
            If Like(Format('*library*%s*;*',
              [ChangeFileExt(ExtractFileName(Project.FileName), '')]), sl[i]) Then
              strExt := '.dll';
            If Like('{$e *}*', sl[i]) Or Like('{$e'#9'*}*', sl[i]) Then
            // Search for alternate extension
              Begin
                iStart := Pos('{$e', Lowercase(sl[i]));
                iEnd := Pos('}', sl[i]);
                If (iStart > 0) And (iEnd > 0) And (iStart < iEnd) Then
                  strExt := '.' + Trim(Copy(sl[i], iStart + 3, iEnd - iStart - 3));
              End;
          End;
      Finally
        sl.Free;
      End;
    End;
  strTargetName := ExtractFilePath(Project.FileName) + ProjectOptions(Project,
    ['OutputDir', 'PkgDllDir']) + ProjectOptions(Project, ['DllPrefix', 'SOPrefix']) +
    ExtractFileName(ChangeFileExt(Project.FileName, '')) + ProjectOptions(Project,
    ['DllSuffix', 'SOSuffix']) + strExt + '.' + ProjectOptions(Project,
    ['DllVersion', 'SOVersion']);
  strTargetName := ExpandFileName(strTargetName);
  AddToList(slResponseFile, strBasePath, strTargetName);
End;

(**

  This method checks whether the extension of the given file exists in the semi-colon separated list of 
  extension to be excluded resource warnings. If it does then it returns false.

  @precon  None.
  @postcon Checks whether the extension of the given file exists in the semi-colon separated list of 
           extension to be excluded resource warnings. If it does then it returns false.

  @param   slResExts   as a TStringList as a constant
  @param   strFileName as a String as a constant
  @return  a Boolean

**)
Function TITHelperIDENotifier.CheckResExts(Const slResExts: TStringList;
  Const strFileName: String): Boolean;

Var
  iExt: Integer;

Begin
  Result := True;
  For iExt := 0 To slResExts.Count - 1 Do
    Result := Result And Not Like(slResExts[iExt], strFileName);
End;

(**

  This method processes the response file information removing any items that make the wildcard (LIKE) 
  exclusions.

  @precon  None.
  @postcon Processes the response file information removing any items that make the wildcard (LIKE) 
           exclusions.

  @param   ProjectOps    as a TITHProjectOptions as a constant
  @param   slReponseFile as a TStringList as a constant

**)
Procedure TITHelperIDENotifier.CheckResponseFileAgainExclusions(
  Const ProjectOps: TITHProjectOptions; Const slReponseFile: TStringList);

Var
  i, j: Integer;
  sl: TStringList;

Begin
  sl := TStringList.Create;
  Try
    sl.Text := ProjectOps.ExcPatterns;
    For j := 0 To sl.Count - 1 Do
      For i := slReponseFile.Count - 1 DownTo 0 Do
        If Like(sl[j], slReponseFile[i]) Then
          Begin
            slReponseFile.Delete(i);
            Break;
          End;
  Finally
    sl.Free;
  End;
End;

(**

  This method searches the list of files in the response file for INCLUDE statements where additional INC
  and RC/RES files are requested.

  @precon  Project must be a valid instance of a IOTAProject interface, slResponse must be a valid 
           instance of a TStringList and INIFile must be a valid instance of a TMemINIFile class.
  @postcon Searches the list of files in the response file for INCLUDE statements where additional INC 
           and RC/RES files are requested.

  @param   Project     as an IOTAProject as a constant
  @param   strProject  as a String
  @param   slResponse  as a TStringList as a constant
  @param   ProjectOps  as a TITHProjectOptions as a constant
  @param   strBasePath as a String as a constant

**)
Procedure TITHelperIDENotifier.CheckResponseFilesForIncludeAndRes(
  Const Project: IOTAProject; Const strProject: String; Const slResponse: TStringList;
  Const ProjectOps: TITHProjectOptions; Const strBasePath: String);

Var
  strFileName: String;
  slIncludeFiles: TStringList;
  strExts: String;
  iModule: Integer;
  iExt: Integer;
  slResExts: TStringList;
  i: Integer;
  astrResExts: TDGHArrayOfString;

Begin
  // Check Source files (*.pas) for INCLUDE & RES files.
  For iModule := 0 To Project.GetModuleCount - 1 Do
    Begin
      strFileName := Project.GetModule(iModule).FileName;
      TfrmITHProcessing.ProcessFileName(ExtractFileName(strFileName));
      slIncludeFiles := TStringList.Create;
      Try
        CheckSourceForInclude(Project.GetModule(iModule).FileName, '{$I', slIncludeFiles);
        CheckSourceForInclude(Project.GetModule(iModule).FileName, '{$INCLUDE',
          slIncludeFiles);
        For i := 0 To slIncludeFiles.Count - 1 Do
          If Not AddToList(slResponse, strBasePath, slIncludeFiles[i]) Then
            AddMsg(Format('%s is not referenced in the project (%s).',
              [slIncludeFiles[i], strProject]), FGlobalOps.GroupMessages,
              FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnTools],
              FGlobalOps.FontColour[ithfWarning], FGlobalOps.FontStyles[ithfWarning]);
        slIncludeFiles.Clear;
        CheckSourceForInclude(Project.GetModule(iModule).FileName, '{$R', slIncludeFiles);
        CheckSourceForInclude(Project.GetModule(iModule).FileName, '{$RESOURCE',
          slIncludeFiles);
        slResExts := TStringList.Create;
        Try
          strExts := ProjectOps.ResExtExc;
          astrResExts := DGHSplit(strExts, ';');
          For iExt := Low(astrResExts) To High(astrResExts) Do
            Begin
              If (astrResExts[iExt] <> '') And (astrResExts[iExt][1] = '.') Then
                astrResExts[iExt] := '*' + astrResExts[iExt];
              slResExts.Add(astrResExts[iExt]);
            End;
          For i := 0 To slIncludeFiles.Count - 1 Do
            If Not AddToList(slResponse, strBasePath, slIncludeFiles[i]) Then
              If CheckResExts(slResExts, slIncludeFiles[i]) Then
                AddMsg(Format('%s is not referenced in the project (%s). Consider ' +
                  'using an RC file and the form {$R resfile.res rcfile.rc}.',
                  [slIncludeFiles[i], strProject]), FGlobalOps.GroupMessages,
                  FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnTools],
                  FGlobalOps.FontColour[ithfWarning], FGlobalOps.FontStyles[ithfWarning]);
        Finally
          slResExts.Free;
        End;
      Finally
        slIncludeFiles.Free;
      End;
    End;
End;

(**

  This method searches for include / res files in source code and extracts the file name and adds it to 
  the list of files to be included in the zip response.

  @precon  slResponse must be a valid instance.
  @postcon Searches for include / res files in source code and extracts the file name and adds it to the
           list of files to be included in the zip response.

  @param   strFileName    as a String as a constant
  @param   strInclude     as a String as a constant
  @param   slIncludeFiles as a TStringList as a constant

**)
Procedure TITHelperIDENotifier.CheckSourceForInclude(Const strFileName, strInclude: String;
  Const slIncludeFiles: TStringList);

  (**

    This function returns the positions of the closing brace before the end of the line containing 
    iOffset or the line end. If the brace is found a positive offset is returned else if the line end is 
    found a negative offset is returned.

    @precon  None.
    @postcon Returns the positions of the closing brace before the end of the line containing iOffset or
             the line end. If the brace is found a positive offset is returned else if the line end is
             found a negative offset is returned.

    @param   strText as a String as a constant
    @param   iOffset as an Integer as a constant
    @return  an Integer

  **)
  Function FindClosingBrace(Const strText: String; Const iOffset: Integer): Integer;

  Var
    i: Integer;

  Begin
    Result := 0;
    For i := iOffset To Length(strText) Do
      {$IFNDEF D2009}
      If strText[i] In ['}', #13, #10] Then
      {$ELSE}
      If CharInSet(strText[i], ['}', #13, #10]) Then
        {$ENDIF}
        Begin
          If strText[i] = '}' Then
            Result := i
          Else
            Result := -i;
          Exit;
        End;
  End;

Var
  sl: TStringList;
  iOffset: Integer;
  iEnd: Integer;
  strIncFile: String;
  iPos: Integer;
  slTokens: TStringList;

Begin
  sl := TStringList.Create;
  Try
    If FileExists(strFileName) Then
      Begin
        Try
          sl.LoadFromFile(strFileName);
          iOffset := 1;
          While iOffset > 0 Do
            Begin
              iOffset := PosEx(strInclude, sl.Text, iOffset);
              If iOffset > 0 Then
                Begin
                  Inc(iOffset, Length(strInclude));
                  {$IFNDEF D2009}
                  If sl.Text[iOffset] In [#32, #9] Then
                  {$ELSE}
                  If CharInSet(sl.Text[iOffset], [#32, #9]) Then
                    {$ENDIF}
                    Begin
                      iEnd := FindClosingBrace(sl.Text, iOffset);
                      If iEnd > iOffset Then
                        Begin
                          slTokens := Tokenize(Copy(sl.Text, iOffset, iEnd - iOffset));
                          Try
                            If slTokens.Count > 0 Then
                              Begin
                                strIncFile := slTokens[0];
                                iPos := Pos('*', strIncFile);
                                While iPos > 0 Do
                                  Begin
                                    strIncFile := Copy(strIncFile, 1, iPos - 1) +
                                      ChangeFileExt(ExtractFileName(strFileName), '') +
                                      Copy(strIncFile, iPos + 1, Length(strIncFile));
                                    iPos := Pos('*', strIncFile);
                                  End;
                                strIncFile := StringReplace(strIncFile, '''', '',
                                  [rfReplaceAll]);
                                If ExtractFilePath(strIncFile) = '' Then
                                  strIncFile := ExtractFilePath(strFileName) + strIncFile;
                                strIncFile := ExpandFileName(strIncFile);
                                If FileExists(strIncFile) Then
                                  slIncludeFiles.Add(strIncFile);
                              End;
                          Finally
                            slTokens.Free;
                          End;
                          iOffset := iEnd + 1;
                        End
                      Else
                        iOffset := Abs(iEnd) + 1;
                    End;
                End;
            End;
        Except
          On E: Exception Do
            AddMsg('ITHelper: ' + E.Message, FGlobalOps.GroupMessages,
              FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnHeader],
              FGlobalOps.FontColour[ithfFailure], FGlobalOps.FontStyles[ithfFailure]);
        End;
      End;
  Finally
    sl.Free;
  End;
End;

(**

  This method copies the version information from the first project dependency to this project IF the 
  option is enabled.

  @precon  Project must be a valid IOTAProject.
  @postcon Copies the version information from the first project dependency to this project IF the 
           option is enabled.

  @param   Project    as an IOTAProject as a constant
  @param   strProject as a String as a constant
  @param   ProjectOps as a TITHProjectOptions as a constant

**)
Procedure TITHelperIDENotifier.CopyVersionInfoFromDependency(Const Project: IOTAProject;
  Const strProject: String; Const ProjectOps: TITHProjectOptions);

Const
  strBugFix = ' abcedfghijklmnopqrstuvwxyz';

Var
  iMajor, iMinor, iBugfix, iBuild: Integer;
  Group: IOTAProjectGroup;
  strTargetName: String;
  {$IFDEF DXE20}
  POC: IOTAProjectOptionsConfigurations;
  AC: IOTABuildConfiguration;
  {$ENDIF}
  
Begin
  Group := ProjectGroup;
  If Group = Nil Then
    Exit;
  strTargetName := ExpandMacro(ProjectOps.CopyVerInfo, Project);
  If strTargetName <> '' Then
    Begin
      AddMsg(Format('Version Dependency (%s) found for project %s.',
        [ExtractFileName(strTargetName), strProject]), FGlobalOps.GroupMessages,
        FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnHeader],
        FGlobalOps.FontColour[ithfDefault], FGlobalOps.FontStyles[ithfDefault]);
      If FileExists(strTargetName) Then
        Begin
          Try
            BuildNumber(strTargetName, iMajor, iMinor, iBugfix, iBuild);
            AddMsg(Format('Dependent Build %d.%d%s (%d.%d.%d.%d).',
              [iMajor, iMinor, strBugFix[iBugfix + 1], iMajor, iMinor, iBugfix, iBuild]),
              FGlobalOps.GroupMessages,
              FGlobalOps.AutoScrollMessages,
              FGlobalOps.FontName[fnHeader],
              FGlobalOps.FontColour[ithfDefault],
              FGlobalOps.FontStyles[ithfDefault]);
            {$IFDEF DXE20}
            If Project.ProjectOptions.QueryInterface(IOTAProjectOptionsConfigurations, POC) = S_OK Then
              Begin
                AC := POC.ActiveConfiguration;
                If AC.PropertyExists(sVerInfo_IncludeVerInfo) Then
                  If AC.AsBoolean[sVerInfo_IncludeVerInfo] Then
                    Raise EITHException.Create(strMsgBroken);
                  If Not ProjectOps.IncITHVerInfo Then
                    Raise EITHException.Create(strMsgCopyDisabled)
              End;
            {$ELSE}
            If Not ProjectOps.IncITHVerInfo Then
              Begin
                If Project.ProjectOptions.Values['MajorVersion'] <> iMajor Then
                  Project.ProjectOptions.Values['MajorVersion'] := iMajor;
                If Project.ProjectOptions.Values['MinorVersion'] <> iMinor Then
                  Project.ProjectOptions.Values['MinorVersion'] := iMinor;
                If Project.ProjectOptions.Values['Release'] <> iBugfix Then
                  Project.ProjectOptions.Values['Release'] := iBugfix;
                If Project.ProjectOptions.Values['Build'] <> iBuild Then
                  Project.ProjectOptions.Values['Build'] := iBuild;
              End;
            {$ENDIF}
              If ProjectOps.IncITHVerInfo Then
                Begin
                  If ProjectOps.Major <> iMajor Then
                    ProjectOps.Major := iMajor;
                  If ProjectOps.Minor <> iMinor Then
                    ProjectOps.Minor := iMinor;
                  If ProjectOps.Release <> iBugfix Then
                    ProjectOps.Release := iBugfix;
                  If ProjectOps.Build <> iBuild Then
                    ProjectOps.Build := iBuild;
                End;
          Except
            On E: EITHException Do
              AddMsg(Format(E.Message + ' (%s)', [strProject]),
                FGlobalOps.GroupMessages,
                FGlobalOps.AutoScrollMessages,
                FGlobalOps.FontName[fnHeader],
                FGlobalOps.FontColour[ithfWarning],
                FGlobalOps.FontStyles[ithfWarning]);
          End;
          ShowHelperMessages(FGlobalOps.GroupMessages);
        End
      Else
        AddMsg(Format('The dependency "%s" was not found. (%s)',
          [strTargetName, strProject]), FGlobalOps.GroupMessages,
          FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnHeader],
          FGlobalOps.FontColour[ithfWarning], FGlobalOps.FontStyles[ithfWarning]);
    End;
End;

(**

  A constructor for the TTestingHelperIDENotifier class.

  @precon  None.
  @postcon Initialises the class.

  @param   GlobalOps as a TITHGlobalOptions as a constant

**)
Constructor TITHelperIDENotifier.Create(Const GlobalOps: TITHGlobalOptions);

Begin
  FGlobalOps := GlobalOps;
  FMsgs := TObjectList.Create(False);
  FLastSuccessfulCompile := 0;
  FSuccessfulCompile := TTimer.Create(Nil);
  FSuccessfulCompile.OnTimer := SuccessfulCompile;
  FSuccessfulCompile.Interval := 100;
  FSuccessfulCompile.Enabled := True;
  FShouldBuildList := TStringList.Create;
  FShouldBuildList.CaseSensitive := False;
End;

(**

  A destructor for the TTestingHelperIDENotifier class.

  @precon  None.
  @postcon Frees memory used by the class.

**)
Destructor TITHelperIDENotifier.Destroy;

Begin
  FShouldBuildList.Free;
  FSuccessfulCompile.Enabled := False;
  FSuccessfulCompile.OnTimer := Nil;
  FSuccessfulCompile.Free;
  FMsgs.Free;
  Inherited Destroy;
End;

(**

  This method expands any macros found in the process information.

  @precon  Project must be a valid instance.
  @postcon Expands any macros found in the process information.

  @param   Processes as a TITHProcessCollection as a constant
  @param   Project   as an IOTAProject as a constant

**)
Procedure TITHelperIDENotifier.ExpandProcessMacro(Const Processes: TITHProcessCollection;
  Const Project: IOTAProject);

Var
  i: Integer;
  P: TITHProcessInfo;

Begin
  For i := 0 To Processes.Count - 1 Do
    Begin
      P := Processes[i];
      P.FEXE := ExpandMacro(P.FEXE, Project);
      P.FParams := ExpandMacro(P.FParams, Project);
      P.FDir := ExpandMacro(P.FDir, Project);
      Processes[i] := P;
    End;
End;

(**

  This method expands the list of files to include as a space separated list of double quoted files.

  @precon  slResponseFile must be a valid instance of a string list.
  @postcon Returns a list of files to include as a space separated list of double quoted files.

  @param   slResponseFile as a TStringList as a constant
  @return  a String

**)
Function TITHelperIDENotifier.FileList(Const slResponseFile: TStringList): String;

Var
  i: Integer;

Begin
  Result := '';
  For i := 0 To slResponseFile.Count - 1 Do
    Result := Result + Format('"%s" ', [slResponseFile[i]]);
End;

(**

  This method is a null implementation of the Wizards FileNotification interface.

  @precon  None.
  @postcon None.

  @nocheck EmptyMethod MissingCONSTInParam
  @nohint  NotifyCode FileName Cancel

  @param   NotifyCode as a TOTAFileNotification
  @param   FileName   as a String as a constant
  @param   cancel     as a Boolean as a reference

**)
Procedure TITHelperIDENotifier.FileNotification(NotifyCode: TOTAFileNotification;
  Const FileName: String; Var Cancel: Boolean);

Begin
End;

(**

  This is an on idle message handler for the DGHCreateProcess method.

  @precon  None.
  @postcon Ensures the application processes its message queue.

**)
Procedure TITHelperIDENotifier.IdleHandler;

Begin
  Application.ProcessMessages;
End;

(**

  This method increments the buld number of the passed project IF this is enabled in the options.

  @precon  ProjectOps must be a valid instance.
  @postcon Increments the buld number of the passed project IF this is enabled in the options.

  @param   ProjectOps as a TITHProjectOptions as a constant
  @param   Project    as an IOTAProject as a constant
  @param   strProject as a String as a constant

**)
Procedure TITHelperIDENotifier.IncrementBuild(Const ProjectOps : TITHProjectOptions;
  Const Project: IOTAProject; Const strProject: String);

Var
  iBuild: Integer;
  {$IFDEF DXE20}
  POC: IOTAProjectOptionsConfigurations;
  AC: IOTABuildConfiguration;
  {$ENDIF}

Begin
  If ProjectOps.IncOnCompile Then
    Begin
      iBuild := -1;
      {$IFDEF DXE20}
      If Project.ProjectOptions.QueryInterface(IOTAProjectOptionsConfigurations, POC)
        = S_OK Then
        Begin
          AC := POC.ActiveConfiguration;
          If AC.PropertyExists(sVerInfo_IncludeVerInfo) Then
            If AC.AsBoolean[sVerInfo_IncludeVerInfo] Then
              Raise EITHException.Create(strMsgBroken);
            If Not ProjectOps.IncITHVerInfo Then
              Raise EITHException.Create(strMsgIncBuildDisabled);
        End;
      {$ELSE}
      If Not ProjectOps.IncITHVerInfo Then
        iBuild := Project.ProjectOptions.Values['Build'];
      {$ENDIF}
      If ProjectOps.IncITHVerInfo Then
        iBuild := ProjectOps.Build;
      If iBuild > -1 Then
        AddMsg(Format('Incrementing %s''s Build from %d to %d.',
          [strProject, iBuild, iBuild + 1]),
          FGlobalOps.GroupMessages,
          FGlobalOps.AutoScrollMessages,
          FGlobalOps.FontName[fnHeader],
          FGlobalOps.FontColour[ithfDefault],
          FGlobalOps.FontStyles[ithfDefault]);
      {$IFNDEF DXE20}
      If Not ProjectOps.IncITHVerInfo Then
        Project.ProjectOptions.Values['Build'] := iBuild + 1;
      {$ENDIF}
      If ProjectOps.IncITHVerInfo Then
        ProjectOps.Build := iBuild + 1;
    End;
End;

(**

  This method searches the projects module files in search of the given file extension pattern.

  @precon  Project must be a valid instance of a IOTAProject interface.
  @postcon Returns return if the file extension pattern was found in the module files.

  @param   Project    as an IOTAProject as a constant
  @param   strExtType as a String as a constant
  @return  a Boolean

**)
Function TITHelperIDENotifier.IsProject(Const Project: IOTAProject; Const strExtType: String): Boolean;

Var
  i: Integer;

Begin
  Result := Like(strExtType, Project.FileName);
  For i := 0 To Project.ModuleFileCount - 1 Do
    Result := Result Or Like(strExtType, Project.ModuleFileEditors[i].FileName);
End;

(**

  This method centralises the processing of the AfterCompile information.
  This is so that its can be called from different versions of the
  implementation.

  @precon  None.
  @postcon Processes the AfterCompile information.

  @nocheck MissingCONSTInParam

  @param   Project       as an IOTAProject as a constant
  @param   Succeeded     as a Boolean
  @param   IsCodeInsight as a Boolean

**)
Procedure TITHelperIDENotifier.ProcessAfterCompile(Const Project: IOTAProject;
  Succeeded, IsCodeInsight: Boolean);

Var
  iResult: Integer;
  strProject: String;
  ProjectOps: TITHProjectOptions;
  iIndex: Integer;
  Ops: TITHEnabledOptions;

Begin
  If Project = Nil Then
    Exit;
  If IsCodeInsight Or Not Succeeded Then
    Exit;
  iIndex := FShouldBuildList.IndexOf(Project.FileName);
  If iIndex > -1 Then
    Begin
      FShouldBuildList.Delete(iIndex);
      ProjectOps := FGlobalOps.ProjectOptions(Project);
      Try
        Ops := FGlobalOps.ProjectGroupOps;
        If eoGroupEnabled In Ops Then
          Try
            strProject := GetProjectName(Project);
            If eoIncrementBuild In Ops Then
              IncrementBuild(ProjectOps, Project, strProject);
            With (BorlandIDEServices As IOTAMessageServices) Do
              Begin
                If eoZip In Ops Then
                  Begin
                    iResult := ZipProjectInformation(ProjectOps, Project);
                    If iResult > 0 Then
                      Begin
                        TfrmITHProcessing.ShowProcessing(Format('ZIP Tool Failure (%s).',
                          [strProject]), FGlobalOps.FontColour[ithfFailure], True);
                        ShowHelperMessages(FGlobalOps.GroupMessages);
                        Abort; // Stop IDE continuing if there was a problem.
                      End;
                  End;
                If eoAfter In Ops Then
                  Begin
                    iResult := ProcessCompileInformation(ProjectOps, Project,
                      'Post-Compilation');
                    If iResult > 0 Then
                      Begin
                        TfrmITHProcessing.ShowProcessing
                          (Format('Post-Compilation Tools Failed (%s).', [strProject]),
                          FGlobalOps.FontColour[ithfWarning], True);
                        ShowHelperMessages(FGlobalOps.GroupMessages);
                        Abort; // Stop IDE continuing if there was a problem.
                      End
                    Else If iResult < 0 Then
                      If ProjectOps.WarnAfter Then
                        Begin
                          AddMsg(Format(strAfterCompileWARNING, [strProject]),
                            FGlobalOps.GroupMessages, FGlobalOps.AutoScrollMessages,
                            FGlobalOps.FontName[fnHeader],
                            FGlobalOps.FontColour[ithfWarning],
                            FGlobalOps.FontStyles[ithfWarning]);
                          ShowHelperMessages(FGlobalOps.GroupMessages);
                        End;
                  End;
                FLastSuccessfulCompile := GetTickCount;
              End;
          Finally
            TfrmITHProcessing.HideProcessing;
          End;
      Finally
        ProjectOps.Free;
      End;
    End;
  FLastMessage := GetTickCount;
End;

(**

  This method processes the list of external tools in the given section and runs each in a process and 
  captures the output. If any of the tools raises an Exit Code > 0 then this is added to the return 
  result.

  @precon  ProjectOps and Project must be a valid instances.
  @postcon Processes the list of external tools in the given section and runs each in a process and 
           captures the output. If any of the tools raises an Exit Code > 0 then this is added to the 
           return result.

  @param   ProjectOps as a TITHProjectOptions as a constant
  @param   Project    as an IOTAProject as a constant
  @param   strWhere   as a String as a constant
  @return  an Integer

**)
Function TITHelperIDENotifier.ProcessCompileInformation(Const ProjectOps : TITHProjectOptions;
  Const Project: IOTAProject; Const strWhere: String): Integer;

Var
  Processes: TITHProcessCollection;
  i, j: Integer;
  strProject: String;

Begin
  Result := -1; // Signifies no tools configured.
  strProject := GetProjectName(Project);
  Processes := TITHProcessCollection.Create;
  Try
    Processes.LoadFromINI(ProjectOps.INIFile, strWhere);
    ExpandProcessMacro(Processes, Project);
    If Processes.Count > 0 Then
      Result := 0;
    For i := 0 To Processes.Count - 1 Do
      Begin
        FMsgs.Clear;
        If Processes[i].FEnabled Then
          Begin
            FParentMsg :=
              AddMsg(Format('Running: %s (%s %s)',
              [ExtractFileName(Processes[i].FTitle), strProject, strWhere]),
              FGlobalOps.GroupMessages, FGlobalOps.AutoScrollMessages,
              FGlobalOps.FontName[fnHeader], FGlobalOps.FontColour[ithfHeader],
              FGlobalOps.FontStyles[ithfHeader]);
            TfrmITHProcessing.ShowProcessing(Format('Processing %s...',
              [ExtractFileName(Processes[i].FTitle)]));
            Inc(Result, DGHCreateProcess(Processes[i], ProcessMsgHandler, IdleHandler));
            For j := 0 To FMsgs.Count - 1 Do
              Case Result Of
                0:
                  (FMsgs.Items[j] As TCustomMessage).ForeColour :=
                    FGlobalOps.FontColour[ithfSuccess];
              Else
                (FMsgs.Items[j] As TCustomMessage).ForeColour := FGlobalOps.FontColour
                  [ithfFailure];
              End;
            If Result <> 0 Then
              FParentMsg.ForeColour := FGlobalOps.FontColour[ithfFailure];
            ShowHelperMessages(FGlobalOps.GroupMessages);
            If Result > 0 Then
                Break;
          End;
      End;
  Finally
    Processes.Free;
  End;
End;

(**

  This is an on process Msg handler for the DGHCreateProcess method.

  @precon  None.
  @postcon Outputs the messages from the process to the message window.

  @param   strMsg    as a String as a constant
  @param   boolAbort as a Boolean as a reference

**)
Procedure TITHelperIDENotifier.ProcessMsgHandler(Const strMsg: String; Var boolAbort: Boolean);

Begin
  If strMsg <> '' Then
    FMsgs.Add(AddMsg(strMsg, FGlobalOps.GroupMessages, FGlobalOps.AutoScrollMessages,
      FGlobalOps.FontName[fnTools], FGlobalOps.FontColour[ithfDefault],
      FGlobalOps.FontStyles[ithfDefault], clWindow, FParentMsg.MessagePntr));
End;

(**

  This method returns the first non-null occurance of the list of project option values.

  @precon  Project must be a valid instance of a IOTAProject interface.
  @postcon Returns the first non-null occurance of the list of project option values.

  @param   Project    as an IOTAProject as a constant
  @param   strOptions as an Array Of String as a constant
  @return  a String

**)
Function TITHelperIDENotifier.ProjectOptions(Const Project: IOTAProject;
  Const strOptions: Array Of String): String;

Var
  i: Integer;
  varValue: Variant;

Begin
  Result := '';
  For i := Low(strOptions) To High(strOptions) Do
    Begin
      varValue := Project.ProjectOptions.Values[strOptions[i]];
      If VarType(varValue) And varString > 0 Then
        Result := varValue;
      If Result <> '' Then
        Break;
    End;
End;

(**

  This is an on timer event handler for the SuccessfulCompile timer.

  @precon  None.
  @postcon If the options is enabled this will switch the message view to the
           helper messages 1 second after a successful compile.

  @param   Sender as a TObject

**)
Procedure TITHelperIDENotifier.SuccessfulCompile(Sender: TObject);

Begin
  If FLastSuccessfulCompile + 1000 > GetTickCount Then
    Begin
      FLastSuccessfulCompile := 0;
      If FGlobalOps.SwitchToMessages Then
        ShowHelperMessages(FGlobalOps.GroupMessages);
    End;
End;

(**

  This method build a response file for a command line zip tool in order to backup all the files required
  to build this project.

  @precon  ProjectOps and Project must be valid instances.
  @postcon Build a response file for a command line zip tool in order to backup all the files required 
           to build this project.

  @param   ProjectOps as a TITHProjectOptions as a constant
  @param   Project    as an IOTAProject as a constant
  @return  an Integer

**)
Function TITHelperIDENotifier.ZipProjectInformation(Const ProjectOps : TITHProjectOptions;
  Const Project: IOTAProject): Integer;

Var
  slResponseFile: TStringList;
  i: Integer;
  strFileName: String;
  strZIPName: String;
  strBasePath: String;
  strProject: String;
  Process: TITHProcessInfo;

Begin
  Result := 0;
  strProject := GetProjectName(Project);
  If ProjectOps.EnableZipping Then
    Begin
      slResponseFile := TStringList.Create;
      Try
        slResponseFile.Duplicates := dupIgnore;
        slResponseFile.Sorted := True;
        strZIPName := ProjectOps.ZipName;
        If strZIPName <> '' Then
          Begin
            strBasePath := ExpandMacro(ProjectOps.BasePath, Project);
            Process.FEnabled := True;
            Process.FEXE := ExpandMacro(FGlobalOps.ZipEXE, Project);
            Process.FParams := ExpandMacro(FGlobalOps.ZipParameters, Project);
            If Not FileExists(Process.FEXE) Then
              Begin
                Inc(Result);
                AddMsg(Format('ZIP Tool (%s) not found! (%s).',
                  [Process.FEXE, strProject]), FGlobalOps.GroupMessages,
                  FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnHeader],
                  FGlobalOps.FontColour[ithfFailure],
                  FGlobalOps.FontStyles[ithfFailure]);
                Exit;
              End;
            strZIPName := ExpandMacro(strZIPName, Project);
            strFileName := BuildResponseFile(Project, ProjectOps, slResponseFile,
              strBasePath, strProject, strZIPName);
            With Process Do
              FParams := StringReplace(FParams, '$RESPONSEFILE$', strFileName, []);
            With Process Do
              FParams := StringReplace(FParams, '$FILELIST$', FileList(slResponseFile), []);
            With Process Do
              FParams := StringReplace(FParams, '$ZIPFILE$', strZIPName, []);
            Process.FDir := ExpandMacro(strBasePath, Project);
            FParentMsg :=
              AddMsg(Format('Running: %s (%s %s)', [ExtractFileName(Process.FEXE),
              strProject, 'Zipping']), FGlobalOps.GroupMessages,
              FGlobalOps.AutoScrollMessages, FGlobalOps.FontName[fnHeader],
              FGlobalOps.FontColour[ithfHeader], FGlobalOps.FontStyles[ithfHeader]);
            TfrmITHProcessing.ShowProcessing(Format('Processing %s...',
              [ExtractFileName(Process.FEXE)]));
            FMsgs.Clear;
            Result := DGHCreateProcess(Process, ProcessMsgHandler, IdleHandler);
            For i := 0 To FMsgs.Count - 1 Do
              Case Result Of
                0:
                  (FMsgs.Items[i] As TCustomMessage).ForeColour :=
                    FGlobalOps.FontColour[ithfSuccess];
              Else
                (FMsgs.Items[i] As TCustomMessage).ForeColour :=
                  FGlobalOps.FontColour[ithfFailure];
              End;
            If Result <> 0 Then
              FParentMsg.ForeColour := FGlobalOps.FontColour[ithfFailure];
          End Else
            AddMsg(Format('ZIP File not configured (%s).', [strProject]),
              FGlobalOps.GroupMessages, FGlobalOps.AutoScrollMessages,
              FGlobalOps.FontName[fnHeader], FGlobalOps.FontColour[ithfFailure],
              FGlobalOps.FontStyles[ithfFailure]);
        Finally
          If FileExists(strFileName) Then
            DeleteFile(strFileName);
          slResponseFile.Free;
        End;
    End;
End;

End.
