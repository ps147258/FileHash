#ifndef CalcCRC32HPP
#define CalcCRC32HPP

#include <System.Classes.hpp>

typedef System::DWord TCRCTable[256];

extern const unsigned long _Crc32Initial;
extern const TCRCTable CRC32Table;

System::DWord UpdateCRC32(System::DWord InitCRC, System::Byte* BufPtr, System::NativeInt Len);
DWord StreamCRC32(TStream* const Stream);
DWord FileCRC32(UnicodeString* const FileName, int CacheSize);

#endif	// CalcCRC32HPP
