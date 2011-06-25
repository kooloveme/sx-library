// * File:     Lib\GUI\uDWinControl.pas
// * Created:  2007-05-27
// * Modified: 2009-09-02
// * Version:  1.1.45.113
// * Author:   David Safranek (Safrad)
// * E-Mail:   safrad at email.cz
// * Web:      http://safrad.own.cz

unit uDWinControl;

interface

uses
	uTypes,
	Classes,
	Controls,
	Messages,
	Graphics,
	uDBitmap;

type
	TDWinControl = class(TWinControl)
	private
		FCanvas: TCanvas;
		FBitmap: TDBitmap;
		FNeedFill: BG;
		{$ifdef info}
		FFillCount, FPaintCount: UG;
		{$endif}
		FFocused: BG;
		procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
		procedure WMSize(var Message: TWMSize); message WM_SIZE;
		procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
		procedure CMFocusEnter(var Message: TCMEnter); message CM_ENTER;
		procedure CMFocusExit(var Message: TCMExit); message CM_EXIT;
	protected
		procedure FillBitmap; virtual;
	public
		constructor Create(AOwner: TComponent); override;
		destructor Destroy; override;
		property Canvas: TCanvas read FCanvas;
		procedure Invalidate; override;
	published
		property Bitmap: TDBitmap read FBitmap;
		property Font;
		property IsFocused: Boolean read FFocused;
		property ParentFont;
	end;

procedure CorrectFont(const Font: TFont);
function GetSectionName(Control: TControl): string;

implementation

uses
	SysUtils, Windows,
	uSysInfo, uMsg;

procedure CorrectFont(const Font: TFont);
var
	MyStruct: TNonClientMetricsA;
begin
//	MyStruct.cbSize := TNonClientMetricsA.SizeOf;
//	MyStruct.cbSize := SizeOf(TNonClientMetricsA);
	MyStruct.cbSize := 340;

	if SystemParametersInfoA(
		SPI_GETNONCLIENTMETRICS,
		MyStruct.cbSize,
		@MyStruct,
		0) then
	begin
		MyStruct.lfMessageFont.lfHeight := -11; // TODO : Variable form and control size required
		{$ifopt d+}
//		MyStruct.lfMessageFont.lfHeight := -13;
		{$endif}
	(*	if NTSystem and (MyStruct.lfMessageFont.lfFaceName = 'MS Sans Serif') then
		begin
	//		{$ifopt d-}
			MyStruct.lfMessageFont.lfFaceName := 	'Microsoft Sans Serif'; // OpenType Font (nicer)
	//		{$else}
	//		MyStruct.lfMessageFont.lfFaceName := 	'Lucida Console';//'Courier New CE';//'Tahoma'; // OpenType Font (nicer)
	//		{$endif}
		end; *)

		Font.Handle := CreateFontIndirectA(MyStruct.lfMessageFont);
	end;
{	else
		ErrorMsg(GetLastError()); // Hang - call CorrectFont again }
end;

function GetSectionName(Control: TControl): string;
begin
	if Assigned(Control.Parent) then
		Result := Control.Parent.Name + '.'
	else
		Result := '';
	Result := Result + Control.Name;
end;

{ TDWinControl }

// TODO : Focus Enter/Leave

procedure TDWinControl.CMFocusEnter(var Message: TCMEnter);
begin
	FFocused := True;
	Invalidate;
end;

procedure TDWinControl.CMFocusExit(var Message: TCMExit);
begin
	FFocused := False;
	Invalidate;
end;

constructor TDWinControl.Create(AOwner: TComponent);
begin
	inherited;

	FBitmap := TDBitmap.Create;

	FCanvas := TControlCanvas.Create;
	TControlCanvas(FCanvas).Control := Self;
end;

destructor TDWinControl.Destroy;
begin
	FreeAndNil(FCanvas);
	FreeAndNil(FBitmap);
	inherited;
end;

procedure TDWinControl.FillBitmap;
begin
{	if not Assigned(FBitmap) then
		FBitmap := TDBitmap.Create;}
	FBitmap.Canvas.Font := Font;
	FNeedFill := False;
	{$ifdef info}
	Inc(FFillCount);
	{$endif}
	FBitmap.SetSize(Width, Height, Color);
end;

procedure TDWinControl.Invalidate;
begin
	FNeedFill := True;
	inherited Invalidate;
end;

procedure TDWinControl.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
	Message.Result := 1;
end;

procedure TDWinControl.WMPaint(var Message: TWMPaint);
begin
	inherited;
	{$ifdef info}
	Inc(FPaintCount);
	{$endif}
	if FNeedFill then FillBitmap;

	if Bitmap.Empty then
	begin
		FCanvas.Brush.Style := bsSolid;
		FCanvas.Brush.Color := clAppWorkSpace;
		PatBlt(
			FCanvas.Handle,
			0,
			0,
			Width,
			Height,
			PATCOPY
		);
	end
	else
	begin
		FBitmap.DrawToDC(FCanvas.Handle, 0, 0);
	end;
{	if Assigned(FOnPaint) then
	begin
		try
			FOnPaint(Self);
		except
			on E: Exception do
				Fatal(E, Self);
		end;
	end;}

	{$ifdef info}
	Canvas.Brush.Style := bsClear;
	Canvas.Font.Color := clWhite;
	Canvas.TextOut(0, 0, IntToStr(FFillCount) + '/' + IntToStr(FPaintCount));
	{$endif}
end;

procedure TDWinControl.WMSize(var Message: TWMSize);
begin
	inherited;
	FNeedFill := True;
end;

end.