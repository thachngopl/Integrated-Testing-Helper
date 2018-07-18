(**
  
  This module contains a frame for the Global Options for ITHelper.

  @Version 1.0
  @Author  David Hoyle
  @Date    18 Jul 2018
  
**)
Unit ITHelper.GlobalOptionsFrame;

Interface

Uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Buttons,
  ToolsAPI,
  ITHelper.Types,
  ITHelper.Interfaces;

Type
  (** A frame to hold the global options. **)
  TframeGlobalOptions = Class(TFrame, IITHOptionsFrame)
    btnAssign: TBitBtn;
    dlgOpenEXE: TOpenDialog;
    lvShortcuts: TListView;
    hkShortcut: THotKey;
    edtZipParams: TEdit;
    edtZipEXE: TEdit;
    chkSwitchToMessages: TCheckBox;
    chkGroupMessages: TCheckBox;
    chkAutoScrollMessages: TCheckBox;
    btnBrowseZipEXE: TButton;
    udClearMessages: TUpDown;
    edtClearMessages: TEdit;
    lblShortcuts: TLabel;
    lblZipParams: TLabel;
    lblZIPEXE: TLabel;
    lblClearMessagesAfter: TLabel;
    Procedure btnBrowseZipEXEClick(Sender: TObject);
    Procedure lvShortcutsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    Procedure btnAssignClick(Sender: TObject);
  Strict Private
  Strict Protected
    Procedure InitialiseOptions(Const GlobalOps: IITHGlobalOptions; Const Project : IOTAProject;
      Const DlgType : TITHDlgType);
    Procedure SaveOptions(Const GlobalOps: IITHGlobalOptions; Const Project : IOTAProject;
      Const DlgType : TITHDlgType);
    Function IsValidated: Boolean;
  Public
    { Public declarations }
  End;

Implementation

Uses
  VCL.Menus,
  VCL.ActnList,
  ITHelper.TestingHelperUtils;

{$R *.dfm}

(**

  This is an on click event handler for the Assign button.

  @precon  None.
  @postcon Assigns the shortcut to the selected action.

  @param   Sender as a TObject

**)
procedure TframeGlobalOptions.btnAssignClick(Sender: TObject);

begin
  If lvShortcuts.ItemIndex >  -1 Then
    lvShortcuts.Selected.SubItems[0] := ShortCutToText(hkShortcut.HotKey);
end;

(**

  This is an on click event handler for the Browse Version From EXE button.

  @precon  None.
  @postcon Allows the user to select an executable from which to get version
           information.

  @param   Sender as a TObject

**)
Procedure TframeGlobalOptions.btnBrowseZipEXEClick(Sender: TObject);

Begin
  dlgOpenEXE.InitialDir := ExtractFilePath(edtZipEXE.Text);
  dlgOpenEXE.FileName   := ExtractFileName(edtZipEXE.Text);
  If dlgOpenEXE.Execute Then
    edtZipEXE.Text := dlgOpenEXE.FileName;
End;

(**

  This method initialises the project options in the dialogue.

  @precon  GlobalOps must be a valid instance.
  @postcon Initialises the project options in the dialogue.

  @nohint  Project DlgType

  @param   GlobalOps as an IITHGlobalOptions as a constant
  @param   Project   as an IOTAProject as a constant
  @param   DlgType   as a TITHDlgType as a constant

**)
Procedure TframeGlobalOptions.InitialiseOptions(Const GlobalOps: IITHGlobalOptions;
  Const Project : IOTAProject; Const DlgType : TITHDlgType);

Var
  i: Integer;
  A : Taction;
  Item : TListItem;

Begin
  chkGroupMessages.Checked      := GlobalOps.GroupMessages;
  chkAutoScrollMessages.Checked := GlobalOps.AutoScrollMessages;
  udClearMessages.Position      := GlobalOps.ClearMessages;
  edtZipEXE.Text                := GlobalOps.ZipEXE;
  edtZipParams.Text             := GlobalOps.ZipParameters;
  chkSwitchToMessages.Checked   := GlobalOps.SwitchToMessages;
  For i := 0 To TITHToolsAPIFunctions.Actions.Count - 1 Do
    If TITHToolsAPIFunctions.Actions[i] Is TAction Then
      Begin
        A := TITHToolsAPIFunctions.Actions[i] As TAction;
        Item := lvShortcuts.Items.Add;
        Item.Caption := A.Name;
        Item.SubItems.Add(ShortCutToText(A.ShortCut));
      End;
  hkShortcut.HotKey := 0;
End;

(**

  This method validates the dialogue.

  @precon  None.
  @postcon There is no validation currently needed.

  @return  a Boolean

**)
Function TframeGlobalOptions.IsValidated: Boolean;

Begin
  Result := True;
End;

(**

  This is an on select item event handler for the list view.

  @precon  None.
  @postcon Assigns the actions short cut to the Hot Key control.

  @param   Sender   as a TObject
  @param   Item     as a TListItem
  @param   Selected as a Boolean

**)
procedure TframeGlobalOptions.lvShortcutsSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);

begin
  btnAssign.Enabled := Selected;
  If Selected Then
    hkShortcut.HotKey := TextToShortCut(Item.SubItems[0]);
end;

(**

  This method saves the project options to the ini file.

  @precon  GlobalOps must be a valid instance.
  @postcon Saves the project options to the ini file.

  @nohint  Project DlgType

  @param   GlobalOps as an IITHGlobalOptions as a constant
  @param   Project   as an IOTAProject as a constant
  @param   DlgType   as a TITHDlgType as a constant

**)
Procedure TframeGlobalOptions.SaveOptions(Const GlobalOps: IITHGlobalOptions;
  Const Project : IOTAProject; Const DlgType : TITHDlgType);

Var
  i: Integer;
  A: TAction;

Begin
  GlobalOps.GroupMessages      := chkGroupMessages.Checked;
  GlobalOps.AutoScrollMessages := chkAutoScrollMessages.Checked;
  GlobalOps.ClearMessages      := udClearMessages.Position;
  GlobalOps.ZipEXE             := edtZipEXE.Text;
  GlobalOps.ZipParameters      := edtZipParams.Text;
  GlobalOps.SwitchToMessages   := chkSwitchToMessages.Checked;
  For i := 0 To TITHToolsAPIFunctions.Actions.Count - 1 Do
    If TITHToolsAPIFunctions.Actions[i] Is TAction Then
      Begin
        A := TITHToolsAPIFunctions.Actions[i] As TAction;
        A.ShortCut := TextToShortCut(lvShortcuts.Items[i].SubItems[0]);
      End;
End;

End.