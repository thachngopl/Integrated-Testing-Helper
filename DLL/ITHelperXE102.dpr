(**

  This module define a DLL which can be loaded in the BDS 2010 IDE and
  implement an IDE wizard.

  @Author  David Hoyle
  @Date    30 Dec 2017
  @Version 2.0

  @nocheck EmptyBEGINEND

  @todo    Change ALL (BorlandIDEServices As Xxxx) for Supports()
  @todo    Create a wrapper for the ziplibrary and use that instead of an external zip programme.
  @todo    Put the prject options back into a single tabbed dialogue (remember NOT to use listviews
           to store information).
  @todo    Put global options into the IDEs Options dialogue.

**)
Library ITHelperXE102;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

{$R 'SplashScreenIcon.res' '..\SplashScreenIcon.RC'}
{$R 'ITHelperVersionInfo.res' 'ITHelperVersionInfo.RC'}
{$R 'ITHelperMenuIcons.res' '..\ITHelperMenuIcons.rc'}

uses
  ShareMem,
  SysUtils,
  Classes,
  ITHelper.Wizard in '..\Source\ITHelper.Wizard.pas',
  ITHelper.ConfigurationForm in '..\Source\ITHelper.ConfigurationForm.pas' {frmITHConfigureDlg},
  ITHelper.TestingHelperUtils in '..\Source\ITHelper.TestingHelperUtils.pas',
  ITHelper.AdditionalZipFilesForm in '..\Source\ITHelper.AdditionalZipFilesForm.pas' {Form1},
  ITHelper.EnabledOptions in '..\Source\ITHelper.EnabledOptions.pas' {frmEnabledOptions},
  ITHelper.OTAInterfaces in '..\Source\ITHelper.OTAInterfaces.pas',
  ITHelper.ProjectManagerMenuInterface in '..\Source\ITHelper.ProjectManagerMenuInterface.pas',
  ITHelper.IDENotifierInterface in '..\Source\ITHelper.IDENotifierInterface.pas',
  ITHelper.GlobalOptions in '..\Source\ITHelper.GlobalOptions.pas',
  ITHelper.FontDialogue in '..\Source\ITHelper.FontDialogue.pas' {frmITHFontDialogue},
  ITHelper.ZIPDialogue in '..\Source\ITHelper.ZIPDialogue.pas' {frmITHZIPDialogue},
  ITHelper.GlobalOptionsDialogue in '..\Source\ITHelper.GlobalOptionsDialogue.pas' {frmITHGlobalOptionsDialogue},
  ITHelper.ProjectOptionsDialogue in '..\Source\ITHelper.ProjectOptionsDialogue.pas' {frmITHProjectOptionsDialogue},
  ITHelper.SplashScreen in '..\Source\ITHelper.SplashScreen.pas',
  ITHelper.CommonFunctions in '..\Source\ITHelper.CommonFunctions.pas',
  ITHelper.Constants in '..\Source\ITHelper.Constants.pas',
  ITHelper.ResourceStrings in '..\Source\ITHelper.ResourceStrings.pas',
  ITHelper.AboutBox in '..\Source\ITHelper.AboutBox.pas',
  ITHelper.ExternalProcessInfo in '..\Source\ITHelper.ExternalProcessInfo.pas',
  ITHelper.ProcessingForm in '..\Source\ITHelper.ProcessingForm.pas' {frmITHProcessing},
  ITHelper.ProgrammeInfoForm in '..\Source\ITHelper.ProgrammeInfoForm.pas' {frmProgrammeInfo};

{$R *.res}

Begin
End.

