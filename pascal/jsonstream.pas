// JsonStream Pascal Implementation v1.0
//
// Copyright 2021 Philip Zander
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Changelog:
//   2022-02-08: Release version 1.0.2
//               - Fixes a rarely triggered off-by-one error
//   2021-12-23: Release version 1.0.1
//               - Fixes assertion failure on skipping boolean value
//   2021-10-18: Release version 1.0.0

unit jsonstream;

{$ifdef FPC}
{$mode Delphi}
{$endif}

interface

uses
  SysUtils, Classes;

type
  TJsonString = string;
  TJsonChar = char;
  PJsonChar = ^TJsonChar;

  TJsonFeature = (jfJson5);
  TJsonFeatures = set of TJsonFeature;

  TJsonState = (
    jsError,
    jsEOF,
    jsDict,
    jsDictEnd,
    jsList,
    jsListEnd,
    jsNumber,
    jsBoolean,
    jsNull,
    jsString,
    jsKey
  );

  TJsonError = (
    jeNoError = 0,
    jeInvalidToken,
    jeInvalidNumber,
    jeUnexpectedToken,
    jeTrailingComma,
    jeUnexpectedEOF,
    jeInvalidEscapeSequence,
    jeNestingTooDeep
  );

  // Internal types

  TJsonToken = (
    jtUnknown, jtEOF, jtDict, jtDictEnd, jtList, jtListEnd, jtComma, jtColon,
    jtNumber, jtDoubleQuote, jtSingleQuote, jtFalse, jtTrue, jtNull,
    jtSingleLineComment, jtMultiLineComment
  );

  TJsonInternalState = (
    jisInitial,
    jisError,
    jisEOF,
    jisListHead,
    jisAfterListItem,
    jisListItem,
    jisDictHead,
    jisDictItem,
    jisAfterDictItem,
    jisDictKey,
    jisAfterDictKey,
    jisDictValue,
    jisNumber,
    jisBoolean,
    jisNull,
    jisString
  );

  TJsonStringMode = (
    jsmDoubleQuoted,
    jsmSingleQuoted,
    jsmUnquoted
  );

  { TJsonReader }

  TJsonReader = class
  protected
    // === Parsing options ===
    FFeatures:         TJsonFeatures;

    // === Input ===
    FStream:           TStream;
    FBuf:              array[0..1023] of TJsonChar;
    // Length of FBuf
    FLen:              Integer;
    // Position within FBuf
    FPos:              Integer;
    // Offset of FBuf within the stream (only used for error information)
    FOffset:           SizeInt;

    // === Tokenizer ===
    // Current token type (at FBuf[FPos])
    FToken:            TJsonToken;

    // == Stack machine ===
    FStack:            array of TJsonInternalState;
    FState:            TJsonState;

    // === Number parsing ===
    // FNumber contains the normalized decimal form of the number.
    // I.e. Skips any leading zeroes and contains no decimal point, and may be
    // followed by an exponent.
    //
    // Satisfies this regex: [-]?(0|[1-9][0-9])*(e[-]?[0-9]+)?
    //
    // Note that we have to store the digits in a string because
    // decimal-to-binary floating-point conversions turn out to be *very*
    // intricate. Up to 768 decimal digits may be required to accurately
    // determine what the closest double precision value is, and JSON places no
    // limit on the number of digits. We don't deal with this ourselves, we just
    // pass it to the runtime and assume it handles it correctly.
    //
    // https://www.exploringbinary.com/17-digits-gets-you-there-once-youve-found-your-way/
    FNumber:           TJsonString;
    // True = number could be parsed but is technically not a valid JSON number
    FNumberErr:        Boolean;

    // === String parsing ===
    // Delimiter of the current string (double-quote, single-quote, or word
    // boundary)
    FStringMode:       TJsonStringMode;
    // If an error occurred during Str() or Key(), the part that has been read
    // is temporarily stored here between successive calls.
    FSavedStr:         TJsonString;
    // True if we reached the end of the string
    FStringEnd:        Boolean;
    // If Proceed was called after a string error: Tell string routines to
    // ignore the error.
    FStrIgnoreError:   Boolean;
    // Temporary storage for decoded escape sequences.
    FEscapeSequence:   TJsonString;

    // Nesting depth of structures (lists + dicts), e.g. "[[" would be depth 2.
    // This is different from Length(FStack) because FStack contains internal
    // nodes such as jisDictValue etc.. This is checked against MaxNestingDepth
    // and an error is generated if the maximum nesting depth is exceeded. The
    // purpose of this is to guarantee an upper bound on memory consumption that
    // doesn't grow linearly with the input in the worst case.
    FNestingDepth:     Integer;
    FMaxNestingDepth:  Integer;

    // === Error recovery ===
    // Stack depth up until which we must pop after an error.
    FPopUntil:         Integer;
    // Stack depth up until which a skip was issued.
    FSkipUntil:        Integer;
    // Whether current item should be skipped upon next call to Advance.
    FSkip:             Boolean;

    // === Error information ===
    FLastError:        TJsonError;
    FLastErrorMessage: TJsonString;
    FLastErrorPosition:SizeInt;

    // Tokenizer
    procedure GetToken;

    // Stack machine
    function  StackTop: TJsonInternalState;
    procedure StackPush(State: TJsonInternalState);
    function  StackPop: TJsonInternalState;
    procedure Reduce;

    // Parsing helpers
    procedure RefillBuffer(LookAhead: Integer = 1);
    procedure SkipSpace;
    procedure SkipGarbage;
    procedure SkipSingleLineComment;
    procedure SkipMultiLineComment;
    function  MatchString(const Str: TJsonString): Boolean;
    procedure ParseNumber;
    procedure FinalizeNumber;

    // Skip helpers
    procedure SkipNumber;
    procedure SkipBoolean;
    procedure SkipNull;
    procedure SkipString;
    procedure SkipKey;

    // Key/Str helpers
    function  StrBufInternal(out Buf; BufSize: SizeInt): SizeInt;
    function  StrInternal(out S: TJsonString): Boolean;

    // Other internal functions
    function  InternalAdvance: TJsonState;
    function  InternalProceed: Boolean;
    procedure InvalidOrUnexpectedToken(const Msg: TJsonString);
    function  AcceptValue: boolean;
    function  AcceptKey: boolean;
    procedure SetLastError(Error: TJsonError; const Msg: string);
  public

    // Construct a TJsonReader object. The input will be read from Stream. Pass
    // [jfJson5] as Features to create a JSON5 parser instead of a regular JSON
    // parser. You can specify a maximum allowable nesting depth with
    // MaxNestingDepth. If this depth is exceeded, the parser will abort.
    constructor Create(
      Stream: TStream; Features: TJsonFeatures=[];
      MaxNestingDepth: Integer=MaxInt
    );

    // === General traversal ===

    // Move to the next element and return the new parse state.
    function  Advance: TJsonState;

    // Return the current parse state.
    function  State: TJsonState;

    // Skip current element. If the element is a list or a dict, then all its
    // children will be skipped.
    procedure Skip;

    // === Acceptor functions for specific elements ===

    // Returns true iff the current element is a dict entry and stores its key
    // in K. If true is returned, then the key is stored in K and the reader
    // is automatically advanced to the corresponding value.
    // If false is returned, the current element is either not a key or an error
    // ocurred during decoding (such as an invalid escape sequence or premature
    // end of file) and the contents of K are undefined.
    // If an error occured, you may call Proceed() to ignore it and call Key()
    // again. This function only returns true once per element.
    function  Key(out K: TJsonString): Boolean;

    // This function is like Key, except that it does not return the full key,
    // but only reads part of it. This is intended for situations where the key
    // could be very large and it would not be efficient to allocate it in
    // memory its entirety. The semantics are the same as the read() syscall
    // on Unix: Up to BufSize bytes are read and stored in Buf.
    // Return value:
    //   > 0: The number of bytes actually read.
    //   = 0: Indicates the end of the key.
    //   < 0: An error occurred (invalid escape sequence or missing trailing ")
    //        or the value is not a key.
    // If an error occurred, you can call Proceed() to ignore it and try to
    // continue reading.
    function  KeyBuf(out Buf; BufSize: SizeInt): SizeInt;

    // Returns true iff the current element is a valid string value.
    // If true is returned, then the decoded string value is stored in S.
    // If false is returned, the current element is either not a string or an
    // error occurred during decoding (such as an invalid escape sequence or
    // premature end of file) and the contents of S are undefined.
    // If an error occurred, you may call Proceed() to ignore it and call Str()
    // again. This function only returns true once per element.
    function  Str(out S: TJsonString): Boolean;

    // This function is like Str, except that it does not return the full string,
    // but only reads part of it. This is intended for situations where the
    // string could be very large ind it would not be efficient to allocate it
    // in memory in its entirety. The semantics are the same as the read()
    // syscall on Unix: Up to BufSize bytes are read and stored in Buf.
    // Return value:
    //   > 0: The number of bytes actually read.
    //   = 0: Indicates the end of the string.
    //   < 0: An error occurred (invalid escape sequence or missing trailing ")
    //        or the value is not a string.
    // If an error occurred, you can call Proceed() to ignore it and try to
    // continue reading.
    function  StrBuf(out Buf; BufSize: SizeInt): SizeInt;

    // Returns true iff the current element is a number that can be exactly
    // represented by an integer and returns its value in Num. This function only
    // return true once per element.
    function  Number(out Num: Integer): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an integer and returns its value in Num. This function only
    // return true once per element.
    function  Number(out Num: Cardinal): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an int64 and returns its value in Num. This function only
    // returns true once per element.
    function  Number(out Num: Int64): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an uint64 and returns its value in Num. This function only
    // returns true once per element.
    function  Number(out Num: UInt64): Boolean; overload;
    // Returns true iff the current element is a number and returns its value
    // in Num. If the number exceeds the representable precision or range of a
    // double precision float, it will be rounded to the closest approximation.
    // This function only returns true once per element.
    function  Number(out Num: Double): Boolean; overload;

    // Returns true iff the current element is a boolean and returns its value
    // in bool. This function only returns true once per element.
    function  Bool(out Bool: Boolean): Boolean;

    // Returns true iff the current element is a null value. This function only
    // returns true once per element.
    function  Null: Boolean;

    // Returns true iff the current element is a dict. If true is returned,
    // then the next element will be the first child of the dict.
    function  Dict: Boolean;

    // Returns true iff the current element is a list. If true is returned,
    // then the next element will be the first child of the list.
    function  List: Boolean;

    // Returns true if the last operation resulted in an error. You can then
    // check the LastError and LastErrorMessage functions to learn more about
    // the error. You can call Proceed to try to recover from the error and
    // continue parsing. Otherwise no further tokens will be consumed and all
    // open elements  will be closed.
    function  Error: Boolean;


    // === Error handling ===

    // Proceed after a parse error. If this is not called after an error is
    // encountered, no further tokens in the file will be processed.
    function  Proceed: Boolean;

    // Return last error code. A return value of 0 means that there was no
    // error. A return value other than 0 indicates that there was an error.
    function  LastError: TJsonError;

    // Return error message for last error.
    function  LastErrorMessage: TJsonString;

    // Location of the last error
    function  LastErrorPosition: SizeInt;
  end;

  { TJsonWriter }

  EJsonWriterError = class(Exception);

  EJsonWriterUnsupportedValue = class(EJsonWriterError);
  EJsonWriterSyntaxError = class(EJsonWriterError);

  TJsonWriter = class
  protected
    FStream:        TStream;
    FNeedComma:     Boolean;
    FNeedColon:     Boolean;
    FStructEmpty:   Boolean;
    FWritingString: Boolean;
    FLevel:         Integer;
    FFeatures:      TJsonFeatures;

    FPrettyPrint:   Boolean;
    FIndentation:   string;

    FStack:         array of TJsonInternalState;

    procedure WriteSeparator(Indent: Boolean = true);
    procedure Write(const S: TJsonString);
    procedure WriteBuf(const Buf; BufSize: SizeInt);
    procedure StrBufInternal(const Buf; BufSize: SizeInt; IsKey: Boolean);

    procedure ValueBegin(const Kind: string);
    procedure ValueEnd;
    procedure KeyBegin;
    procedure KeyEnd;

    function  StackTop: TJsonInternalState;
    procedure StackPush(State: TJsonInternalState);
    function  StackPop: TJsonInternalState;
  public
    constructor Create(
      Stream: TStream; Features: TJsonFeatures=[];
      PrettyPrint: Boolean=false; const Indentation: string='  '
    );

    procedure Key(const K: TJsonString);
    // Streaming equivalent of the Key() method. See StrBuf().
    procedure KeyBuf(const Buf; BufSize: SizeInt);
    procedure Str(const S: TJsonString);
    // Streaming equivalent of the Str() method. To indicate the end of the
    // string, call once with BufSize set to 0.
    // Note: To write an empty string, you have to call the method twice:
    //   StrBuf(..., 0); // Write 0 bytes
    //   StrBuf(..., 0); // Signal end of string
    procedure StrBuf(const Buf; BufSize: SizeInt);
    procedure Number(Num: Integer); overload;
    procedure Number(Num: Cardinal); overload;
    procedure Number(Num: Int64); overload;
    procedure Number(Num: UInt64); overload;
    // Write number if hexadecimal format, if possible. This required jfJson5 to
    // be included in Features. If jfJson5 is not included in Features, a
    // decimal number will be written, instead.
    procedure NumberHex(Num: UInt64); overload;
    procedure Number(Num: Double); overload;
    procedure Bool(Bool: Boolean);
    procedure Null;
    procedure Dict;
    procedure DictEnd;
    procedure List;
    procedure ListEnd;
  end;

implementation

uses
  math
  {$ifdef FPC}
  {$ifndef MSWINDOWS}
  , cwstring
  {$endif}
  {$endif}
  ;

type
  TJsonCharArray =
    array[0..High(SizeInt) div sizeof(TJsonChar) - 1] of TJsonChar;

{ TJsonReader }

constructor TJsonReader.Create(Stream: TStream; Features: TJsonFeatures;
  MaxNestingDepth: integer);
begin
  FStream            := Stream;
  FLen               := 0;
  FPos               := 0;
  FPopUntil          := -1;
  FSkipUntil         := MaxInt;
  FSkip              := false;
  FSavedStr          := '';
  FFeatures          := Features;
  FLastError         := jeNoError;
  FLastErrorPosition := 0;
  FMaxNestingDepth   := MaxNestingDepth;

  StackPush(jisInitial);
  Advance;
end;

procedure TJsonReader.RefillBuffer(LookAhead: Integer);
var
  Delta: LongInt;
begin
  if FPos + LookAhead > FLen then
  begin
    assert(FPos <= FLen);
    if Flen > FPos then
      Move(FBuf[FPos], FBuf[0], FLen - FPos);
    Inc(FOffset, FPos);
    FLen := FLen - FPos;
    FPos := 0;

    repeat
      Delta := FStream.Read(FBuf[Flen], length(FBuf) - FLen);
      if Delta <= 0 then
        break;
      Inc(FLen, Delta);
    until FPos + LookAhead <= FLen;
  end;

  assert((FPos < FLen) or (FLen = 0));
end;

type
  TSetOfChar = set of char;

procedure SkipCharSet(Reader: TJsonReader; Chars: TSetOfChar);
begin
  repeat
    while (Reader.FPos < Reader.FLen) and (Reader.FBuf[Reader.FPos] in Chars) do
      Inc(Reader.FPos);

    if Reader.FPos < Reader.FLen then
      break;

    Reader.RefillBuffer;
  until Reader.FLen <= 0;
end;

procedure TJsonReader.SkipSpace;
begin
  SkipCharSet(self, [' ', #9, #13, #10]);
end;

procedure TJsonReader.SkipGarbage;
begin
  SkipCharSet(self, [#0..#32]);
end;

procedure TJsonReader.SkipSingleLineComment;
begin
  SkipCharSet(Self, [#0..#255] - [#10, #13]);
end;

procedure TJsonReader.SkipMultiLineComment;
begin
  while true do
  begin
    SkipCharSet(Self, [#0..#255] - ['*']);
    Inc(FPos);

    RefillBuffer;
    if FLen <= 0 then
      break;

    if FBuf[FPos] = '/' then
    begin
      Inc(FPos);
      break;
    end;
  end;
end;

procedure TJsonReader.SkipNumber;
begin
  if FState <> jsNumber then
    Exit;

  FNumber := '';
  FSkip  := false;
  StackPop;
  Reduce;
end;

procedure TJsonReader.SkipNull;
begin
  Null;
end;

procedure TJsonReader.SkipBoolean;
begin
  StackPop;
  Reduce;
  FSkip  := false;
end;

procedure TJsonReader.SkipString;
var
  Buf: array[0..1024] of TJsonChar;
  n: SizeInt;
begin
  repeat
    n := StrBufInternal(Buf, sizeof(Buf));
  until n <= 0;

  FSkip := false;
end;

procedure TJsonReader.SkipKey;
begin
  SkipString;
end;

const
  WordBoundaryChars: set of TJsonChar =
    [#0..#32, '[', ']', '{', '}', ':', ',', ';', '"', '/'];

function TJsonReader.MatchString(const Str: TJsonString): Boolean;
var
  i: Integer;
begin
  Result := false;

  // +1 because we need to check if the character after the string as a word
  // boundary
  RefillBuffer(Length(Str) + 1);

  if FLen < length(Str) then
    exit;

  for i := 0 to length(Str) - 1 do
    if FBuf[FPos + i] <> Str[i + 1] then
      exit;

  if (FLen > length(Str)) and
     not (FBuf[FPos + length(Str)] in WordBoundaryChars) then
    exit;

  Result := true;
end;

const
  sInfinity = 'Infinity';
  sNaN      = 'NaN';

procedure TJsonReader.ParseNumber;
var
  Buf: array[0..768-1 + 1 { sign }] of TJsonChar;
  i, n:          Integer;
  Exponent:      Integer;
  LeadingZeroes: Integer;
  TmpExp:        Integer;
  TmpExpSign:    Integer;

label
  Finalize;

  function SkipZero: Integer;
  var
    j: Integer;
  begin
    Result := 0;
    while (FBuf[FPos] = '0') do
    begin
      for j := FPos to FLen - 1 do
      begin
        if FBuf[FPos] <> '0' then
          break;
        Inc(Result);
        Inc(FPos);
      end;
      RefillBuffer;
    end;
  end;

  function ReadDigits(Digits: TSetOfChar=['0'..'9']): Integer;
  var
    j: Integer;
  begin
    Result := 0;
    while (FLen > 0) and (FBuf[FPos] in Digits) do
    begin
      for j := FPos to FLen - 1 do
      begin
        if not (FBuf[FPos] in Digits) then
          break;
        if n < sizeof(Buf) then
        begin
          Buf[n] := FBuf[FPos];
          Inc(n);
        end;
        Inc(FPos);
        Inc(Result);
      end;
      RefillBuffer;
    end;
  end;
begin
  n          := 0;
  Exponent   := 0;
  FNumber    := '';
  FNumberErr := false;

  RefillBuffer(2);

  // Hex number (JSON5)
  if (jfJson5 in FFeatures) and (FBuf[FPos] = '0') and (FPos + 1 < FLen) and
     (FBuf[FPos + 1] in ['x', 'X']) then
  begin
    Inc(FPos, 2);
    RefillBuffer;
    Buf[n] := '$';
    Inc(n);
    if (ReadDigits(['0'..'9', 'a'..'f', 'A'..'F']) <= 0) then
    begin
      FNumberErr := true;
      SetLastError(jeInvalidNumber, 'Invalid hexadecimal number.');
    end;
    goto Finalize;
  end;

  // NaN
  if (jfJson5 in FFeatures) and MatchString(sNaN) then
  begin
    Move(sNaN[1], Buf[n], Length(sNaN));
    Inc(FPos, Length(sNaN));
    Inc(n, Length(sNaN));
    goto Finalize;
  end;

  // Sign
  if FBuf[FPos] in ['-','+'] then
  begin
    // Leading + not allowed by JSON
    if (FBuf[FPos] = '+') and not (jfJson5 in FFeatures) then
    begin
      FNumberErr := true;
      SetLastError(jeInvalidNumber, 'Number has leading `+`.');
    end;

    if (FBuf[FPos] = '-') then
    begin
      Buf[n] := FBuf[FPos];
      Inc(n);
    end;

    Inc(FPos);
    RefillBuffer;
  end;

  // Infinity
  if (jfJson5 in FFeatures) and MatchString(sInfinity) then
  begin
    Move(sInfinity[1], Buf[n], Length(sInfinity));
    Inc(FPos, Length(sInfinity));
    Inc(n, Length(sInfinity));
    goto Finalize;
  end;

  // Decimal number

  LeadingZeroes := SkipZero;

  RefillBuffer;

  // JSON does not allow leading zeroes
  if (LeadingZeroes > 1) or
     (LeadingZeroes > 0) and (FLen >= 0) and (FBuf[FPos] in ['0'..'9']) then
  begin
    FNumberErr := true;
    SetLastError(jeInvalidNumber, 'Number has leading zeroes.');
  end;

  if (LeadingZeroes > 0) and
     not ((FLen >= 0) and (FBuf[FPos] in ['0'..'9'])) then
  begin
    if (FLen >= 0) and (FBuf[FPos] = '.') then
    begin
      // 0.something
      Inc(FPos);
      RefillBuffer;
      // JSON requires digit after decimal point
      if (FLen < 0) or not (FBuf[FPos] in ['0'..'9']) then
      begin
        FNumberErr := true;
        SetLastError(jeInvalidNumber, 'Expected digit after decimal point.');
      end;
      Exponent := -SkipZero;
      Exponent := Exponent - ReadDigits;
    end
    else
    begin
      // Just 0
      Buf[0] := '0';
      n := 1;
    end;
  end
  else
  begin
    // JSON number must have a digit before the decimal point (except in JSON5)
    if (ReadDigits <= 0) and not (jfJson5 in FFeatures) then
      FNumberErr := true;
    if FBuf[FPos] = '.' then
    begin
      Inc(FPos);
      RefillBuffer;
      // JSON (but not JSON5) requires digit after decimal point
      if ((FLen < 0) or not (FBuf[FPos] in ['0'..'9'])) and
         not (jfJson5 in FFeatures) then
      begin
        FNumberErr := true;
        SetLastError(jeInvalidNumber, 'Expected digit after decimal point.');
      end;
      Exponent := -ReadDigits;
    end;
  end;

  if FBuf[FPos] in ['e', 'E'] then
  begin
    Inc(FPos);
    RefillBuffer;
    TmpExp := 0;
    TmpExpSign := +1;
    if (FBuf[FPos] in ['-', '+']) then
    begin
      if FBuf[FPos] = '-' then
        TmpExpSign := -1;
      Inc(FPos);
      RefillBuffer;
    end;

    SkipZero;

    for i := FPos to FLen - 1 do
    begin
      if not (FBuf[FPos] in ['0'..'9']) then
        break;
      // The exponent range for double is something like -324 to +308, i.e. the
      // exponent will never have more than 3 digits. We just want to make sure
      // we don't overflow for pathological inputs. Truncating the exponent is
      // not a problem as values exceeding the possible exponent range will be
      // rounded to -INF or +INF, anyway.
      if TmpExp < 10000 then
        TmpExp := TmpExp * 10 + (ord(FBuf[FPos]) - ord('0'));

      Inc(FPos);
    end;
    Exponent := Exponent + TmpExpSign * TmpExp;
  end;

Finalize:

  FNumber := Copy(Buf, 1, n);
  if Exponent <> 0 then
    FNumber := FNumber + 'e' + IntToStr(Exponent);


  // Check if there is garbage at the end
  RefillBuffer;
  if (FLen > 0) and not (FBuf[FPos] in WordBoundaryChars) then
  begin
    StackPop; // Was never a number to begin with
    StackPush(jisNull);
    StackPush(jisError);
    FState := jsError;
    SetLastError(jeInvalidToken, 'Invalid token.');

    // Skip rest of token
    repeat
      while (FPos < FLen) and not (FBuf[FPos] in WordBoundaryChars) do
        Inc(FPos);

      RefillBuffer;
    until (FPos < FLen) or (FLen <= 0);

    exit;
  end;

  if FNumberErr then
  begin
    FState := jsError;
    StackPush(jisError);
  end
end;

procedure TJsonReader.GetToken;
begin
  SkipSpace;

  if FLen <= 0 then
  begin
    FToken := jtEOF;
    Exit;
  end;

  assert(FPos < FLen);

  FToken := jtUnknown;

  case FBuf[FPos] of
    '{':      FToken := jtDict;
    '}':      FToken := jtDictEnd;
    '[':      FToken := jtList;
    ']':      FToken := jtListEnd;
    ',':      FToken := jtComma;
    ':':      FToken := jtColon;
    '0'..'9', '-', '+':
              FToken := jtNumber;
    '.':      if (jfJson5 in FFeatures) then
                FToken := jtNumber;
    'I':      if (jfJson5 in FFeatures) and MatchString('Infinity') then
                FToken := jtNumber;
    'N':      if (jfJson5 in FFeatures) and MatchString('NaN') then
                FToken := jtNumber;
    '"':      FToken := jtDoubleQuote;
    '''':     if jfJson5 in FFeatures then
                FToken := jtSingleQuote;
    '/':      if jfJson5 in FFeatures then
              begin
                RefillBuffer(1);
                if FBuf[FPos + 1] = '/' then
                  FToken := jtSingleLineComment
                else if FBuf[FPos + 1] = '*' then
                  FToken := jtMultiLineComment;
              end;
    't':      if MatchString('true') then
                FToken := jtTrue;
    'f':      if MatchString('false') then
                FToken := jtFalse;
    'n':      if MatchString('null') then
                FToken := jtNull;
  end;
end;

function TJsonReader.StackTop: TJsonInternalState;
begin
  assert(Length(FStack) > 0);
  Result := FStack[High(FStack)];
end;

procedure TJsonReader.StackPush(State: TJsonInternalState);
begin
  SetLength(FStack, Length(FStack) + 1);
  FStack[High(FStack)] := State;
end;

function TJsonReader.StackPop: TJsonInternalState;
begin
  assert(Length(FStack) > 0);
  Result := FStack[High(FStack)];
  SetLength(FStack, Length(FStack) - 1);
end;

procedure TJsonReader.Reduce;
begin
  assert(Length(FStack) > 0);

  while true do
    case StackTop of
      jisDictKey:
      begin
        StackPop;
        StackPush(jisAfterDictKey);
      end;
      jisString:
      begin
        StackPop;
      end;
      jisDictValue:
      begin
        StackPop;
        StackPop;
        StackPush(jisAfterDictItem);
      end;
      jisListHead, jisListItem:
      begin
        StackPop;
        StackPush(jisAfterListItem);
      end
      else
        break;
    end;
end;

function TJsonReader.Advance: TJsonState;
var
  NewSkip:      Integer;
  BeenSkipping: Boolean;
begin
  if StackTop in [jisListHead, jisDictHead] then
    NewSkip := High(FStack) - 1
  else
    NewSkip := High(FStack);

  if FSkip and (NewSkip < FSkipUntil) then
    FSkipUntil := NewSkip;

  while true do
  begin
    case InternalAdvance of
      jsError:
        break;
    end;
    if High(FStack) <= FSkipUntil then
    begin
      BeenSkipping := FSkipUntil < MaxInt;
      FSkipUntil := MaxInt;

      // When skipping from inside a structure like this:
      //
      // [
      //   *Skip*
      //
      // After skipping, we still get the closing ]. But the user who called
      // Skip() is not interested in this token, so we have to eat it.
      if BeenSkipping and (StackTop in [jisAfterListItem, jisAfterDictItem])then
        InternalAdvance;

      break;
    end;
  end;

  Result := FState;
  FSkip := Result in [jsDict, jsKey, jsList, jsNumber, jsString, jsBoolean, jsNull];
end;

function TJsonReader.State: TJsonState;
begin
  Result := FState;
end;

function TJsonReader.InternalAdvance: TJsonState;
label
  start;
var
  PoppedItem: TJsonInternalState;
begin
  start:

  if StackTop = jisError then
    FPopUntil := 0;

  if FPopUntil < 0 then
  begin
    // Normal operation
    GetToken;
  end
  else
  begin
    // After an error: Unwind the stack
    while High(FStack) >= FPopUntil do
    begin
      if High(FStack) <= FPopUntil then
        FPopUntil := -1;

      PoppedItem := StackPop;

      case PoppedItem of
        jisListItem, jisListHead, jisAfterListItem:
        begin
          FState := jsListEnd;
          Dec(FNestingDepth);
          break;
        end;
        jisDictItem, jisDictHead, jisAfterDictItem:
        begin
          FState := jsDictEnd;
          Dec(FNestingDepth);
          break;
        end;
        jisInitial, jisEOF:
        begin
          FState := jsEOF;
          StackPush(jisEOF);
          break;
        end
      end;
    end;

    Result := FState;
    FSkip := false;
    Reduce;

    // Note that the above loop only looks at FPopUntil and does not pay respect
    // to FSkipUntil! Therefore it can pop one more element than we actually
    // want to pop. If this case happens, push the item back on. (Unfortunately
    // it is not trivial to integrate the check into the loop condition itself,
    // as we may only know whether we went to far after we called Reduce()).
    if (FSkipUntil < MaxInt) and (High(FStack) < FSkipUntil) then
      StackPush(PoppedItem);

    exit;
  end;

  // Note: The tokenizer only spits out comment tokens in JSON5 mode.
  while FToken in [jtSingleLineComment, jtMultiLineComment] do
  begin
    case FToken of
      jtSingleLineComment: SkipSingleLineComment;
      jtMultiLineComment:  SkipMultiLineComment;
    end;
    GetToken;
  end;

  case StackTop of
    jisInitial:
      case FToken of
        jtEOF:
        begin
          FState := jsEOF;
          StackPop;
          StackPush(jisEOF);
        end
        else if not AcceptValue then
        begin
          FState := jsError;
          InvalidOrUnexpectedToken(
            'Expected `[` or `{`, number, boolean, string or null.'
          );
          StackPush(jisError);
        end;
      end;
    jisEOF:
      FState := jsEOF;
    jisListItem, jisListHead:
      case FToken of
        jtListEnd:
        begin
          if (StackTop = jisListHead) or (jfJson5 in FFeatures) then
          begin
            FState := jsListEnd;
            StackPop;
            Reduce;
            Inc(FPos);
          end
          else
          begin
            FState := jsError;
            SetLastError(
              jeTrailingComma,
              'Trailing comma before end of list.'
            );
            StackPush(jisError);
          end;
        end
        else if not AcceptValue then
        begin
          FState := jsError;
          InvalidOrUnexpectedToken(
            'Expected `[` or `{`, number, boolean, string or null.'
          );
          StackPush(jisError);
        end;
      end;
    jisAfterListItem:
      case FToken of
        jtComma:
        begin
          StackPop;
          StackPush(jisListItem);
          Inc(FPos);
          goto start;
        end;
        jtListEnd:
        begin
          FState := jsListEnd;
          StackPop;
          Reduce;
          Inc(FPos);
          Dec(FNestingDepth);
        end
        else
        begin
          FState := jsError;
          InvalidOrUnexpectedToken('Expected `,` or `]`.');
          StackPush(jisError);
        end;
      end;
    jisDictItem, jisDictHead:
      case FToken of
        jtDictEnd:
        begin
          if (StackTop = jisDictHead) or (jfJson5 in FFeatures) then
          begin
            FState := jsDictEnd;
            StackPop; // DictItem
            Reduce;
            Inc(FPos);
          end
          else
          begin
            FState := jsError;
            SetLastError(
              jeTrailingComma,
              'Trailing comma before end of dict.'
            );
            StackPush(jisError);
          end;
        end
        else if not AcceptKey then
        begin
          FState := jsError;
          InvalidOrUnexpectedToken('Expected string or `}`.');
          StackPush(jisError);
        end;
      end;
    jisAfterDictKey:
      case FToken of
        jtColon:
        begin
          StackPop;
          StackPush(jisDictValue);
          Inc(FPos);
          goto start;
        end
        else
        begin
          FState := jsError;
          InvalidOrUnexpectedToken('Expected `:`.');
          StackPush(jisError);
        end;
      end;
    jisDictValue:
      if not AcceptValue then
      begin
        FState := jsError;
        InvalidOrUnexpectedToken(
          'Expected `[`, `{`, number, boolean, string or null.'
        );
        StackPush(jisError);
      end;
    jisAfterDictItem:
      case FToken of
        jtComma:
        begin
          StackPop; // AfterDictItem
          StackPush(jisDictItem);
          Inc(FPos);
          goto start;
        end;
        jtDictEnd:
        begin
          FState := jsDictEnd;
          StackPop; // AfterDictItem
          Reduce;
          Inc(FPos);
          Dec(FNestingDepth);
        end
        else
        begin
          FState := jsError;
          InvalidOrUnexpectedToken('Expected `,` or `}`.');
          StackPush(jisError);
        end;
      end;
    jisNumber:
      SkipNumber;
    jisBoolean:
      SkipBoolean;
    jisNull:
      SkipNull;
    jisString:
      SkipString;
    jisDictKey:
      SkipKey;
  end;
  Result := FState;
end;

procedure TJsonReader.InvalidOrUnexpectedToken(const Msg: TJsonString);
begin
  case FToken of
    jtUnknown:
      SetLastError(
        jeInvalidToken,
        Format('Unexpected character `%s`. %s', [FBuf[FPos], Msg])
      );
    jtEOF:
      SetLastError(
        jeUnexpectedEOF,
        Format('Unexpected end-of-file. %s', [Msg])
      );
    jtNumber:
      SetLastError(
        jeUnexpectedToken,
        Format('Unexpected numeral. %s', [Msg])
      );
    else
      SetLastError(
        jeUnexpectedToken,
        Format('Unexpected `%s`. %s', [FBuf[FPos], Msg])
      );
  end;
end;

procedure TJsonReader.Skip;
begin
  FSkip := true;
end;


function TJsonReader.InternalProceed: Boolean;
var
  i: Integer;
  Needle: set of TJsonInternalState;
begin
  Result := false;

  if StackTop <> jisError then
    exit;

  // Pop off the jisError state
  StackPop;

  // Skip control characters/whitespace
  if {}(StackTop <> jisString) and (FBuf[FPos] in [#0..#32]) then
  begin
    SkipGarbage;
    exit;
  end;

  // Treat garbage tokens as string
  if (FToken = jtUnknown) or
     (StackTop in [jisDictHead, jisDictItem]) and
     (FToken in [jtNumber, jtTrue, jtFalse, jtNull]) then
  begin
    if StackTop in [jisDictHead, jisDictItem] then
    begin
      StackPush(jisDictKey);
      FState := jsKey;
    end
    else
    begin
      StackPush(jisString);
      FState := jsString;
    end;
    if FBuf[FPos] = '''' then
    begin
      FStringMode := jsmSingleQuoted;
      Inc(FPos);
    end
    else
      FStringMode := jsmUnquoted;
    FStringEnd := false;
    FSkip := true;
    Result := true;
    exit;
  end;

  // List: missing comma
  if (StackTop = jisAfterListItem) and
     (FToken in [jtDict, jtList, jtNumber, jtTrue, jtFalse, jtNull, jtDoubleQuote]) then
  begin
    StackPop;
    StackPush(jisListItem);
    exit;
  end;

  // List: trailing comma
  if (StackTop = jisListItem) and (FToken = jtListEnd) then
  begin
    StackPop;
    StackPush(jisAfterListItem);
    exit;
  end;

  // Dict: missing comma
  if (StackTop = jisAfterDictItem) and
     (FToken in [jtDict, jtList, jtNumber, jtTrue, jtFalse, jtNull, jtDoubleQuote]) then
  begin
    StackPop;
    StackPush(jisDictItem);
    exit;
  end;

  // Dict: trailing comma
  if (StackTop = jisDictItem) and (FToken = jtDictEnd) then
  begin
    StackPop;
    StackPush(jisAfterDictItem);
    exit;
  end;

  // Dict: missing colon
  if StackTop = jisAfterDictKey then
  begin
    StackPop; // AfterDictKey
    StackPush(jisDictValue);
    StackPush(jisNull);
    FState := jsNull;
    FSkip := true;
    Result := true;
    exit;
  end;

  // Dict: missing value after colon
  if StackTop = jisDictValue then
  begin
    StackPush(jisNull);
    FState := jsNull;
    FSkip := true;
    Result := true;
    exit;
  end;

  // Dict: Expected key, but got something else
  if (StackTop in [jisDictHead, jisDictItem]) and
     (FToken in [jtDict, jtList]) then
  begin
    StackPush(jisDictValue);
    FSkip := true;
    exit;
  end;

  // List closed, but node is not a list or
  // Dict closed, but node is not a dict
  // (this rule also catches trailing comma)
  if ((FToken = jtListEnd) and not (StackTop in [jisListHead, jisListItem])) or
     ((FToken = jtDictEnd) and not (StackTop in [jisDictHead, jisDictItem])) then
  begin
    Needle := []; // Shut up compiler warning
    case FToken of
      jtListEnd: Needle := [jisListItem, jisListHead];
      jtDictEnd: Needle := [jisDictItem, jisDictHead];
      else       assert(false);
    end;

    // Check if there is a list further up the stack
    // TODO: This is O(stack depth), therefore a potential performance bottle-
    // neck. It could be implemented in O(1).
    i := High(FStack);
    while (i >= 0) and not (FStack[i] in Needle) do
      dec(i);

    if i < 0 then
    begin
      // There is no list in the stack, so the symbol is bogus, ignore it.
      Inc(FPos);
    end
    else
    begin
      // Pop stack until we sync
      Inc(FPos);
      FPopUntil := i;
    end;

    exit;
  end;

  if FToken in [jtColon, jtComma] then
  begin
    Inc(FPos);
    exit;
  end;

  if StackTop = jisNumber then
  begin
    FState := jsNumber;
    FSkip := true;
    Result := true;
    exit;
  end;

  if StackTop = jisNull then
  begin
    // This case only occurs when a garbage token like 23abc occurred, that
    // looked like  a number at first but turned out to be garbage. ParseNumber
    // then turns that into a null value.
    FState := jsNull;
    FSkip := true;
    Result := true;
    exit;
  end;

  if StackTop = jisString then
  begin
    FStrIgnoreError := true;
    FSkip := true;
    FState := jsString;
    Result := true;
    exit;
  end;

  if StackTop = jisDictKey then
  begin
    FStrIgnoreError := true;
    FSkip := true;
    FState := jsKey;
    Result := true;
    exit;
  end;

  // We could not fix the error. Pop the entire stack
  FPopUntil := 0;
  FSkip := false;

  // Push error state back on
  StackPush(jisError);
end;

function TJsonReader.Proceed: Boolean;
begin
  Result := InternalProceed;

  if Result and (High(FStack) >= FSkipUntil) then
    Advance;
end;

function TJsonReader.LastError: TJsonError;
begin
  Result := FLastError;
end;

function TJsonReader.LastErrorMessage: TJsonString;
begin
  Result := FLastErrorMessage;
end;

function TJsonReader.LastErrorPosition: SizeInt;
begin
  Result := FLastErrorPosition;
end;

function TJsonReader.StrBufInternal(out Buf; BufSize: SizeInt): SizeInt;
var
  i0, i1, o0, o1: SizeInt;
  l:              SizeInt;
  StopChars:      set of char;
  uc:             Cardinal;
  k, n:           Integer;
  _Buf:           TJsonCharArray absolute Buf;
label
  return;

  function HexDigit(c: Char): integer;
  begin
    case c of
      '0'..'9': Result := Ord(c) - Ord('0');
      'a'..'f': Result := Ord(c) - Ord('a') + $a;
      'A'..'Q': Result := Ord(c) - Ord('A') + $a;
      else      Result := -1;
    end;
  end;

begin
  o1 := 0;

  StopChars := []; // Shut up compiler warning

  case FStringMode of
    jsmDoubleQuoted: StopChars := ['\', '"'];
    jsmSingleQuoted: StopChars := ['\', ''''];
    jsmUnquoted:     StopChars := [#0..#32, ':', ',', '{', '}', '[', ']'];
    else             assert(false);
  end;

  // JSON strings must not contain line-breaks
  StopChars := StopChars + [#13, #10];

  // In pure JSON, all codepoints < 32 are not allowed and must be encoded using
  // escape sequences, instead.
  if not (jfJson5 in FFeatures) then
    StopChars := StopChars + [#0..#31];

  FillByte(_Buf[0], BufSize, 0);

  if (BufSize <= 0) or (StackTop = jisError) or FStringEnd then
  begin
    Result := -1;
    exit;
  end;

  while true do
  begin
    // There may be some remaining buffered chars from an escape sequence that
    // need to be emitted  before we can advance.
    if FEscapeSequence <> '' then
    begin
      n := Length(FEscapeSequence);
      if n > BufSize - o1 then
        n := BufSize - o1;

      Move(FEscapeSequence[1], _Buf[o1], n);
      if Length(FEscapeSequence) > n then
        Move(
          FEscapeSequence[n + 1],
          FEscapeSequence[1],
          length(FEscapeSequence) - n
        );
      SetLength(FEscapeSequence, length(FEscapeSequence) - n);
      Inc(o1, n);
    end;

    i0 := FPos;
    i1 := i0;
    o0 := o1;
    l  := FLen;

    // Hopefully, most characters will be regular characters, not escape
    // sequences or string delimiters. We try to copy as much data as we can
    // using a simple block move until we encounter a character that needs
    // special processing.
    while (i1 < l) and (o1 < BufSize) and not (FBuf[i1] in StopChars) do
    begin
      Inc(i1);
      Inc(o1);
    end;
    FPos := i1;
    if o1 > o0 then
      Move(FBuf[i0], _Buf[o0], o1 - o0);

    // Output buffer is full, exit
    if o1 >= BufSize then
      break;

    // EOF Before string end?
    if FLen = 0 then
    begin
      if not FStrIgnoreError then
      begin
        FState := jsError;
        StackPush(jisError);
        SetLastError(jeUnexpectedEOF, 'Unexpected end-of-file.');
      end;

      FStrIgnoreError := false;
      FStringMode := jsmUnquoted; // Hack so we don't increment FPos
      break;
    end;

    // Used up the input buffer? Refill and continue
    if FPos >= FLen then
    begin
      RefillBuffer;
      continue;
    end;

    // When we get here, at the current position we have either
    // - the end of the string
    // - an escape sequence (valid or invalid)
    // - an invalid character (ASCII < 31)

    if FBuf[FPos] = '\' then
    begin
      // We have an escape sequence

      // Maximum length of an escape sequence is 6 (\u1234), so we need 6
      // characters lookahead
      RefillBuffer(6);

      // EOF after the '\'?
      if FPos + 1 >= FLen then
      begin
        if not FStrIgnoreError then
        begin
          FState := jsError;
          StackPush(jisError);
          SetLastError(jeUnexpectedEOF, 'Unexpected end-of-file.');
        end;

        FStrIgnoreError := false;
        break;
      end;

      assert(FEscapeSequence = '');

      // \u1234 escape sequence
      if FBuf[FPos + 1] = 'u' then
      begin
        uc := 0;
        k := 0;

        while (k < 4) and (FPos + 2 + k < FLen) and
              (HexDigit(FBuf[FPos + 2 + k]) >= 0) do
        begin
          uc := uc shl 4 or HexDigit(FBuf[FPos + 2 + k]);
          inc(k);
        end;

        if (k < 4) then
        begin
          if not FStrIgnoreError then
          begin
            FState := jsError;
            StackPush(jisError);
            SetLastError(
              jeInvalidEscapeSequence,
              'Invalid escape sequence in string. Expected four hex digits.'
            );
            break;
          end;

          FStrIgnoreError := false;
        end;

        if k = 0 then
          uc := $fffe;

        FEscapeSequence := TJsonString(UnicodeChar(uc));
        Inc(FPos, 2 + k);
      end
      // Other escape sequence
      else
      begin
        // Number of consumed input characters (usually 2)
        n := 2;
        case FBuf[FPos + 1] of
          '"':  FEscapeSequence := '"';
          '''': FEscapeSequence := '''';
          '\':  FEscapeSequence := '\';
          '/':  FEscapeSequence := '/';
          'b':  FEscapeSequence := #08;
          'f':  FEscapeSequence := #12;
          'n':  FEscapeSequence := #10;
          'r':  FEscapeSequence := #13;
          't':  FEscapeSequence := #09;
          else
          begin
            // JSON5 allows escaping of newline characters (stupid)
            if jfJson5 in FFeatures then
            begin
              if (FBuf[FPos + 1] = #13) and (FBuf[FPos + 2] = #10) then
              begin
                FEscapeSequence := #13#10;
                n := 3;
              end
              else if (FBuf[FPos + 1] = #10) then
              begin
                FEscapeSequence := #10;
                n := 2;
              end;
            end
            else if not FStrIgnoreError then
            begin
              FState := jsError;
              StackPush(jisError);
              SetLastError(
                jeInvalidEscapeSequence,
                'Invalid escape sequence in string.'
              );
              break;
            end
            else
            begin
              FEscapeSequence := Copy(FBuf, FPos + 1, 2);
              FStrIgnoreError := false;
              n := 2;
            end;
          end;
        end;

        Inc(FPos, n);
      end;
    end
    else if (FBuf[FPos] in [#0..#31]) and (FStringMode <> jsmUnquoted) then
    begin
      // Invalid character
      if not FStrIgnoreError then
      begin
        FState := jsError;
        StackPush(jisError);
        SetLastError(
          jeInvalidEscapeSequence,
          'Invalid character in string. Codepoints below 32 must be encoded ' +
          'using escape sequence (\u....).'
        );
        break;
      end
      else
      begin
        _Buf[o1] := FBuf[FPos];
        Inc(FPos);
        inc(o1);
      end;
      FStrIgnoreError := false;
    end
    else
    begin
      // End of string
      assert(
        (FStringMode = jsmUnquoted) or
        ((FStringMode = jsmDoubleQuoted) and (FBuf[FPos] = '"')) or
        ((FStringMode = jsmSingleQuoted) and (FBuf[FPos] = ''''))
      );
      break;
    end;
  end;

return:

  Result := o1;

  FStrIgnoreError := false;

  if (Result = 0) and (StackTop <> jisError) then
  begin
    FStringEnd := true;
    if FStringMode <> jsmUnquoted then
      Inc(FPos);
    Reduce;
  end;

  if (Result = 0) and (StackTop = jisError) then
    Result := -1;
end;

function TJsonReader.StrInternal(out S: TJsonString): Boolean;
var
  Len:   SizeInt;
  Delta: SizeInt;
begin
  S := FSavedStr;
  Len := Length(S);
  SetLength(S, Len + 32);
  while true do
  begin
    if Len = Length(S) then
      SetLength(S, Length(S) * 2);
    Delta := StrBufInternal(S[1 + Len], Length(S) - Len);
    if Delta <= 0 then
    begin
      Result := Delta = 0;
      break;
    end;
    Len := Len + Delta;
  end;
  SetLength(S, Len);
  if Delta < 0 then
  begin
    // There was an error, save temporary result
    FSavedStr := S;
    S := '';
  end
  else
  begin
    FSavedStr := '';
  end;
end;

function TJsonReader.AcceptValue: Boolean;
begin
  Result := false;
  case FToken of
    jtDict:
    begin
      if FNestingDepth >= FMaxNestingDepth then
      begin
        FState := jsError;
        FPopUntil := 0;
        StackPush(jisError);
        SetLastError(
          jeNestingTooDeep,
          Format('Nesting limit of %d exceeded.', [FMaxNestingDepth])
        );
      end
      else
      begin
        FState := jsDict;
        StackPush(jisDictHead);
        Inc(FPos);
        Inc(FNestingDepth);
      end;
      Result := true;
    end;
    jtList:
    begin
      if FNestingDepth >= FMaxNestingDepth then
      begin
        FState := jsError;
        FPopUntil := 0;
        StackPush(jisError);
        SetLastError(
          jeNestingTooDeep,
          Format('Nesting limit of %d exceeded.', [FMaxNestingDepth])
        );
      end
      else
      begin
        FState := jsList;
        StackPush(jisListHead);
        Inc(FPos);
        Inc(FNestingDepth);
      end;
      Result := true;
    end;
    jtNumber:
    begin
      FState := jsNumber;
      StackPush(jisNumber);
      ParseNumber;
      Result := true;
    end;
    jtTrue:
    begin
      FState := jsBoolean;
      StackPush(jisBoolean);
      Inc(FPos, Length('true'));
      Result := true;
    end;
    jtFalse:
    begin
      FState := jsBoolean;
      StackPush(jisBoolean);
      Inc(FPos, Length('false'));
      Result := true;
    end;
    jtNull:
    begin
      FState := jsNull;
      StackPush(jisNull);
      Inc(FPos, Length('null'));
      Result := true;
    end;
    jtDoubleQuote:
    begin
      FState := jsString;
      StackPush(jisString);
      FStringMode := jsmDoubleQuoted;
      FStringEnd := false;
      Inc(FPos);
      Result := true;
    end;
    jtSingleQuote:
    begin
      if jfJson5 in FFeatures then
      begin
        FState := jsString;
        StackPush(jisString);
        FStringMode := jsmSingleQuoted;
        FStringEnd := false;
        Inc(FPos);
        Result := true;
      end
    end;
  end;
end;

function TJsonReader.AcceptKey: Boolean;
begin
  Result := false;
  case FToken of
    jtDoubleQuote:
    begin
      FState := jsKey;
      StackPush(jisDictKey);
      FStringMode := jsmDoubleQuoted;
      FStringEnd := false;
      Inc(FPos);
      Result := true;
    end;
    jtSingleQuote:
    begin
      if jfJson5 in FFeatures then
      begin
        FState := jsKey;
        StackPush(jisDictKey);
        FStringMode := jsmSingleQuoted;
        FStringEnd := false;
        Inc(FPos);
        Result := true;
      end
    end;
    else
    begin
      // In JSON5, unquoted keys should match the JS identifier syntax, i.e.
      // start with a letter or $ or _, but we allow other characters here to
      // reduce code complexity.
      if (jfJson5 in FFeatures) and not (FBuf[FPos] in [
           #0..#32, '0'..'9', '[', ']', '{', '}', '(', ')', '<', '>',
           '.', ':', ',', ';', '+', '-', '*', '/', '%', '^', '~', '&', '|',
           '?', '!', '=', '#'
         ]) then
      begin
        FState := jsKey;
        StackPush(jisDictKey);
        FStringMode := jsmUnquoted;
        FStringEnd := false;
        Result := true;
      end
    end;
  end;
end;

procedure TJsonReader.SetLastError(Error: TJsonError; const Msg: string);
begin
  FLastError         := Error;
  FLastErrorMessage  := Msg;
  FLastErrorPosition := FOffset + FPos;
end;

function TJsonReader.Key(out K: TJsonString): Boolean;
begin
  if FState <> jsKey then
  begin
    Result := False;
    Exit;
  end;

  Result := StrInternal(K);
  FSkip  := false;
  if FState <> jsError then
    Advance;
end;

function TJsonReader.KeyBuf(out Buf; BufSize: SizeInt): SizeInt;
begin
  if FState <> jsKey then
  begin
    Result := -1;
    Exit;
  end;

  Result := StrBufInternal(Buf, BufSize);
  FSkip  := false;

  if (Result = 0) and (BufSize > 0) then
    Advance;
end;

function TJsonReader.Str(out S: TJsonString): Boolean;
begin
  if FState <> jsString then
  begin
    Result := False;
    S := '';
    Exit;
  end;

  Result := StrInternal(S);
  FSkip  := false;
end;

function TJsonReader.StrBuf(out Buf; BufSize: SizeInt): SizeInt;
begin
  if FState <> jsString then
  begin
    Result := -1;
    Exit;
  end;

  Result := StrBufInternal(Buf, BufSize);
  FSkip  := false;
end;

procedure TJsonReader.FinalizeNumber;
begin
  FNumber := '';
  FSkip  := false;
  StackPop;
  Reduce;
end;

function TJsonReader.Number(out Num: Integer): Boolean;
{$ifdef FPC}
{$if FPC_FULLVERSION < 30301}
  // See https://gitlab.com/freepascal.org/fpc/source/-/issues/39406
  function TryStrToInt(const s: string; Out i : integer): Boolean;
  var
    Error : word;
    li : Int64;
  begin
    Val(s, li, Error);
    Result := (Error=0) and (li <= High(i)) and (li >= Low(i));
    if Result then
      i := li;
  end;
{$endif}
{$endif}
begin
  if (FState <> jsNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToInt(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: Cardinal): Boolean;
{$ifdef FPC}
{$if FPC_FULLVERSION < 30301}
  // See https://gitlab.com/freepascal.org/fpc/source/-/issues/39406
  function TryStrToDWord(const s: string; Out i: Cardinal): Boolean;
  var
    Error: Word;
    li:    UInt64;
  begin
    Val(s, li, Error);
    Result := (Error=0) and (li <= High(i)) and (li >= Low(i));
    if Result then
      i := li;
  end;
{$endif}
{$endif}
begin
  if (FState <> jsNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToDWord(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: Int64): Boolean;
begin
  if (FState <> jsNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToInt64(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: UInt64): Boolean;
begin
  if (FState <> jsNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToQWord(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: Double): Boolean;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings.DecimalSeparator := '.';
  FormatSettings.ThousandSeparator := #0;

  if FState <> jsNumber then
  begin
    Result := False;
    exit;
  end;

  Result := true;

  if not TryStrToFloat(FNumber, Num, FormatSettings) then
  begin
    if FNumber = sInfinity then
      Num := math.Infinity
    else if FNumber = '-' + sInfinity then
      Num := math.NegInfinity
    else if FNumber = sNan then
      Num := math.NaN
    else
      Result := false;
  end;

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Bool(out Bool: Boolean): Boolean;
begin
  if FState <> jsBoolean then
  begin
    Result := false;
    exit;
  end;

  case FToken of
    jtTrue:  Bool := true;
    jtFalse: Bool := false;
    else     assert(false);
  end;

  StackPop;
  Reduce;

  Result := true;
  FSkip  := false;
end;

function TJsonReader.Null: Boolean;
begin
  if FState <> jsNull then
  begin
    Result := false;
    exit;
  end;

  StackPop;
  Reduce;

  Result := true;   
  FSkip  := false;
end;

function TJsonReader.Dict: Boolean;
begin
  if FState <> jsDict then
  begin
    Result := False;
    Exit;
  end;
  Result := true;
  FSkip  := false;
end;

function TJsonReader.List: Boolean;
begin
  if FState <> jsList then
  begin
    Result := False;
    Exit;
  end;
  Result := true;
  FSkip  := false;
end;

function TJsonReader.Error: Boolean;
begin
  Result := FState = jsError;
end;

{ TJsonWriter }

constructor TJsonWriter.Create(Stream: TStream; Features: TJsonFeatures;
  PrettyPrint: Boolean; const Indentation: string);
begin
  FNeedComma     := false;
  FNeedColon     := false;
  FWritingString := false;
  FStream        := Stream;
  FFeatures      := Features;
  FPrettyPrint   := PrettyPrint;
  FIndentation   := Indentation;
  StackPush(jisInitial);
end;

procedure TJsonWriter.WriteSeparator(Indent: Boolean);
var
  i: Integer;
begin
  if FNeedColon then
    if FPrettyPrint then
      Write(': ')
    else
      Write(':');

  if FNeedComma then
    Write(',');

  if FPrettyPrint then
  begin
    if Indent and (FNeedComma or FStructEmpty) then
      Write(LineEnding);
    if Indent and not FNeedColon then
    begin
      for i := 0 to FLevel - 1 do
        Write({'  '}FIndentation);
    end;
  end;
  FNeedColon := false;
  FStructEmpty := false;
end;


procedure TJsonWriter.Write(const S: TJsonString);
begin
  WriteBuf(S[1], length(S));
end;

procedure TJsonWriter.WriteBuf(const Buf; BufSize: SizeInt);
var
  i:       SizeInt;
  Written: LongInt;
  _Buf:    TJsonCharArray absolute Buf;
begin
  i := 0;
  while i < BufSize do
  begin
    Written := FStream.Write(_Buf[i], BufSize - i);
    if Written <= 0 then
      raise EStreamError.CreateFmt(
        'Expected to write %d bytes, but only wrote %d bytes.', [BufSize, i]
      );
    Inc(i, Written);
  end;
end;

procedure TJsonWriter.StrBufInternal(const Buf; BufSize: SizeInt; IsKey: Boolean
  );
const
  ChunkSize = 256;
  EntitySize = 6; // \u1234
  HexDigits: array[0..15] of Char =
    ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
var
  Escaped:    array[0 .. EntitySize * ChunkSize - 1] of TJsonChar;
  i, j, o, n: SizeInt;
  _Buf:       TJsonCharArray absolute Buf;
begin
  if not FWritingString then
  begin
    WriteSeparator;
    Write('"');
    FWritingString := true;
  end else if BufSize = 0 then
  begin
    Write('"');
    FWritingString := false;
    if IsKey then
    begin
      FNeedComma := false;
      FNeedColon := true
    end
    else
    begin
      FNeedComma := true;
      FNeedColon := false;
    end;
  end;

  Escaped[0] := #0; // Shut up compiler warning

  i := 0;

  while i < BufSize do
  begin
    n := BufSize - i;
    if n > ChunkSize then
      n := ChunkSize;

    o := 0;
    for j := 0 to n - 1 do
    begin
      if _Buf[i] in ['\', '"'] then
      begin
        Escaped[o] := '\';
        Escaped[o+1] := _Buf[i];
        Inc(o, 2);
        Inc(i);
      end
      else if (_Buf[i] in [#10, #13]) or
              ((_Buf[i] in [#0..#31]) and not (jfJson5 in FFeatures)) then
      begin
        Escaped[o] := '\';
        case _Buf[i] of
          #08: begin Escaped[o+1] := 'b'; Inc(o, 2); end;
          #12: begin Escaped[o+1] := 'f'; Inc(o, 2); end;
          #10: begin Escaped[o+1] := 'n'; Inc(o, 2); end;
          #13: begin Escaped[o+1] := 'r'; Inc(o, 2); end;
          #09: begin Escaped[o+1] := 't'; Inc(o, 2); end;
          else
          begin
            Escaped[o+1] := 'u';
            Escaped[o+2] := '0';
            Escaped[o+3] := '0';
            Escaped[o+4] :=  HexDigits[Ord(_Buf[i]) shr 4];
            Escaped[o+5] :=  HexDigits[Ord(_Buf[i]) and $f];
            Inc(o, 6);
          end;
        end;
        Inc(i);
      end
      else
      begin
        Escaped[o] := _Buf[i];
        Inc(o);
        Inc(i);
      end;
    end;

    WriteBuf(Escaped[0], SizeOf(Escaped[0]) * o);
  end;
end;

procedure TJsonWriter.KeyBegin;
begin
  if StackTop <> jisDictItem then
    raise EJsonWriterSyntaxError.Create('Unexpected key.');
end;

procedure TJsonWriter.KeyEnd;
begin
  Assert(StackTop = jisDictKey);
  StackPop;
  StackPush(jisDictValue);
end;

procedure TJsonWriter.ValueBegin(const Kind: string);
begin
  if not (StackTop in [jisInitial, jisListItem, jisDictValue]) then
    raise EJsonWriterSyntaxError.CreateFmt('Unexpected %s', [Kind]);
end;

procedure TJsonWriter.ValueEnd;
begin
  case StackPop of
    jisInitial:   StackPush(jisEOF);
    jisListItem:  StackPush(jisListItem);
    jisDictValue: StackPush(jisDictItem);
    else         assert(false);
  end;
end;

function TJsonWriter.StackTop: TJsonInternalState;
begin
  assert(Length(FStack) > 0);
  Result := FStack[High(FStack)];
end;

procedure TJsonWriter.StackPush(State: TJsonInternalState);
begin
  SetLength(FStack, Length(FStack) + 1);
  FStack[High(FStack)] := State;
end;

function TJsonWriter.StackPop: TJsonInternalState;
begin
  assert(Length(FStack) > 0);
  Result := FStack[High(FStack)];
  SetLength(FStack, Length(FStack) - 1);
end;

procedure TJsonWriter.Key(const K: TJsonString);
begin
  KeyBegin;

  StrBufInternal(PJsonChar(K)^, SizeOf(TJsonChar) * Length(K), true);
  StrBufInternal(PJsonChar(nil)^, 0, true);

  StackPop;
  StackPush(jisDictValue);
end;

procedure TJsonWriter.KeyBuf(const Buf; BufSize: SizeInt);
var
  IsEnd: Boolean;
begin
  IsEnd := (BufSize = 0) and (StackTop = jisDictKey);

  if not IsEnd then
    KeyBegin;

  StrBufInternal(Buf, BufSize, true);

  if IsEnd then
    KeyEnd;
end;

procedure TJsonWriter.Str(const S: TJsonString);
begin
  ValueBegin('string');

  StrBufInternal(PJsonChar(S)^, SizeOf(TJsonChar) * Length(S), false);
  StrBufInternal(PJsonChar(nil)^, 0, false);

  ValueEnd;
end;

procedure TJsonWriter.StrBuf(const Buf; BufSize: SizeInt);
var
  IsEnd: Boolean;
begin
  IsEnd := (BufSize = 0) and (StackTop = jisString);

  if not IsEnd then
    ValueBegin('string');

  StrBufInternal(Buf, BufSize, false);

  if not IsEnd then
    ValueEnd;
end;

procedure TJsonWriter.Number(Num: Integer);
begin
  ValueBegin('number');

  WriteSeparator;
  Write(IntToStr(Num));
  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.Number(Num: Cardinal);
begin
  Number(uint64(Num));
end;

procedure TJsonWriter.Number(Num: Int64);
begin
  ValueBegin('number');

  WriteSeparator;
  Write(IntToStr(Num));
  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.Number(Num: UInt64);
begin
  ValueBegin('number');

  WriteSeparator;
  Write(IntToStr(Num));
  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.NumberHex(Num: UInt64);
begin
  ValueBegin('number');

  WriteSeparator;
  if jfJson5 in FFeatures then
    Write('0x'+IntToHex(Num, 1))
  else
    Write(IntToStr(Num));
  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.Number(Num: Double);
var
  fs: TFormatSettings;
begin
  ValueBegin('number');

  fs.ThousandSeparator := #0;
  fs.DecimalSeparator := '.';

  if (IsNan(Num) or IsInfinite(Num)) and not (jfJson5 in FFeatures) then
    raise EJsonWriterUnsupportedValue.Create(
      'The values NaN and +/-Inf are not supported by the JSON standard. ' +
      '(Add jfJson5 to Features to be able to use them)'
    );

  WriteSeparator;

  if IsNan(Num) and (jfJson5 in FFeatures) then
    Write('NaN')
  else if IsInfinite(Num) and (Num > 0) and (jfJson5 in FFeatures) then
    Write('Infinity')
  else if IsInfinite(Num) and (Num < 0) and (jfJson5 in FFeatures) then
    Write('-Infinity')
  else
    Write(FloatToStr(Num, fs));

  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.Bool(Bool: Boolean);
begin
  ValueBegin('boolean');

  WriteSeparator;
  if Bool then
    Write('true')
  else
    Write('false');
  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.Null;
begin
  ValueBegin('null');

  WriteSeparator;
  Write('null');
  FNeedComma := true;

  ValueEnd;
end;

procedure TJsonWriter.Dict;
begin
  ValueBegin('dict');
  StackPush(jisDictItem);

  WriteSeparator;
  Write('{');
  FNeedComma := false;
  FStructEmpty := true;
  Inc(FLevel);
end;

procedure TJsonWriter.DictEnd;
begin
  if StackTop <> jisDictItem then
    raise EJsonWriterSyntaxError.Create('Unexpected dict end.');

  FNeedComma := false;
  Dec(FLevel);
  if not FStructEmpty then
  begin
    if FPrettyPrint then
      Write(LineEnding);
    WriteSeparator;
  end;
  Write('}');
  FNeedComma := true;
  FStructEmpty := false;

  StackPop;
  ValueEnd;
end;

procedure TJsonWriter.List;
begin
  ValueBegin('list');
  StackPush(jisListItem);

  WriteSeparator;
  Write('[');
  FNeedComma := false;
  FStructEmpty := true;
  Inc(FLevel);
end;

procedure TJsonWriter.ListEnd;
begin
  if StackTop <> jisListItem then
    raise EJsonWriterSyntaxError.Create('Unexpected list end.');

  FNeedComma := false;
  Dec(FLevel);
  if not FStructEmpty then
  begin
    if FPrettyPrint then
      Write(LineEnding);
    WriteSeparator;
  end;
  Write(']');
  FNeedComma := true;
  FStructEmpty := false;

  StackPop;
  ValueEnd;
end;

end.
