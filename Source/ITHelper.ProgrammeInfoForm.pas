(**

  This modules contains a form for specifying the EXE, Params and Working
  Directory for external tools.

  @Version 1.0
  @Author  David Hoyle
  @Date    03 Jan 2018

**)
Unit ITHelper.ProgrammeInfoForm;

Interface

Uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  Buttons,
  StdCtrls,
  ExtCtrls;

Type
  (** A class to represent the form. **)
  TfrmITHProgrammeInfo = Class(TForm)
    lblProgramme: TLabel;
    edtProgramme: TEdit;
    lblParameters: TLabel;
    edtParameters: TEdit;
    lblWorkingDirectrory: TLabel;
    edtWorkingDirectory: TEdit;
    btnEXE: TButton;
    btnDirectory: TButton;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    dlgOpen: TOpenDialog;
    edtTitle: TEdit;
    lblTitle: TLabel;
    Procedure btnEXEClick(Sender: TObject);
    Procedure btnDirectoryClick(Sender: TObject);
  Strict Private
  Strict Protected
    Procedure LoadPosition(Const strINIFile: String);
    Procedure SavePosition(Const strINIFile: String);
  Public
    Class Function Execute(Var strTitle, strEXE, strParam, strDir: String;
      Const strINIFile: String): Boolean;
  End;

Implementation

{$R *.dfm}


Uses
  FileCtrl,
  INIFiles;

Const
  (** An INI section name for the dialogue settings. **)
  strProgrammeInfoDlgSection = 'ProgrammeInfoDlg';
  (** An INI key for the dialogue top. **)
  strTopKey = 'Top';
  (** An INI key for the dialogue left. **)
  strLeftKey = 'Left';
  (** An INI key for the dialogue height. **)
  strHeightKey = 'Height';
  (** An INI key for the dialogue width. **)
  strWidthKey = 'Width';

(**

  This is an on click event handler for the Directory browse button.

  @precon  None.
  @postcon Allows the user to browse for a directory.

  @param   Sender as a TObject

**)
Procedure TfrmITHProgrammeInfo.btnDirectoryClick(Sender: TObject);

ResourceString
  strSelectWorkingDirectory = 'Select a Working Directory';

Var
  strDirectory: String;

Begin
  strDirectory := edtWorkingDirectory.Text;
  If strDirectory = '' Then
    strDirectory := ExtractFilePath(edtProgramme.Text);
  If SelectDirectory(strSelectWorkingDirectory, '', strDirectory,
    [sdNewFolder, sdShowShares, sdNewUI, sdValidateDir]) Then
    edtWorkingDirectory.Text := strDirectory + '\';
End;

(**

  This is an on click event handler for the EXE browse button.

  @precon  None.
  @postcon Allows the user to browse for EXE, BAT anmd BTM files.

  @param   Sender as a TObject

**)
Procedure TfrmITHProgrammeInfo.btnEXEClick(Sender: TObject);

Begin
  If dlgOpen.Execute Then
    Begin
      edtProgramme.Text := dlgOpen.Filename;
      If edtWorkingDirectory.Text = '' Then
        edtWorkingDirectory.Text := ExtractFilePath(dlgOpen.Filename);
    End;
End;

(**

  This is the classes interface Singleton method. If the dialogue is confirmed the information is 
  returned in the var parameters.

  @precon  None.
  @postcon If the dialogue is confirmed the information is returned in the var parameters .

  @param   strTitle   as a String as a reference
  @param   strEXE     as a String as a reference
  @param   strParam   as a String as a reference
  @param   strDir     as a String as a reference
  @param   strINIFile as a String as a constant
  @return  a Boolean

**)
Class Function TfrmITHProgrammeInfo.Execute(Var strTitle, strEXE, strParam, strDir: String;
      Const strINIFile: String): Boolean;

Var
  frm: TfrmITHProgrammeInfo;

Begin
  frm := TfrmITHProgrammeInfo.Create(Nil);
  Try
    Result := False;
    frm.edtTitle.Text := strTitle;
    frm.edtProgramme.Text := strEXE;
    frm.edtParameters.Text := strParam;
    frm.edtWorkingDirectory.Text := strDir;
    frm.LoadPosition(strINIFile);
    If frm.ShowModal = mrOK Then
      Begin
        strTitle := frm.edtTitle.Text;
        strEXE := frm.edtProgramme.Text;
        strParam := frm.edtParameters.Text;
        strDir := frm.edtWorkingDirectory.Text;
        frm.SavePosition(strINIFile);
        Result := True;
      End;
  Finally
    frm.Free;
  End;
End;

(**

  This method loads the position of the dialogue from the pased INI File.

  @precon  None.
  @postcon Loads the position of the dialogue from the pased INI File.

  @param   strINIFile as a String as a constant

**)
Procedure TfrmITHProgrammeInfo.LoadPosition(Const strINIFile: String);

Var
  iniFile: TMemIniFile;

Begin
  iniFile := TMemIniFile.Create(strINIFile);
  Try
    Top := iniFile.ReadInteger(strProgrammeInfoDlgSection, strTopKey, Application.MainForm.Top +
      Application.MainForm.Height Div 2 - Height Div 2);
    Left := iniFile.ReadInteger(strProgrammeInfoDlgSection, strLeftKey, Application.MainForm.Left
      + Application.MainForm.Width Div 2 - Width Div 2);
    Height := iniFile.ReadInteger(strProgrammeInfoDlgSection, strHeightKey, Height);
    Width := iniFile.ReadInteger(strProgrammeInfoDlgSection, strWidthKey, Width);
  Finally
    iniFile.Free;
  End;
End;

(**

  This method saves the position of the dialogue to the passed INI file.

  @precon  None.
  @postcon Saves the position of the dialogue to the passed INI file.

  @param   strINIFile as a String as a constant

**)
Procedure TfrmITHProgrammeInfo.SavePosition(Const strINIFile: String);

Var
  iniFile: TMemIniFile;

Begin
  iniFile := TMemIniFile.Create(strINIFile);
  Try
    iniFile.WriteInteger(strProgrammeInfoDlgSection, strTopKey, Top);
    iniFile.WriteInteger(strProgrammeInfoDlgSection, strLeftKey, Left);
    iniFile.WriteInteger(strProgrammeInfoDlgSection, strHeightKey, Height);
    iniFile.WriteInteger(strProgrammeInfoDlgSection, strWidthKey, Width);
    iniFile.UpdateFile;
  Finally
    iniFile.Free;
  End;
End;

End.
