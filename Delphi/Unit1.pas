unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.CheckLst, Vcl.Mask, Vcl.Menus, Vcl.ExtCtrls, Vcl.ComCtrls,
  JvExControls, JvExMask, JvToolEdit, JvgProgress, JvComponentBase, JvThread,
  Vcl.Clipbrd, System.Math, System.Hash, CalcCRC32;

type
  TForm1 = class(TForm)
    JvFilenameEdit1: TJvFilenameEdit;
    CheckListBox1: TCheckListBox;
    Button1: TButton;
    Button2: TButton;
    CheckBox1: TCheckBox;
    Label1: TLabel;
    Label2: TLabel;
    ListView1: TListView;
    JvgProgress1: TJvgProgress;
    PopupMenu1: TPopupMenu;
    SelectAll1: TMenuItem;
    ReverseSelect1: TMenuItem;
    N1: TMenuItem;
    CopyValue1: TMenuItem;
    N2: TMenuItem;
    Compare1: TMenuItem;
    Timer1: TTimer;
    JvThread1: TJvThread;
    JvThread2: TJvThread;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure JvFilenameEdit1Change(Sender: TObject);
    procedure JvThread1Begin(Sender: TObject);
    procedure JvThread1Execute(Sender: TObject; Params: Pointer);
    procedure JvThread1FinishAll(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure CheckListBox1ClickCheck(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ListView1ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure SelectAll1Click(Sender: TObject);
    procedure ReverseSelect1Click(Sender: TObject);
    procedure CopyValue1Click(Sender: TObject);
    procedure Compare1Click(Sender: TObject);
    procedure JvThread2Execute(Sender: TObject; Params: Pointer);
  private type
    THashType = (
      _HT_CRC32, _HT_MD5, _HT_SHA1,
      _HT_SHA224, _HT_SHA256, _HT_SHA384,
      _HT_SHA512, _HT_SHA512_224, _HT_SHA512_256
    );
    TProgressBarState = (
      PBS_Clear, PBS_Process, PBS_Pause, PBS_Stop, PBS_Complete, PBS_FileError
    );
  private const
//    HashSHA2_Count = Ord(SHA512_256) - Ord(SHA224) + 1; // THashSHA2::TSHA2Version
    BufferSize     = 1024 * 1024; // 16 * 1024
    BufferPages    = 2;
  private type
    THashParam = record
      Name: string;
      Value: string;
    end;
    PHashParam = ^THashParam;
    TBuffer = array[0..BufferSize-1] of Byte;
    TBufferPage = record
      Length: UInt64;
      Buffer: TBuffer;
    end;
    PBufferPage = ^TBufferPage;
    PHashMD5 = ^THashMD5;
    PHashSHA1 = ^THashSHA1;
    PHashSHA2 = ^THashSHA2;
    TSHA2Ver = THashSHA2.TSHA2Version;
  private
    FileName: string;
    BaseThread: TJvBaseThread;
    HashParam: THashParam;

    Percent: Integer;
    ThreadProcessing: Boolean;
    Paused: Boolean;
    Completed: Boolean;
    Pages: array[0..BufferPages-1] of TBufferPage;
    Page: PBufferPage;
    FileStream: TFileStream;
  //  HashCRC32: TIdHashCRC32;
    crc32: Cardinal;
    HashCrc32: Boolean;
    HashMD5: PHashMD5;
    HashSHA1: PHashSHA1;
    HashSHA2: array[TSHA2Ver] of PHashSHA2;
    TotalPauseTime: DWORD;
    PauseStartTime: DWORD;
    ExecuteStartTime: DWORD;
    procedure FinishAll;
    procedure Reset;
    procedure CopyToClipboard(Full: Boolean);
    procedure StartHashThread; inline;
    procedure WaitHashThread; inline;
    procedure ProgressUpdate;
    procedure SetProgressBarState(State: TProgressBarState);
    procedure ProgressActive(Active: Boolean);
    procedure AddListViewItem;
    procedure ShowRead;
    function ListChecked: Boolean;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  Winapi.MMSystem;

{$R *.dfm}

function FormatBytes(Bytes: UInt64; Float: Boolean = True): string;
const
  btc: array[0..4] of string = ('Bytes','KB','MB','GB','TB');
var
  I: Integer;
  f: Double;
begin
  I := 0;
  if Float then
  begin
    f := Bytes;
    while f >= 1024 do
    begin
      f := f / 1024;
      Inc(I);
    end;
    Result := FormatFloat('#,##0.00', f) + ' ' + btc[i];
  end
  else
  begin
    while Bytes >= 1024 do
    begin
      Bytes := Bytes div 1024;
      Inc(i);
    end;
    Result := FormatFloat('#,##0', Bytes) + ' ' + btc[i];
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  CheckListBox1.CheckAll(cbChecked, False, True);
  CheckListBox1ClickCheck(CheckListBox1);
  Reset;
//  JvFilenameEdit1.FileName := Application.ExeName;
  BaseThread := nil;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  JvThread1.TerminateWaitFor;
end;

procedure TForm1.JvFilenameEdit1Change(Sender: TObject);
begin
  Reset;
end;

procedure TForm1.JvThread1Begin(Sender: TObject);
var
  iSHA2: TSHA2Ver;
  FileSize: Int64;
  sha2: PHashSHA2;
begin
  JvFilenameEdit1.Enabled := False;
  CheckListBox1.Enabled := False;
  ListView1.Enabled := False;
  ListView1.Items.BeginUpdate;
  ListView1.Clear;
  Button1.Caption := 'Stop';
  FileName := JvFilenameEdit1.FileName;

//  HashCRC32 = 0;
  crc32     := 0;
  HashCrc32 := False;
  HashMD5   := nil;
  HashSHA1  := nil;
  FillChar(HashSHA2, SizeOf(HashSHA2), 0);

  try
    FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  except
    on E: Exception do
    begin
      FileStream := nil;
  //    JvgProgress1->Caption = SysErrorMessage(GetLastError());
      JvgProgress1.Caption := E.Message;
      SetProgressBarState(PBS_FileError);
    end;
  end;

  if Assigned(FileStream) then
  begin
    FileSize := FileStream.Size;
    if FileSize < 1024 then
      Label1.Caption := Format('File size: %s bytes', [FormatCurr('#,##0', FileSize)])
    else
      Label1.Caption := Format('File size: %s (%s bytes)', [FormatBytes(FileSize), FormatCurr('#,##0', FileSize)]);
    Label2.Caption := '';
    TotalPauseTime := 0;
    PauseStartTime := 0;
    ExecuteStartTime := timeGetTime;
    Timer1.Enabled := True;
  end
  else
    Exit;

  Completed := False;
  Percent := 0;
  JvgProgress1.Percent := 0;
  ProgressActive(False);
  Button2.Enabled := True;

  if CheckListBox1.Checked[0] then
  begin
//      HashCRC32 := TIdHashCRC32.Create();
    crc32 := _Crc32Initial;
    HashCrc32 := True;
  end;
  if CheckListBox1.Checked[1] then
  begin
    New(HashMD5);
    HashMD5.Reset;
  end;
  if CheckListBox1.Checked[2] then
  begin
    New(HashSHA1);
    HashSHA1.Reset;
  end;

  for iSHA2 := Low(TSHA2Ver) to High(TSHA2Ver) do
  begin
    if CheckListBox1.Checked[Integer(iSHA2) + 3] then
    begin
        New(sha2);
      HashSHA2[iSHA2] := sha2;
      sha2.FVersion := iSHA2;
      sha2.Reset;
    end;
  end;
end;

procedure TForm1.JvThread1Execute(Sender: TObject; Params: Pointer);
label
  gotoContinue;
var
  PageIndex: Integer;
  FileSize: Int64;
  FilePosition: Int64;
  Position: Integer;
  Timeout, ms: DWORD;
  NextPage: PBufferPage;
  sha2: PHashSHA2;
  iSHA2: TSHA2Ver;
  Strings: TStrings;
  f: Single;
  procedure SetSyncBuffer(const Name, Value: string);
  begin
    HashParam.Name := Name;
    HashParam.Value := Value;
  end;
begin
  if Assigned(FileStream) then
  begin
    if HashCrc32 or Assigned(HashMD5) or Assigned(HashSHA1) then
      goto gotoContinue
    else
    begin
      for iSHA2 := Low(TSHA2Ver) to High(TSHA2Ver) do
      begin
        if Assigned(HashSHA2[iSHA2]) then
          goto gotoContinue;
      end;
    end;
  end;
  Exit;
  gotoContinue:

  PageIndex := 0;
  NextPage := @Pages[PageIndex];
  NextPage.Length := FileStream.Read(NextPage.Buffer, BufferSize);
  FileSize := FileStream.Size;
  FilePosition := FileStream.Position;
  TThread.Synchronize(BaseThread, ProgressUpdate);

  Timeout := timeGetTime() + 50;
  repeat
    if BaseThread.Terminated then
    begin
      WaitHashThread;
      Exit;
    end;

    Page := NextPage;

    StartHashThread;

    if FilePosition >= FileSize then
    begin
      WaitHashThread;
      Break;
    end;

    Inc(PageIndex);
    if PageIndex >= BufferPages then
      PageIndex := 0;
    NextPage := @Pages[PageIndex];
    NextPage.Length := FileStream.Read(NextPage.Buffer, BufferSize);
    FilePosition := FileStream.Position;
    f := FilePosition;
    Position := Round(f / FileSize * 100);

    WaitHashThread;

    if Position <> Percent then
    begin
      Percent := Position;
      ms := timeGetTime;
      if ms > Timeout then
      begin
        Timeout := ms + 25;
        TThread.Synchronize(BaseThread, ProgressUpdate);
      end;
    end;
  until (False);

  Strings := CheckListBox1.Items;
  if HashCrc32 then
  begin
//      crc32 := not crc32;
    SetSyncBuffer(Strings.Strings[0], IntToHex(not crc32, SizeOf(crc32) * 2));
    TThread.Synchronize(BaseThread, AddListViewItem);
  end;
  if Assigned(HashMD5) then
  begin
    SetSyncBuffer(Strings.Strings[1], HashMD5.HashAsString);
    TThread.Synchronize(BaseThread, AddListViewItem);
  end;
  if Assigned(HashSHA1) then
  begin
    SetSyncBuffer(Strings.Strings[2], HashSHA1.HashAsString);
    TThread.Synchronize(BaseThread, AddListViewItem);
  end;
  for iSHA2 := Low(TSHA2Ver) to High(TSHA2Ver) do
  begin
    sha2 := HashSHA2[iSHA2];
    if Assigned(sha2) then
    begin
      SetSyncBuffer(Strings.Strings[Integer(iSHA2) + 3], sha2.HashAsString);
      TThread.Synchronize(BaseThread, AddListViewItem);
    end;
  end;
  Percent := 100;
  Completed := True;
  TThread.Synchronize(BaseThread, ProgressUpdate);
end;

procedure TForm1.FinishAll;
var
  iSHA2: TSHA2Ver;
  sha2: PHashSHA2;
begin
  if Assigned(FileStream) then
  begin
    Timer1.Enabled := False;
    ShowRead;
    FileStream.Free;
  end
  else
  begin
//    SetProgressBarState(PBS_FileError);
  end;

  for iSHA2 := Low(TSHA2Ver) to High(TSHA2Ver) do
  begin
    sha2 := HashSHA2[iSHA2];
    if Assigned(sha2) then Dispose(sha2);
  end;
  if Assigned(HashMD5)  then Dispose(HashMD5);
  if Assigned(HashSHA1) then Dispose(HashSHA1);

  Button2.Enabled := False;
  Button1.Caption := 'Get hash';
  Button2.Caption := 'Paused';
  JvFilenameEdit1.Enabled := True;
  CheckListBox1.Enabled := True;
  ListView1.Enabled := True;
  ListView1.Items.EndUpdate;

  BaseThread := nil;

  Button1.Enabled := True;
end;

procedure TForm1.JvThread1FinishAll(Sender: TObject);
begin
  JvThread1.Synchronize(FinishAll);
end;

procedure TForm1.JvThread2Execute(Sender: TObject; Params: Pointer);
var
  HashType: THashType;
begin
  HashType := THashType(Params);
  case HashType of
    _HT_CRC32:  crc32 := UpdateCRC32(crc32, Page.Buffer, Page.Length);
    _HT_MD5:    HashMD5.Update(Page.Buffer, Page.Length);
    _HT_SHA1:   HashSHA1.Update(Page.Buffer, Page.Length);
    _HT_SHA224: HashSHA2[TSHA2Ver.SHA224].Update(Page.Buffer, Page.Length);
    _HT_SHA256: HashSHA2[TSHA2Ver.SHA256].Update(Page.Buffer, Page.Length);
    _HT_SHA384: HashSHA2[TSHA2Ver.SHA384].Update(Page.Buffer, Page.Length);
    _HT_SHA512: HashSHA2[TSHA2Ver.SHA512].Update(Page.Buffer, Page.Length);
    _HT_SHA512_224: HashSHA2[TSHA2Ver.SHA512_224].Update(Page.Buffer, Page.Length);
    _HT_SHA512_256: HashSHA2[TSHA2Ver.SHA512_256].Update(Page.Buffer, Page.Length);
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  ShowRead;
end;

procedure TForm1.CheckListBox1ClickCheck(Sender: TObject);
var
  b: Boolean;
begin
  b := ListChecked;
  if Button1.Enabled <> b then
    Button1.Enabled := b;
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
var
  CheckBox: TCheckBox ABSOLUTE Sender;
  b: Boolean;
  I: Integer;
  Items: TListItems;
  Strings: TStrings;
begin
  b := CheckBox.Checked;
  Items := ListView1.Items;
  Items.BeginUpdate;
  try
    I := 0;
    while I < Items.Count do
    begin
      Strings := Items.Item[I].SubItems;
      if Strings.Count > 0 then
        if b then
          Strings.Strings[0] := UpperCase(Strings.Strings[0])
        else
          Strings.Strings[0] := LowerCase(Strings.Strings[0]);
      Inc(I);
    end;
  finally
    Items.EndUpdate;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if Assigned(BaseThread) then
  begin
    if not BaseThread.Terminated then
    begin
      Button1.Enabled := False;
      Button2.Enabled := False;
      SetProgressBarState(PBS_Stop);
      JvThread1.Terminate;
      JvThread1.WaitFor;
    end;
  end
  else
  begin
    if JvThread1.Terminated then
    begin
      BaseThread := JvThread1.Execute(nil);
      JvThread1.Resume;
    end;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  ProgressActive(not Paused);
  if Paused then
  begin
    JvThread1.Suspend;
    PauseStartTime := timeGetTime;
    ShowRead();
  end
  else
  begin
    TotalPauseTime := TotalPauseTime + timeGetTime - PauseStartTime;
    JvThread1.Resume;
    ShowRead();
  end;
end;

procedure TForm1.ListView1ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  Item: TListItem;
begin
  Item := ListView1.Selected;
  if not Assigned(Item) then
    if ListView1.Items.Count <> 0 then
      MousePos.SetLocation(ListView1.Left, ListView1.Top)
    else
      Handled := True;
  if not Handled then
    CopyValue1.Enabled := Item <> nil;
end;

procedure TForm1.SelectAll1Click(Sender: TObject);
begin
  ListView1.SelectAll;
end;

procedure TForm1.ReverseSelect1Click(Sender: TObject);
var
  Items: TListItems;
  I: Integer;
begin
  Items := ListView1.Items;
  Items.BeginUpdate;
  try
    I := 0;
    while I < Items.Count do
    begin
      Items.Item[I].Selected := not Items.Item[I].Selected;
      Inc(I);
    end;
  finally
    Items.EndUpdate;
  end;
end;

procedure TForm1.CopyValue1Click(Sender: TObject);
begin
  CopyToClipboard(ListView1.SelCount > 1);
end;

procedure TForm1.Compare1Click(Sender: TObject);
begin
  //
end;

procedure TForm1.Reset;
begin
  Label1.Caption := '';
  Label2.Caption := '';
  SetProgressBarState(PBS_Clear);
  ListView1.Clear;
end;

procedure TForm1.CopyToClipboard(Full: Boolean);
var
  cb: TClipboard;
  Strings: TStringList;
  Item: TListItem;
begin
  cb := Clipboard;
  if Assigned(cb) then
  begin
    Strings := TStringList.Create;
    try
      Item := ListView1.Selected;
      while Assigned(Item) do
      begin
        if Full then
          Strings.Add(Item.Caption + ': ' + Item.SubItems.Strings[0])
        else
          Strings.Add(Item.SubItems.Strings[0]);
        Item := ListView1.GetNextItem(Item, sdAll, [isSelected]);
      end;
      if Strings.Count <> 0 then
        cb.AsText := Strings.Text;
    finally
      Strings.Free;
    end;
  end;
end;

procedure TForm1.StartHashThread;
var
  sha2: PHashSHA2;
  iSHA2: TSHA2Ver;
begin
  ThreadProcessing := True;

  if HashCrc32 then
    JvThread2.Execute(Pointer(_HT_CRC32));

  if Assigned(HashMD5) then
    JvThread2.Execute(Pointer(_HT_MD5));

  if Assigned(HashSHA1) then
    JvThread2.Execute(Pointer(_HT_SHA1));

  for iSHA2 := Low(TSHA2Ver) to High(TSHA2Ver) do
  begin
    sha2 := HashSHA2[iSHA2];
    if Assigned(sha2) then
      JvThread2.Execute(Pointer(NativeInt(_HT_SHA224) + NativeInt(iSHA2)));
  end;

  JvThread2.Resume;
end;

procedure TForm1.WaitHashThread;
begin
  repeat
    Sleep(1);
  until JvThread2.Terminated;
end;

procedure TForm1.ProgressUpdate;
begin
  JvgProgress1.Percent := Percent;
  if Completed then
    SetProgressBarState(PBS_Complete);
end;

procedure TForm1.SetProgressBarState(State: TProgressBarState);
begin
  case State of
    PBS_Clear:
    begin
      JvgProgress1.Percent := 0;
      JvgProgress1.Caption := '';
    end;
    PBS_Process:
    begin
      JvgProgress1.Gradient.FromColor := clGreen;
      JvgProgress1.Gradient.ToColor := clGreen;
      JvgProgress1.Caption := 'Progress...[%d%%]';
    end;
    PBS_Pause:
    begin
      JvgProgress1.Gradient.FromColor := clYellow;
      JvgProgress1.Gradient.ToColor := clYellow;
      JvgProgress1.Caption := 'Paused [%d%%]';
    end;
    PBS_Stop:
    begin
      JvgProgress1.Gradient.FromColor := clRed;
      JvgProgress1.Gradient.ToColor := clRed;
      JvgProgress1.Caption := 'Stop [%d%%]';
    end;
    PBS_Complete:
    begin
      JvgProgress1.Gradient.FromColor := clLime;
      JvgProgress1.Gradient.ToColor := clLime;
      JvgProgress1.Caption := 'Completed.';
    end;
    PBS_FileError:
    begin
//      JvgProgress1.Percent = 0;
//      JvgProgress1.Caption = 'Can''t open file.';
    end;
  end;
end;

procedure TForm1.ProgressActive(Active: Boolean);
begin
  Paused := Active;
  if Active then
  begin
    SetProgressBarState(PBS_Pause);
    Button2.Caption := 'Continue';
  end
  else
  begin
    Button2.Caption := 'Pause';
    SetProgressBarState(PBS_Process);
  end;
end;

procedure TForm1.AddListViewItem;
var
  Item: TListItem;
begin
  Item := ListView1.Items.Add;
  Item.Caption := HashParam.Name;
  if CheckBox1.Checked then
    Item.SubItems.Add(UpperCase(HashParam.Value))
  else
    Item.SubItems.Add(LowerCase(HashParam.Value));
end;

procedure TForm1.ShowRead;
var
  ms, pt, Reads: DWORD;
  sec: Single;
  str: string;
begin
  ms := timeGetTime();
  if Paused then
    pt := ms - PauseStartTime + TotalPauseTime
  else
    pt := TotalPauseTime;
  sec := ms - ExecuteStartTime - pt;
  sec := sec / 1000;
  if sec < 1 then
    Reads := FileStream.Position
  else
    Reads := FileStream.Position div Ceil(sec);
  if PauseStartTime <> 0 then
    str := 'Read: %s/sec in %ssec (roughly)'
  else
    str := 'Read: %s/sec in %ssec';
  Label2.Caption := Format(str, [FormatBytes(Reads), FormatFloat('#,##0.000', sec)]);
end;

function TForm1.ListChecked: Boolean;
var
  I: Integer;
begin
  I := 0;
  while I < CheckListBox1.Count do
  begin
    if CheckListBox1.Checked[I] then
      Exit(True);
    Inc(I);
  end;
  Exit(False);
end;

end.
