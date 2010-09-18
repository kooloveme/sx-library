//* File:     Lib\uError.pas
//* Created:  1999-12-01
//* Modified: 2004-04-28
//* Version:  X.X.31.X
//* Author:   Safranek David (Safrad)
//* E-Mail:   safrad@email.cz
//* Web:      http://safrad.webzdarma.cz

unit uError;

interface

uses
	Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
	ExtCtrls, StdCtrls, uDButton, ComCtrls, uDLabel, uWave, uAdd,
	uDForm, uDTimer, uDEdit;

type
	TDlgBtn = (
		mbOK, mbYes, mbYesToAll,
		mbRetry, mbIgnore, mbAbort,
		mbDelete, mbDeleteAll,
		mbNo, mbNoToAll, mbCancel);
	TDlgButtons = set of TDlgBtn;


	TfIOError = class(TDForm)
		ButtonRetry: TDButton;
		ButtonIgnore: TDButton;
		ButtonIgnoreAll: TDButton;
		ButtonExit: TDButton;
		ButtonOpen: TDButton;
		OpenDialogFile: TOpenDialog;
		MemoMsg: TMemo;
		Label1: TDLabel;
    PanelCount: TDLabel;
    Timer1: TDTimer;
    Image: TImage;
    LabelTimeLeft: TDLabel;
    PanelTimeLeft: TDLabel;
    LabelCreated: TDLabel;
		PanelCreated: TDLabel;
    LabelMessage: TDLabel;
    ButtonAll: TDButton;
		Bevel1: TBevel;
    ButtonDown: TDButton;
		EditIndex: TDEdit;
		ButtonUp: TDButton;
		procedure ButtonOpenClick(Sender: TObject);
		procedure ButtonExitClick(Sender: TObject);
		procedure FormKeyDown(Sender: TObject; var Key: Word;
			Shift: TShiftState);
		procedure FormKeyUp(Sender: TObject; var Key: Word;
			Shift: TShiftState);
		procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
			Y: Integer);
		procedure Timer1Timer(Sender: TObject);
		procedure LabelTimeLeftClick(Sender: TObject);
		procedure ButtonRetryClick(Sender: TObject);
		procedure ButtonIgnoreClick(Sender: TObject);
		procedure ButtonIgnoreAllClick(Sender: TObject);
		procedure ButtonDownClick(Sender: TObject);
		procedure EditIndexChange(Sender: TObject);
    procedure FormHide(Sender: TObject);
	private
		{ Private declarations }
		ActItem: UG;
		ShiftDown: BG;

		FButtons: array of TDButton;

		procedure DrawTimeLeft;
		procedure BClick(Sender: TObject);
		procedure ShowMes;
		procedure TryClose;
	public
		{ Public declarations }
	end;

const
	DlgBtnNames: array[TDlgBtn] of string = (
		'OK', 'Yes', 'YesToAll',
		'Retry', 'Ignore', 'Abort',
		'Delete', 'DeleteAll',
		'No', 'NoToAll', 'Cancel');

	DlgNoTime = 0;
	DlgWait = 15;

type
	TIgnoreAll = (iaNone, iaSame, iaAll);
var
	IgnoreAll: TIgnoreAll;

{$ifopt d+}
procedure IE; overload;
procedure IE(ErrorCode: SG); overload;
{$endif}
procedure CreateException;
function ErrorMes(const ErrorCode: U4): string;

procedure ShowMessages;
// Normal Dialog
function MessageD(Msg: string; DlgType: TMsgDlgType;
	Buttons: TDlgButtons): TDlgBtn;
function MessageDEx(Msg: string; DlgType: TMsgDlgType;
	Buttons: array of ShortString; TimeLeft: SG; Owener: TComponent): SG;
// IO Error
procedure IOError(FName: TFileName; const ErrorCode: U4);
function IOErrorRetry(var FName: TFileName; const ErrorCode: U4): Boolean;
// File Error
procedure IOErrorMessage(FName: TFileName; const ErrorMsg: string);
function IOErrorMessageRetry(var FName: TFileName; const ErrorMsg: string): Boolean;
// Internal Error
procedure ErrorMessage(ErrorMsg: string);
function ErrorMessageRetry(ErrorMsg: string): Boolean;

implementation

{$R *.DFM}
uses
	uStrings, uGraph, uDBitmap, uData, uInput,
	Registry, MMSystem, Consts, Math;

type
	TStyle = (stNormal, stInternal, stIO, stFile);

	PIgnore = ^TIgnore;
	TIgnore = packed record // 32
		Style: TStyle; // 1
		Retry: B1; // 1
		Ignore: TIgnoreAll; // 1
		DlgType: TMsgDlgType; // 1

		Msg: string; // 4
		ErrorFileName: TFileName; // 4
		Res: S4; // 4

		Buttons: array of ShortString; // 4

		DateTime: TDateTime; // 4
		TimeLeft: U4; // 4
//		Reserved: array[0..3] of U1; // 4
	end;

var
	fIOError: TfIOError;
	Ignores: TData;
	Ignore: PIgnore;
	TickCount, StartTickCount: U8;

{$ifopt d+}
procedure IE;
begin
	IE(0);
end;

procedure IE(ErrorCode: SG);
var S: string;
begin
//	{$ifopt d+}
	S := 'Internal Error ' + IntToStr(ErrorCode);
	ErrorMessage(S);
//	{$else}
//	PlayWinSound(wsCriticalStop);
//	{$endif}
end;
{$endif}

procedure CreateException;
begin
	asm
	mov eax, $ffffffff
	call eax
	end;
end;

function ErrorMes(const ErrorCode: U4): string;
var
	NewLength: SG;
begin
	SetLength(Result, MAX_PATH);
	NewLength := FormatMessage(
		{FORMAT_MESSAGE_ALLOCATE_BUFFER or}
		FORMAT_MESSAGE_FROM_SYSTEM or
		FORMAT_MESSAGE_IGNORE_INSERTS,
		nil,
		ErrorCode,
		LANG_NEUTRAL or SUBLANG_DEFAULT shl 10,
		PChar(Result),
		MAX_PATH,
		nil);
	SetLength(Result, NewLength);
	Replace(Result, CharCR + CharLF, ' ');
	DelBESpace(Result);
	Result := Result + ' (' + NToS(ErrorCode) + ')';
end;

// TfIOError

procedure TfIOError.DrawTimeLeft;
begin
//	if StartTickCount > 0 then
// D??? Error Ignore.TimeLeft not inicialized
	PanelTimeLeft.Caption := msToStr(1000 * UG(Ignore.TimeLeft) + StartTickCount - TickCount, diMSD, 0, False);
end;

var
	Captions: array[TMsgDlgType] of string = (SMsgDlgWarning, SMsgDlgError,
		SMsgDlgInformation, SMsgDlgConfirm, '');
	IconIDs: array[TMsgDlgType] of PChar = (IDI_EXCLAMATION, IDI_HAND,
		IDI_ASTERISK, IDI_QUESTION, nil);

procedure TfIOError.ButtonOpenClick(Sender: TObject);
var FExt: string;
begin
	FExt := ExtractFileExt(Ignore.ErrorFileName);
	if Length(FExt) > 0 then
		OpenDialogFile.Filter := '(*' + FExt + ')|*' + FExt + '|Any file (*.*)|*.*'
	else
		OpenDialogFile.Filter := 'Any file (*.*)|*.*';
	OpenDialogFile.FileName := Ignore.ErrorFileName;
	if OpenDialogFile.Execute then
	begin
		Ignore.ErrorFileName := OpenDialogFile.FileName;
		Ignore.Res := 3;
		TryClose;
	end;
end;

procedure TfIOError.ShowMes;
var
	IconID: PChar;
	Bo: BG;
	i, LastLine: SG;
	Wid, Hei, BWid, MaxWid, LineCount: SG;
const
	BMinWidth = 81;
	BHeight = 23;
begin
	Ignore := PIgnore(Ignores.Get(ActItem));

	// Captions
	EditIndex.Text:= NToS(ActItem + 1);
	PanelCreated.Caption := DateTimeToStr(Ignore.DateTime);
	case Ignore.Style of
	stNormal:
	begin
		if Ignore.DlgType <> mtCustom then
			Caption := string(Captions[Ignore.DlgType])
		else
			Caption := Application.Title;

		IconID := IconIDs[Ignore.DlgType];
	end;
	stInternal:
	begin
		Caption := 'Internal Error';
		IconID := IDI_APPLICATION;
	end;
	stIO:
	begin
		Caption := 'I/O Error';
		IconID := IDI_WINLOGO;
	end;
	stFile:
	begin
		Caption := 'File Error';
		IconID := IDI_WINLOGO;
	end
	else
	begin
		Caption := '';
		IconID := nil;
	end;
	end;

	// Image
	if IconID <> nil then
	begin
		Image.Name := 'Image';
		Image.Picture.Icon.Handle := LoadIcon(0, IconID);
	end;

	MaxWid := PanelCreated.Left + PanelCreated.Width + FormBorder;

	// Message Text
	LineCount := 1;
	LastLine := 1;
	for i := 1 to Length(Ignore.Msg) + 1 do
		if (i = Length(Ignore.Msg) + 1) or (Ignore.Msg[i] = CharLF) then
		begin
			Inc(LineCount);
			Wid := Canvas.TextWidth(Copy(Ignore.Msg, LastLine, i - LastLine)) + 4 + FormBorder + MemoMsg.Left;
			if Wid > MaxWid then MaxWid := Wid;
			LastLine := i + 1;
		end;

	// Buttons
	Bo := Ignore.Style in [stIO, stFile];
	ButtonRetry.Visible := Bo;
	ButtonIgnore.Visible := Bo;
//	ButtonIgnoreAll.Visible := B;
	ButtonOpen.Visible := Bo;

//	ButtonExit.Visible := Bo;

	BWid := 0;
	if Bo = False then
	begin
		if Length(Ignore.Buttons) > Length(FButtons) then SetLength(FButtons, Length(Ignore.Buttons));
		for i := 0 to Length(FButtons) - 1 do
		begin
			if i < Length(Ignore.Buttons) then
			begin
				if not Assigned(FButtons[i]) then
				begin
					FButtons[i] := TDButton.Create(Self);
					FButtons[i].OnKeyDown := FormKeyDown;
					FButtons[i].OnKeyUp := FormKeyUp;
					FButtons[i].OnMouseMove := FormMouseMove;

					InsertControl(FButtons[i]);
				end;

				FButtons[i].Name := 'Button' + IntToStr(i);
				FButtons[i].Caption := Ignore.Buttons[i];
				FButtons[i].Visible := True;
	//			(ButtonAll.Left + ButtonAll.Width + BSpace + (BWidth + BSpace) * (2 * i - ButtonCount) + BSpace + MaxWid) div 2;
				FButtons[i].Left := 0;
				FButtons[i].Width := Max(BMinWidth, Canvas.TextWidth(FButtons[i].Caption) + 2 * 5);
				Inc(BWid, FButtons[i].Width + FormBorder);
				FButtons[i].Top := 0;

				FButtons[i].Height := BHeight;
				FButtons[i].OnClick := BClick;
				FButtons[i].Default :=  i = 0;
				FButtons[i].TabOrder := i + 4;
				FButtons[i].TabStop := True;
				FButtons[i].Tag := i;
				FButtons[i].Down := Ignore.Res = i;
				FButtons[i].Enabled := Ignore.Res = -1;
				if (i = 0) and (FButtons[i].Enabled) then
					ActiveControl := FButtons[i];
				FButtons[i].Cancel := i = Length(Ignore.Buttons) - 1;
			end
			else if not Assigned(FButtons[i]) then
				FButtons[i].Visible := False;

		end;

		Wid := BWid + MemoMsg.Left;
	end
	else
	begin
		ButtonOpen.Enabled := (Ignore.Res = -1) and Ignore.Retry;
		ButtonRetry.Enabled := (Ignore.Res = -1) and Ignore.Retry;
		ButtonRetry.Default := Ignore.Retry;
		ButtonIgnore.Enabled := Ignore.Res = -1;
		if ButtonRetry.Enabled then
			ActiveControl := ButtonRetry
		else if ButtonIgnore.Enabled then
			ActiveControl := ButtonIgnore;


		ButtonIgnore.Default := not Ignore.Retry;

		ButtonIgnore.Down := Ignore.Res = 1;
		ButtonRetry.Down := (Ignore.Res = 2);
		ButtonOpen.Down := (Ignore.Res = 3);

		Wid := ButtonOpen.Left + ButtonOpen.Width + FormBorder;
	end;

	MaxWid := Max(MaxWid, Wid);

	if MaxWid > Screen.Width - 2 * (Width - ClientWidth) then
		MaxWid := Screen.Width - 2 * (Width - ClientWidth);

	MemoMsg.Width := MaxWid - MemoMsg.Left - FormBorder + 6;
	Hei := Max(LineCount, 3) * Canvas.TextHeight(Ignore.Msg) + 6;

	MemoMsg.Height := Hei;

	MemoMsg.Lines.Clear;
	MemoMsg.Lines.Insert(0, ReplaceF(Ignore.Msg, CharLF, CharCR + CharLF));
//	Hei := Max(Hei, ButtonAll.Top + ButtonAll.Height + 6);
	Inc(Hei, MemoMsg.Top + FormBorder);
	ClientWidth := MaxWid;
	ClientHeight := Hei + BHeight + FormBorder;//ButtonA.Top + ButtonA.Height + BSpace;

	ButtonAll.Down := Ignore.Ignore <> iaNone;
	ButtonAll.Enabled := Ignore.Res = -1;
	ButtonAll.Top := Hei;

	if Bo = False then
	begin
		Wid := MaxWid - BWid;
		for i := 0 to Length(Ignore.Buttons) - 1 do
		begin
			FButtons[i].Left := Wid;
			Inc(Wid, FButtons[i].Width + FormBorder);
			FButtons[i].Top := Hei;
		end;
	end
	else
	begin
		ButtonRetry.Top := Hei;
		ButtonIgnore.Top := Hei;
		ButtonOpen.Top := Hei;
	end;
end;
{
procedure TfIOError.UpDown1ChangingEx(Sender: TObject;
	var AllowChange: Boolean; NewValue: SmallInt;
	Direction: TUpDownDirection);
begin
	if NewValue < 0 then
	begin
		AllowChange := False;
		Exit;
	end;
	if NewValue >= SG(Ignores.Count) then
	begin
		AllowChange := False;
		Exit;
	end;
	EditIndex.Text := NToS(NewValue + 1);
	ShowMes(NewValue);
end;}

procedure TfIOError.ButtonExitClick(Sender: TObject);
begin
	if Assigned(Application.MainForm) and (ShiftDown = False){(GetAsyncKeyState(VK_SHIFT) = 0)} then
		Application.MainForm.Close
	else
	begin
		TerminateProcess(GetCurrentProcess, 1);
//		Halt;
	end;
end;

procedure TfIOError.FormKeyDown(Sender: TObject; var Key: Word;
	Shift: TShiftState);
begin
	if (ShiftDown = False) and (Key = VK_SHIFT) then
	begin
		ShiftDown := True;
		ButtonAll.Caption := 'Never Show';
		ButtonExit.Caption := 'Terimante';
	end;
end;

procedure TfIOError.FormKeyUp(Sender: TObject; var Key: Word;
	Shift: TShiftState);
begin
	if (ShiftDown = True) and (Key = VK_SHIFT) then
	begin
		ShiftDown := False;
		ButtonAll.Caption := 'Use Answer for All';
		ButtonExit.Caption := 'Close Program';
	end;
end;

procedure TfIOError.FormMouseMove(Sender: TObject; Shift: TShiftState;
	X, Y: Integer);
begin
	StartTickCount := TickCount;
	Timer1Timer(Sender);
end;

procedure TfIOError.Timer1Timer(Sender: TObject);
begin
	TickCount := GetTickCount;
	DrawTimeLeft;
	if TickCount > Ignore.TimeLeft * 1000 + StartTickCount then Close;
end;

function DoForm(
	const Style: TStyle; var FName: TFileName; const ErrorCode: U4;
	ErrorMsg: string; const Retry: Boolean;
	DlgType: TMsgDlgType;
	Buttons: array of ShortString; TimeLeft: SG; Owener: TComponent): SG;

var
	s: string;
	i: SG;
	FoundSame: BG;
	Ignore: PIgnore;
	LineIndex: SG;
	B: SG;
begin
	// Win X pressed
	case Style of
	stNormal, stInternal:
		Result := -1; // None of Button
	else // stIO, stFile:
		Result := 2; // Ignore
	end;

	if Ignores = nil then Exit;

	if Style = stIO then
		ErrorMsg := ErrorMes(ErrorCode);
{	else
		s := ErrorMsg;}
	DelChars(ErrorMsg, '&');
	LineIndex := 1;
	s := ReadToChar(ErrorMsg, LineIndex, LineSep);

	FoundSame := False;
	if IgnoreAll = iaSame then
	begin
		for i := SG(Ignores.Count) - 1 downto 0 do
		begin
			Ignore := Ignores.Get(i);
			LineIndex := 1;
			if (Ignore.Ignore <> iaNone) then
			if (Ignore.Style = Style) and (Ignore.Retry = Retry) and (Ignore.DlgType = DlgType) then
			if (ReadToChar(Ignore.Msg, LineIndex, LineSep) = s) then
			begin
				FoundSame := True;
				Result := Ignore.Res;
				Break;
			end;
		end;
	end;
	if FName <> '' then ErrorMsg := ErrorMsg + LineSep + FName;

	Ignore := Ignores.Add;
	FillChar(Ignore^, SizeOf(Ignore^), 0);
	Ignore.Style := Style;
	Ignore.Retry := Retry;
	Ignore.DlgType := DlgType;
	Ignore.Msg := ErrorMsg;
	Ignore.ErrorFileName := FName;
	Ignore.Buttons := nil;
	SetLength(Ignore.Buttons, Length(Buttons));
	for B := 0 to Length(Buttons) - 1 do
	begin
		Ignore.Buttons[B] := Buttons[B];
	end;
	Ignore.Res := -1;
	Ignore.Ignore := iaNone;
	Ignore.DateTime := Now;
	Ignore.TimeLeft := TimeLeft;

	if (IgnoreAll <> iaAll) and (FoundSame = False) then
	begin
		if Style = stNormal then
			PlayWinSound(wsQuestion)
		else
			PlayWinSound(wsCriticalStop);

		if not Assigned(fIOError) then
		begin
			fIOError := TfIOError.Create(Owener);
			fIOError.Background := baGradient;
		end;

		if Assigned(fIOError) then
		begin
//			fIOError.UpDown1.OnChangingEx := nil;
//			fIOError.UpDown1.Max := Ignores.Count - 1;
//			fIOError.UpDown1.OnChangingEx := fIOError.UpDown1ChangingEx;
			fIOError.PanelCount.Caption := NToS(Ignores.Count);
		end;

 		if fIOError.Visible = False then
		begin
			TickCount := GetTickCount;
			StartTickCount := TickCount;
{			fIOError.UpDown1.OnChangingEx := nil;
			fIOError.UpDown1.Position := Ignores.Count - 1;
			fIOError.UpDown1.OnChangingEx := fIOError.UpDown1ChangingEx;}
			fIOError.ActItem := Ignores.Count - 1;
			fIOError.EditIndex.Text := NToS(fIOError.ActItem);
			fIOError.ShowMes;
			fIOError.DrawTimeLeft;

			fIOError.ModalResult := mrNone;
			if Application.Terminated then
			begin
				fIOError.FormStyle := fsStayOnTop;
				fIOError.Timer1.Enabled := True;
				fIOError.Show;
				repeat
					Application.HandleMessage;
				until fIOError.ModalResult <> mrNone;
				fIOError.Hide;
			end
			else
			begin
				fIOError.FormStyle := fsNormal;
//				if fIOError.Visible = True then Exit;
				fIOError.Timer1.Enabled := True;
				fIOError.ShowModal;
			end;
		end
		else
		begin
			while Ignore.Res = -1 do
			begin
//				Application.HandleMessage;
				Application.ProcessMessages;
//				uDTimer.TryTimer;
				Sleep(20);
			end;
		end;

//		if ModalResult = mrNone then ModalResult := mrCancel;
		if Ignore.Res = -1 then
		begin
			// X win button pressed
			Ignore.Res := Result
		end
		else
			Result := Ignore.Res;
		if Ignore.ErrorFileName <> FName then FName := Ignore.ErrorFileName;

		if IsMultiThread then
		begin
			fIOError.Free;
			fIOError := nil;
		end;
	end
	else
		Ignore.Res := Result;
end;

procedure TfIOError.LabelTimeLeftClick(Sender: TObject);
begin
	Timer1.Enabled := False;
end;

procedure TfIOError.TryClose;
var
	i: SG;
	MCount, Last: SG;
begin
	if ButtonAll.Down = False then
		Ignore.Ignore := iaNone
	else
	begin
		if fIOError.ShiftDown then
		begin
			Ignore.Ignore := iaAll;
			IgnoreAll := iaAll;
		end
		else
		begin
			Ignore.Ignore := iaSame;
			IgnoreAll := iaSame;
		end;


	end;

	MCount := 0;
	Last := -1;
	for i := 0 to Ignores.Count - 1 do
	begin
		if TIgnore(Ignores.Get(i)^).Res = -1 then
		begin
			if Last = -1 then Last := i;
			Inc(MCount);
		end;
	end;
	if MCount = 0 then
		Close
	else
	begin
		ActItem := Last;
		ShowMes;
	end;
	ModalResult := mrCancel;
end;

// Button Clicks

procedure TfIOError.BClick(Sender: TObject);
begin
	Ignore.Res := TDButton(Sender).Tag;
	TryClose;
end;

procedure TfIOError.ButtonRetryClick(Sender: TObject);
begin
	Ignore.Res := 2;
	TryClose;
end;

procedure TfIOError.ButtonIgnoreClick(Sender: TObject);
begin
	Ignore.Res := 1;
	TryClose;
end;

procedure TfIOError.ButtonIgnoreAllClick(Sender: TObject);
begin
{	if fIOError.ShiftDown then
		IgnoreAll := iaAll
	else
		IgnoreAll := iaSame;
	Ignore.Res := ;
	TryClose;}
end;

// Public

procedure ShowMessages;
begin
	if Assigned(fIOError) then
	begin
		fIOError.ShowMes;
		fIOError.ShowModal;
	end
	else
		MessageD('No message found', mtInformation, [mbOk]);
end;

function MessageDEx(Msg: string; DlgType: TMsgDlgType;
	Buttons: array of ShortString; TimeLeft: SG; Owener: TComponent): SG;
var
	FileName: TFileName;
begin
	FileName := '';
	Result := DoForm(stNormal, FileName, 0, Msg, False, DlgType, Buttons, TimeLeft, Owener);
end;

function MessageD(Msg: string; DlgType: TMsgDlgType;
	Buttons: TDlgButtons): TDlgBtn;
var
	B: TDlgBtn;
	Res, i: SG;
	But: array of ShortString;

	procedure AddS(s: string);
	begin
		SetLength(But, Length(But) + 1);
		But[Length(But) - 1] := s;
	end;

begin
	for B := Low(B) to High(B) do
		if B in Buttons then AddS(DlgBtnNames[B]);
	Res := MessageDEx(Msg, DlgType, But, DlgWait, nil);
	i := 0;
	Result := mbCancel;
	for B := Low(B) to High(B) do
		if B in Buttons then
		begin
			if i = Res then
			begin
				Result := B;
				Break;
			end;
			Inc(i);
		end;
end;

procedure IOError(FName: TFileName; const ErrorCode: U4);
begin
	DoForm(stIO, FName, ErrorCode, '', False, mtCustom, [], DlgWait, Application.MainForm);
end;

function IOErrorRetry(var FName: TFileName; const ErrorCode: U4): Boolean;
begin
	Result := DoForm(stIO, FName, ErrorCode, '', True, mtCustom, [], DlgWait, Application.MainForm) > 1;
end;

procedure IOErrorMessage(FName: TFileName; const ErrorMsg: string);
begin
	DoForm(stFile, FName, 0, ErrorMsg, False, mtCustom, [], DlgWait, Application.MainForm);
end;

function IOErrorMessageRetry(var FName: TFileName; const ErrorMsg: string): Boolean;
begin
	Result := DoForm(stFile, FName, 0, ErrorMsg, True, mtCustom, [], DlgWait, Application.MainForm) > 1;
end;

procedure ErrorMessage(ErrorMsg: string);
var FName: TFileName;
begin
	DoForm(stInternal, FName, 0, ErrorMsg, False, mtCustom, ['OK'], DlgWait, Application.MainForm);
end;

function ErrorMessageRetry(ErrorMsg: string): Boolean;
var FName: TFileName;
begin
	Result := DoForm(stInternal, FName, 0, ErrorMsg, True, mtCustom, ['OK'], DlgWait, Application.MainForm) > 1;
end;

procedure TfIOError.ButtonDownClick(Sender: TObject);
begin
	if TDButton(Sender).Tag = 0 then
	begin
		if ActItem > 0 then
			Dec(ActItem);
	end
	else
	begin
		if ActItem < Ignores.Count - 1 then
			Inc(ActItem);
	end;
	ShowMes;
end;

procedure TfIOError.EditIndexChange(Sender: TObject);
begin
	ActItem := StrToValI(EditIndex.Text, True, 1, ActItem + 1, Ignores.Count, 1) - 1;
	ShowMes;
end;

procedure TfIOError.FormHide(Sender: TObject);
begin
	fIOError.Timer1.Enabled := False;
end;

initialization
	Ignores := TData.Create;
	Ignores.ItemSize := SizeOf(TIgnore);
finalization
	Ignores.Free; Ignores := nil;
end.