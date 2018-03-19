//---------------------------------------------------------------------------

#ifndef Unit1H
#define Unit1H
//---------------------------------------------------------------------------
#include <System.Classes.hpp>
#include <Vcl.Controls.hpp>
#include <Vcl.StdCtrls.hpp>
#include <Vcl.Forms.hpp>
#include <Vcl.CheckLst.hpp>
#include <Vcl.Mask.hpp>
#include <Vcl.ComCtrls.hpp>
#include <Vcl.ExtCtrls.hpp>
#include <Vcl.Menus.hpp>
#include "JvComponentBase.hpp"
#include "JvExMask.hpp"
#include "JvExControls.hpp"
#include "JvToolEdit.hpp"
#include "JvgProgress.hpp"
#include "JvThread.hpp"
//---------------------------------------------------------------------------
//#include <IdHashCRC.hpp>
//#include <IdHashMessageDigest.hpp>
#include <Clipbrd.hpp>
#include <System.Math.hpp>
#include <System.Hash.hpp>
#include "CalcCRC32.hpp"
//---------------------------------------------------------------------------
class TForm1 : public TForm
{
__published:	// IDE-managed Components
	TJvFilenameEdit *JvFilenameEdit1;
	TCheckListBox *CheckListBox1;
	TButton *Button1;
	TJvgProgress *JvgProgress1;
	TListView *ListView1;
	TJvThread *JvThread1;
	TButton *Button2;
	TJvThread *JvThread2;
	TCheckBox *CheckBox1;
	TLabel *Label1;
	TLabel *Label2;
	TTimer *Timer1;
	TPopupMenu *PopupMenu1;
	TMenuItem *SelectAll1;
	TMenuItem *ReverseSelect1;
	TMenuItem *N1;
	TMenuItem *CopyValue1;
	TMenuItem *N2;
	TMenuItem *Compare1;
	void __fastcall FormDestroy(TObject *Sender);
	void __fastcall JvFilenameEdit1Change(TObject *Sender);
	void __fastcall JvThread1Begin(TObject *Sender);
	void __fastcall JvThread1Execute(TObject *Sender, Pointer Params);
	void __fastcall JvThread1FinishAll(TObject *Sender);
	void __fastcall JvThread2Execute(TObject *Sender, Pointer Params);
	void __fastcall Timer1Timer(TObject *Sender);
	void __fastcall CheckListBox1ClickCheck(TObject *Sender);
	void __fastcall CheckBox1Click(TObject *Sender);
	void __fastcall Button1Click(TObject *Sender);
	void __fastcall Button2Click(TObject *Sender);
	void __fastcall ListView1ContextPopup(TObject *Sender, TPoint &MousePos, bool &Handled);
	void __fastcall SelectAll1Click(TObject *Sender);
	void __fastcall ReverseSelect1Click(TObject *Sender);
	void __fastcall CopyValue1Click(TObject *Sender);
	void __fastcall Compare1Click(TObject *Sender);

private:	// User declarations
	enum THashType {
		_HT_CRC32, _HT_MD5, _HT_SHA1,
		_HT_SHA224, _HT_SHA256, _HT_SHA384,
		_HT_SHA512, _HT_SHA512_224, _HT_SHA512_256, _HT_Max
	};
	enum TProgressBarState {
		PBS_Clear, PBS_Process, PBS_Pause, PBS_Stop, PBS_Complete, PBS_FileError
	};

	static const int HashSHA2_Count = _HT_Max - _HT_SHA224; // THashSHA2::TSHA2Version
	static const int BufferSize     = 1024 * 1024; // 16 * 1024
	static const int BufferPages    = 2;

	typedef struct THashParam {
		System::UnicodeString Name;
		System::UnicodeString Value;
	} *PHashParam;
	typedef Byte TBuffer[BufferSize];
	typedef struct TBufferPage {
		unsigned int  Length;
		TBuffer Buffer;
	} *PBufferPage;

	System::UnicodeString FileName;
	TJvBaseThread         *BaseThread;
	THashParam            HashParam;

	int           Percent;
	bool          ThreadProcessing;
	bool          Paused;
	bool          Completed;
	TBufferPage   Pages[BufferPages];
	TBufferPage   *Page;
	TFileStream   *FileStream;
//	TIdHashCRC32  *HashCRC32;
	unsigned long crc32;
	bool          HashCrc32;
	THashMD5			*HashMD5;
	THashSHA1     *HashSHA1;
	THashSHA2     *HashSHA2[HashSHA2_Count];
	DWORD         TotalPauseTime;
	DWORD         PauseStartTime;
	DWORD         ExecuteStartTime;

	void __fastcall SetSyncBuffer(System::UnicodeString Name, System::UnicodeString Value) _ALWAYS_INLINE;
	void __fastcall FinishAll(void);
	void __fastcall Reset(void);
	void __fastcall CopyToClipboard(bool Full);
	void __fastcall StartHashThread(void) _ALWAYS_INLINE;
	void __fastcall WaitHashThread(void) _ALWAYS_INLINE;
	void __fastcall ProgressUpdate(void);
	void __fastcall SetProgressBarState(TProgressBarState State);
	void __fastcall ProgressActive(bool Active);
	void __fastcall AddListViewItem(void);
	void __fastcall ShowRead(void);
	bool __fastcall ListChecked(void);
public:		// User declarations
	__fastcall TForm1(TComponent* Owner);
};
//---------------------------------------------------------------------------
extern PACKAGE TForm1 *Form1;
//---------------------------------------------------------------------------
#endif
