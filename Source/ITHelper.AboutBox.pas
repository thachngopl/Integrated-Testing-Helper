(**
  
  This module contains code for added and removing about box entries in the IDE.

  @Author  David Hoyle
  @Version 1.0
  @Date    18 Jul 2018
  
**)
Unit ITHelper.AboutBox;

Interface

  Function  AddAboutBoxEntry : Integer;
  Procedure RemoveAboutBoxEntry(Const iAboutBoxIndex : Integer);

Implementation

Uses
  ToolsAPI,
  SysUtils,
  Windows,
  Forms, 
  ITHelper.ResourceStrings, 
  ITHelper.Constants, 
  ITHelper.CommonFunctions;

(**

  This method installs the about box entry in the IDE.

  @precon  None.
  @postcon The about box entry is installed and the return value is the index with whch to remove it
           later.

  @return  an Integer

**)
Function  AddAboutBoxEntry : Integer;

Const
  strITHelperSplashScreen48x48 = 'ITHelperSplashScreen48x48';
  {$IFDEF DEBUG}
  strSKUBuild = 'SKU DEBUG Build %d.%d.%d.%d';
  {$ELSE}
  strSKUBuild = 'SKU Build %d.%d.%d.%d';
  {$ENDIF}

ResourceString
  strPluginDescription = 'An IDE expert to allow the configuration of pre and post compilation ' + 
    'processes and automatically ZIP the successfully compiled project for release.';

Var
  bmSplashScreen : HBITMAP;
  recVersionInfo : TITHVersionInfo;
  ABS : IOTAAboutBoxServices;
  strModuleName: String;
  iSize: Cardinal;

Begin
  Result := -1;
  SetLength(strModuleName, MAX_PATH);
  iSize := GetModuleFileName(hInstance, PChar(strModuleName), MAX_PATH);
  SetLength(strModuleName, iSize);
  BuildNumber(strModuleName, recVersionInfo);
  bmSplashScreen := LoadBitmap(hInstance, strITHelperSplashScreen48x48);
  If Supports(BorlandIDEServices, IOTAAboutBoxServices, ABS) Then
    Begin
      Result := ABS.AddPluginInfo(
        Format(strSplashScreenName, [
          recVersionInfo.FMajor,
          recVersionInfo.FMinor,
          Copy(strRevisions, recVersionInfo.FBugFix + 1, 1),
          Application.Title]),
        strPluginDescription,
        bmSplashScreen,
        {$IFDEF DEBUG} True {$ELSE} False {$ENDIF},
        Format(strSplashScreenBuild, [
          recVersionInfo.FMajor,
          recVersionInfo.FMinor,
          recVersionInfo.FBugfix,
          recVersionInfo.FBuild]),
        Format(strSKUBuild, [
          recVersionInfo.FMajor,
          recVersionInfo.FMinor,
          recVersionInfo.FBugfix,
          recVersionInfo.FBuild]));
    End;
End;

(**

  This method removes the about box entry from the IDE with the given index.

  @precon  Must be a valid index for an about box entry.
  @postcon The about box entry is removed.

  @param   iAboutBoxIndex as an Integer as a constant

**)
Procedure RemoveAboutBoxEntry(Const iAboutBoxIndex : Integer);

Var
  ABS : IOTAAboutBoxServices;
  
Begin
  If iAboutBoxIndex > -1 Then
    If Supports(BorlandIDEServices, IOTAAboutBoxServices, ABS) Then
      ABS.RemovePluginInfo(iAboutBoxIndex);
End;

End.
