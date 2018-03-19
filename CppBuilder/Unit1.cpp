//---------------------------------------------------------------------------

#include <vcl.h>
#pragma hdrstop

#include "Unit1.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma link "JvComponentBase"
#pragma link "JvExMask"
#pragma link "JvExControls"
#pragma link "JvToolEdit"
#pragma link "JvgProgress"
#pragma link "JvThread"
#pragma resource "*.dfm"
TForm1 *Form1;
//---------------------------------------------------------------------------
System::UnicodeString __fastcall FormatBytes(__int64 Bytes, bool Float = true)
{
	const System::UnicodeString btc[] = {"Bytes","KB","MB","GB","TB"};
	int i = 0;
	if (Float) {
		long double Value = (long double)Bytes;
		while (Value >= 1024)
		{
			Value /= 1024;
			i++;
		}
		return FormatFloat("#,##0.00", Value) + ' ' + btc[i];
	} else {
		__int64 Value = Bytes;
		while (Value >= 1024)
		{
			Value /= 1024;
			i++;
		}
		return FormatFloat("#,##0", Value) + ' ' + btc[i];
	}
}
//---------------------------------------------------------------------------
__fastcall TForm1::TForm1(TComponent* Owner)
	: TForm(Owner)
{
	CheckListBox1->CheckAll(cbChecked, false, true);
	CheckListBox1ClickCheck(CheckListBox1);
	Reset();
//	JvFilenameEdit1->FileName = Application->ExeName;
	BaseThread = NULL;
}
//---------------------------------------------------------------------------
void __fastcall TForm1::FormDestroy(TObject *Sender)
{
	JvThread1->TerminateWaitFor();
}
//---------------------------------------------------------------------------
void __fastcall TForm1::JvFilenameEdit1Change(TObject *Sender)
{
	Reset();
}
//---------------------------------------------------------------------------
void __fastcall TForm1::JvThread1Begin(TObject *Sender)
{
	JvFilenameEdit1->Enabled = false;
	CheckListBox1->Enabled = false;
	ListView1->Enabled = false;
	ListView1->Items->BeginUpdate();
	ListView1->Clear();
	Button1->Caption = "Stop";
	FileName = JvFilenameEdit1->FileName;

//	HashCRC32 = 0;
	crc32     = 0;
	HashCrc32 = false;
	HashMD5   = NULL;
	HashSHA1  = NULL;
	memset(HashSHA2, 0, sizeof(HashSHA2));

	try {
		FileStream = new TFileStream(FileName, fmOpenRead | fmShareDenyWrite);
	} catch (const Exception& e) {
		FileStream = NULL;
//		JvgProgress1->Caption = SysErrorMessage(GetLastError());
		JvgProgress1->Caption = e.Message;
		SetProgressBarState(PBS_FileError);
	}
	if (FileStream) {
		__int64 FileSize = FileStream->Size;
		double c = FileSize;
		if (FileSize < 1024)
			Label1->Caption = Format("File size: %s bytes", ARRAYOFCONST((FormatCurr("#,##0", c))));
		else
			Label1->Caption = Format("File size: %s (%s bytes)", ARRAYOFCONST((FormatBytes(FileSize), FormatCurr("#,##0", c))));
		Label2->Caption = "";
		TotalPauseTime = 0;
		PauseStartTime = 0;
		ExecuteStartTime = timeGetTime();
		Timer1->Enabled = true;
	} else {
		return;
	}

	Completed = false;
	Percent = 0;
	JvgProgress1->Percent = 0;
	ProgressActive(false);
	Button2->Enabled = true;

	if (CheckListBox1->Checked[0])
	{
//			HashCRC32 = new TIdHashCRC32();
		crc32 = _Crc32Initial;
		HashCrc32 = true;
	}
	if (CheckListBox1->Checked[1])
	{
		HashMD5 = new THashMD5();
		HashMD5->Reset();
	}
	if (CheckListBox1->Checked[2])
	{
		HashSHA1 = new THashSHA1();
		HashSHA1->Reset();
	}

	for (int i = 0; i < HashSHA2_Count; i++) {
		if (CheckListBox1->Checked[i + 3])
		{
			THashSHA2 *sha2 = new THashSHA2();
			HashSHA2[i] = sha2;
			sha2->FVersion = (THashSHA2::TSHA2Version)i;
			sha2->Reset();
		}
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::JvThread1Execute(TObject *Sender, Pointer Params)
{
	if (FileStream) {
		if (HashCrc32 || HashMD5 || HashSHA1)
			goto Continue;
		else
			for (int i = 0; i < HashSHA2_Count; i++)
				if (HashSHA2[i])
					goto Continue;
	}
	return;
	Continue:

	int PageIndex = 0;
	TBufferPage *NextPage = &Pages[PageIndex];
	NextPage->Length = FileStream->Read(NextPage->Buffer, BufferSize);
	__int64 FileSize = FileStream->Size;
	__int64 FilePosition = FileStream->Position;
	int Position;
	TThread::Synchronize(BaseThread, ProgressUpdate);
	DWORD Timeout = timeGetTime() + 50;
	do {
		if (BaseThread->Terminated) {
			WaitHashThread();
			return;
		}

		Page = NextPage;

		StartHashThread();

		if (FilePosition >= FileSize) {
			WaitHashThread();
			break;
		}

		PageIndex++;
		if (PageIndex >= BufferPages)
			PageIndex = 0;
		NextPage = &Pages[PageIndex];
		NextPage->Length = FileStream->Read(NextPage->Buffer, BufferSize);
		FilePosition = FileStream->Position;
		Position = (int)((float)FilePosition / FileSize * 100);

		WaitHashThread();

		if (Position != Percent) {
			Percent = Position;
			DWORD ms = timeGetTime();
			if (ms > Timeout)
			{
				Timeout = ms + 25;
				TThread::Synchronize(BaseThread, ProgressUpdate);
			}
		}
	} while (true);

	System::Classes::TStrings *Strings = CheckListBox1->Items;
	if (HashCrc32)
	{
//			crc32 = ~crc32;
		SetSyncBuffer(Strings->Strings[0], IntToHex((int)~crc32, sizeof(crc32) * 2));
		TThread::Synchronize(BaseThread, AddListViewItem);
	}
	if (HashMD5)
	{
		SetSyncBuffer(Strings->Strings[1], HashMD5->HashAsString());
		TThread::Synchronize(BaseThread, AddListViewItem);
	}
	if (HashSHA1)
	{
		SetSyncBuffer(Strings->Strings[2], HashSHA1->HashAsString());
		TThread::Synchronize(BaseThread, AddListViewItem);
	}
	for (int i = 0; i < HashSHA2_Count; i++) {
		THashSHA2 *sha2 = HashSHA2[i];
		if (sha2)
		{
			SetSyncBuffer(Strings->Strings[i + 3], sha2->HashAsString());
			TThread::Synchronize(BaseThread, AddListViewItem);
		}
	}
	Percent = 100;
	Completed = true;
	TThread::Synchronize(BaseThread, ProgressUpdate);
}
//---------------------------------------------------------------------------
void __fastcall TForm1::FinishAll(void)
{
	if (FileStream)
	{
		Timer1->Enabled = false;
		ShowRead();
		delete FileStream;
	} else {
//		SetProgressBarState(PBS_FileError);
	}

	for (int i = 0; i < HashSHA2_Count; i++) {
		THashSHA2 *sha2 = HashSHA2[i];
		if (sha2) delete sha2;
	}
	if (HashMD5)  delete HashMD5;
	if (HashSHA1) delete HashSHA1;

	Button2->Enabled = false;
	Button1->Caption = "Get hash";
	Button2->Caption = "Paused";
	JvFilenameEdit1->Enabled = true;
	CheckListBox1->Enabled = true;
	ListView1->Enabled = true;
	ListView1->Items->EndUpdate();

	BaseThread = NULL;
	
	Button1->Enabled = true;
}
//---------------------------------------------------------------------------
void __fastcall TForm1::JvThread1FinishAll(TObject *Sender)
{
	JvThread1->Synchronize(FinishAll);
}
//--------------------------------------------------------------------------
void __fastcall TForm1::JvThread2Execute(TObject *Sender, Pointer Params)
{
	switch ((int)Params) {
	case _HT_CRC32:  crc32 = UpdateCRC32(crc32, Page->Buffer, Page->Length); break;
	case _HT_MD5:    HashMD5->Update((void*)Page->Buffer, Page->Length);     break;
	case _HT_SHA1:   HashSHA1->Update((void*)Page->Buffer, Page->Length);    break;
	case _HT_SHA224: HashSHA2[0]->Update((void*)Page->Buffer, Page->Length); break;
	case _HT_SHA256: HashSHA2[1]->Update((void*)Page->Buffer, Page->Length); break;
	case _HT_SHA384: HashSHA2[2]->Update((void*)Page->Buffer, Page->Length); break;
	case _HT_SHA512: HashSHA2[3]->Update((void*)Page->Buffer, Page->Length); break;
	case _HT_SHA512_224: HashSHA2[4]->Update((void*)Page->Buffer, Page->Length); break;
	case _HT_SHA512_256: HashSHA2[5]->Update((void*)Page->Buffer, Page->Length); break;
	default: ;
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::Timer1Timer(TObject *Sender)
{
	ShowRead();
}
//---------------------------------------------------------------------------
void __fastcall TForm1::CheckListBox1ClickCheck(TObject *Sender)
{
	bool b = ListChecked();
	if (Button1->Enabled != b)
		Button1->Enabled = b;
}
//---------------------------------------------------------------------------
void __fastcall TForm1::CheckBox1Click(TObject *Sender)
{
	TCheckBox *CheckBox = dynamic_cast<TCheckBox*>(Sender);

	bool b = CheckBox->Checked;
	TListItems *Items = ListView1->Items;
	Items->BeginUpdate();
	try {
		for (int i = 0; i < Items->Count; i++) {
			System::Classes::TStrings *Strings = Items->Item[i]->SubItems;
			if (Strings->Count) {
				if (b)
					Strings->Strings[0] = UpperCase(Strings->Strings[0]);
				else
					Strings->Strings[0] = LowerCase(Strings->Strings[0]);
			}
		}
	} __finally {
		Items->EndUpdate();
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::Button1Click(TObject *Sender)
{
	if (BaseThread) {
		if (!(BaseThread->Terminated)) {
			Button1->Enabled = False;
			Button2->Enabled = False;
			SetProgressBarState(PBS_Stop);
			JvThread1->Terminate();
			JvThread1->WaitFor();
		}
	} else {
		if (JvThread1->Terminated) {
			BaseThread = JvThread1->Execute(NULL);
			JvThread1->Resume();
		}
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::Button2Click(TObject *Sender)
{
	ProgressActive(!Paused);
	if (Paused) {
		JvThread1->Suspend();
		PauseStartTime = timeGetTime();
		ShowRead();
	} else {
		TotalPauseTime += timeGetTime() - PauseStartTime;
		JvThread1->Resume();
		ShowRead();
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::ListView1ContextPopup(TObject *Sender, TPoint &MousePos, bool &Handled)
{
	TListItem *Item = ListView1->Selected;
	if (!Item) {
		if (ListView1->Items->Count)
			MousePos.SetLocation(ListView1->Left, ListView1->Top);
		else
			Handled = true;
	}
	if (!Handled) {
		CopyValue1->Enabled = Item != NULL;
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::SelectAll1Click(TObject *Sender)
{
	ListView1->SelectAll();
}
//---------------------------------------------------------------------------
void __fastcall TForm1::ReverseSelect1Click(TObject *Sender)
{
	TListItems *Items = ListView1->Items;
	Items->BeginUpdate();
	try {
		for (int i = 0; i < Items->Count; i++) {
			Items->Item[i]->Selected = !(Items->Item[i]->Selected);
		}
	} __finally {
		Items->EndUpdate();
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::CopyValue1Click(TObject *Sender)
{
	CopyToClipboard(ListView1->SelCount > 1);
}
//---------------------------------------------------------------------------
void __fastcall TForm1::Compare1Click(TObject *Sender)
{
	//
}
//---------------------------------------------------------------------------
void __fastcall TForm1::SetSyncBuffer(System::UnicodeString Name, System::UnicodeString Value) _ALWAYS_INLINE
{
	HashParam.Name = Name;
	HashParam.Value = Value;
}
//---------------------------------------------------------------------------
void __fastcall TForm1::Reset(void)
{
	Label1->Caption = "";
	Label2->Caption = "";
	SetProgressBarState(PBS_Clear);
	ListView1->Clear();
}
//---------------------------------------------------------------------------
void __fastcall TForm1::CopyToClipboard(bool Full)
{
	TClipboard *cb = Clipboard();
	if (cb) {
		System::Classes::TStringList *Strings = new System::Classes::TStringList();
		try
		{
			TItemStates selected = TItemStates() << isSelected;
			TListItem *Item = ListView1->Selected;
			while (Item){
				if (Full)
					Strings->Add(Item->Caption + ": " + Item->SubItems->Strings[0]);
				else
					Strings->Add(Item->SubItems->Strings[0]);
				Item = ListView1->GetNextItem(Item, sdAll, selected);
			}
			if (Strings->Count) {
				cb->AsText = Strings->Text;
			}
		}
		 __finally
		{
			if (Strings)
				delete Strings;
		}
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::StartHashThread(void)
{
	ThreadProcessing = true;
	
	if (HashCrc32) JvThread2->Execute((void*)_HT_CRC32);
	if (HashMD5)   JvThread2->Execute((void*)_HT_MD5);
	if (HashSHA1)  JvThread2->Execute((void*)_HT_SHA1);
	for (int i = 0; i < HashSHA2_Count; i++) {
		THashSHA2 *sha2 = HashSHA2[i];
		if (sha2)
			JvThread2->Execute((void*)((NativeInt)_HT_SHA224 + i));
	}
	
	JvThread2->Resume();
}
//---------------------------------------------------------------------------
void __fastcall TForm1::WaitHashThread(void)
{
	do {
		Sleep(1);
	} while (!JvThread2->Terminated);
}
//---------------------------------------------------------------------------
void __fastcall TForm1::ProgressUpdate(void)
{
	JvgProgress1->Percent = Percent;
	if (Completed)
		SetProgressBarState(PBS_Complete);
}
//---------------------------------------------------------------------------
void __fastcall TForm1::SetProgressBarState(TProgressBarState State)
{
	switch (State) {
		case PBS_Clear:
			JvgProgress1->Percent = 0;
			JvgProgress1->Caption = "";
			break;
		case PBS_Process:
			JvgProgress1->Gradient->FromColor = clGreen;
			JvgProgress1->Gradient->ToColor = clGreen;
			JvgProgress1->Caption = "Progress...[%d%%]";
			break;
		case PBS_Pause:
			JvgProgress1->Gradient->FromColor = clYellow;
			JvgProgress1->Gradient->ToColor = clYellow;
			JvgProgress1->Caption = "Paused [%d%%]";
			break;
		case PBS_Stop:
			JvgProgress1->Gradient->FromColor = clRed;
			JvgProgress1->Gradient->ToColor = clRed;
			JvgProgress1->Caption = "Stop [%d%%]";
			break;
		case PBS_Complete:
			JvgProgress1->Gradient->FromColor = clLime;
			JvgProgress1->Gradient->ToColor = clLime;
			JvgProgress1->Caption = "Completed.";
			break;
		case PBS_FileError:
//			JvgProgress1->Percent = 0;
//			JvgProgress1->Caption = "Can\'t open file.";
			break;
	default:
		;
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::ProgressActive(bool Active)
{
	Paused = Active;
	if (Active) {
		SetProgressBarState(PBS_Pause);
		Button2->Caption = "Continue";
	} else {
		Button2->Caption = "Pause";
		SetProgressBarState(PBS_Process);
	}
}
//---------------------------------------------------------------------------
void __fastcall TForm1::AddListViewItem(void)
{
	TListItem *Item = ListView1->Items->Add();
	Item->Caption = HashParam.Name;
	if (CheckBox1->Checked)
		Item->SubItems->Add(UpperCase(HashParam.Value));
	else
		Item->SubItems->Add(LowerCase(HashParam.Value));
}
//---------------------------------------------------------------------------
void __fastcall TForm1::ShowRead(void)
{
	DWORD ms    = timeGetTime();
	DWORD pt    = Paused?(ms - PauseStartTime + TotalPauseTime):TotalPauseTime;
	float sec   = (float)(ms - ExecuteStartTime - pt) / 1000;
	DWORD Reads = FileStream->Position / ((sec<1)?1:Ceil(sec));
	System::UnicodeString str;
	if (PauseStartTime)
		str = "Read: %s/sec in %ssec (roughly)";
	else
		str = "Read: %s/sec in %ssec";
	Label2->Caption = Format(str, ARRAYOFCONST((FormatBytes(Reads), FormatFloat("#,##0.000", sec))));
}
//---------------------------------------------------------------------------
bool __fastcall TForm1::ListChecked(void)
{
	for (int i = 0; i < CheckListBox1->Count; i++)
		if (CheckListBox1->Checked[i])
			return true;
	return false;
}
//---------------------------------------------------------------------------

