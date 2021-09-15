unit json;

{$mode Delphi}

interface

uses
  SysUtils, Classes;

type

  TJsonToken = (
    jtUnknown, jtEOF, jtDict, jtDictEnd, jtList, jtListEnd, jtComma, jtColon,
    jtNumber, jtString, jtFalse, jtTrue, jtNull
  );

  TJsonInternalState = (
    jsInitial,
    jsError,
    jsEOF,
    jsListHead,
    jsAfterListItem,
    jsListItem,
    jsDictHead,
    jsDictItem,
    jsAfterDictItem,
    jsDictKey,
    jsAfterDictKey,
    jsDictValue,
    jsNumber,
    jsBoolean,
    jsNull,
    jsString
  );

  TJsonState = (
    jnError,
    jnEOF,
    jnDict,
    jnDictEnd,
    jnList,
    jnListEnd,
    jnNumber,
    jnBoolean,
    jnNull,
    jnString,
    jnKey
  );

  TJsonError = (
    jeInvalidToken,
    jeInvalidNumber,
    jeUnexpectedToken,
    jeUnexpectedListEnd,
    jeUnexpectedDictEnd,
    jeUnexpectedEOF
  );

  PJsonState = ^TJsonState;

  { TJsonReader }

  TJsonReader = class
  protected
    FToken:      TJsonToken;

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
    FNumber:     string;
    FNumberErr:  Boolean;

    FStream:     TStream;
    FBuf:        array[0..1023] of Char;
    FLen:        integer;
    FPos:        integer;
    // False for a regular string, true after error recovery when we encounter garbage tokens and
    // fallback to interpreting them as a string.
    FFauxString: boolean;

    FStack:      array of TJsonInternalState;
    FSavedStack: array of TJsonInternalState;
    FState:      TJsonState;

    // Stack depth up until which we must pop after an error.
    FPopUntil:   integer;
    // Stack depth up until which a skip was issued.
    FSkipUntil:  integer;
    // Whether current item should be skipped upon next call to Advance.
    FSkip:       Boolean;

    FLastError:  TJsonError;
    FLastErrorMessage: string;

    // Tokenizer
    procedure GetToken;

    // Stack machine
    function  StackTop: TJsonInternalState;
    procedure StackPush(State: TJsonInternalState);
    function  StackPop: TJsonInternalState;
    procedure Reduce;

    // Parsing helpers
    procedure RefillBuffer;
    procedure SkipSpace;
    function  MatchString(const Str: string): Boolean;
    procedure ParseNumber;
    //function  InitNumber: Boolean;
    procedure FinalizeNumber;

    // Skip helpers
    procedure SkipNumber;
    procedure SkipBoolean;   
    procedure SkipNull;
    procedure SkipString;
    procedure SkipKey;

    // Key/Str helpers
    function  StrBufInternal(out Buf; BufSize: SizeInt): SizeInt;
    function  StrInternal(out S: String): Boolean;

    // Internal functions
    function  InternalAdvance: TJsonState;
    procedure InternalProceed;
    procedure InvalidOrUnexpectedToken(const Msg: string);
  public
    constructor Create(Stream: TStream);

    // === General traversal ===

    // Move to the next element and return the new parse state.
    // TODO: This function is probably confusing as its behavior for lists/dicts
    // depends on whether List/Dict was called prior to its invokation or not:
    // - If List/Dict was NOT called, then the list/dict will be skipped and
    //   the next element will be its next sibling.
    // - If List/Dict WAS called, then the next element will be its first child,
    //   or the matching ListEnd/DictEnd element, if the list/dict is empty.
    function  Advance: TJsonState;

    // Return the current parse state.
    function  State: TJsonState;

    // Skip current element. If the element is a list or a dict, then all its
    // children will be skipped.
    procedure Skip;


    // === Acceptor functions for specific elements ===

    // Returns true iff the current element is a dict entry and stores its key
    // in K. If true is returned, then the current element is automatically
    // advanced to the value of the entry.
    function  Key(out K: String): Boolean;

    // This function is like Key, except that it does not return the full key,
    // but only reads part of it. This is intended for situations where the key
    // could be very large and it would not be efficient to allocate it in
    // memory its entirety. The semantics are the same as the read() syscall
    // on Unix: Up to BufSize bytes are read and stored in Buf.
    // Return value:
    //   > 0: The number of bytes actually read.
    //   = 0: Indicates the end of the key.
    //   < 0: An error occurred (invalid escape sequence or missing trailing ").
    // If an error occurred, you can call Proceed() to ignore it and try to
    // continue reading.
    function  KeyBuf(out Buf; BufSize: SizeInt): SizeInt;

    // Returns true iff the current element is a string value. If true is
    // is returned, then the decoded string value is stored in S.
    function  Str(out S: String): Boolean;

    // This function is like St, except that it does not return the full string,
    // but only reads part of it. This is intended for situations where the
    // string could be very large ind it would not be efficient to allocate it
    // in memory in its entirety. The semantics are the same as the read()
    // syscall on Unix: Up to BufSize bytes are read and stored in Buf.  
    // Return value:
    //   > 0: The number of bytes actually read.
    //   = 0: Indicates the end of the string.
    //   < 0: An error occurred (invalid escape sequence or missing trailing ").
    // If an error occurred, you can call Proceed() to ignore it and try to
    // continue reading.
    function  StrBuf(out Buf; BufSize: SizeInt): SizeInt;

    // Returns true iff the current element is a number that can be exactly
    // represented by an integer and returns its value in Num.
    function  Number(out Num: integer): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an int64 and returns its value in Num.
    function  Number(out Num: int64): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an uint64 and returns its value in Num.
    function  Number(out Num: uint64): Boolean; overload;
    // Returns true iff the current element is a number and returns its value 
    // in Num. If the number exceeds the representable precision or range of a
    // double precision float, it will be rounded to the closest approximation.
    function  Number(out Num: double): Boolean; overload;

    // Returns true iff the current element is a boolean and returns its value
    // in bool.
    function  Bool(out Bool: Boolean): Boolean;

    // Returns true iff the current element is a null value.
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
    function Proceed: Boolean;

    // Return last error code. A return value of 0 means that there was no
    // error. A return value other than 0 indicates that there was an error.
    function LastError: TJsonError;

    // Return error message for last error.
    function  LastErrorMessage: string;
  end;

  { TJsonWriter }
  {
  TJsonWriter = class
  protected
    FStream: TStream;
  public
    constructor Create(Stream: TStream);

    procedure BeginDict;
    procedure EndDict;
    procedure BeginList;
    procedure EndList;

    procedure IntVal(val: integer);
    procedure StringVal(const val: String);
    procedure WriteVal(const Buf; n: SizeInt);

    procedure Key(Key: String);
    procedure WriteKey(const Buf; n: SizeInt);
  end;
  }

implementation

{ TJsonReader }

constructor TJsonReader.Create(Stream: TStream);
begin
  FStream    := Stream;
  FLen       := 0;
  FPos       := 0;      
  FPopUntil  := -1;
  FSkipUntil := MaxInt;
  FSkip      := false;
  StackPush(jsInitial);
  Advance;
end;

procedure TJsonReader.RefillBuffer;
begin
  if FPos >= FLen then
  begin
    FLen := FStream.Read(FBuf, length(FBuf));
    FPos := 0;
  end;

  assert((FPos < FLen) or (FLen = 0));
end;

procedure TJsonReader.SkipSpace;
begin
  repeat
    while (FPos < FLen) and (FBuf[FPos] in [' ', #9, #13, #10]) do
      Inc(FPos);

    RefillBuffer;
  until (FPos < FLen) or (FLen <= 0);
end;

procedure TJsonReader.SkipNumber;
begin
  if FState <> jnNumber then
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
var
  dummy: Boolean;
begin
  Bool(dummy);
end;

procedure TJsonReader.SkipString;
var
  dummy: string;
begin
  // TODO: Be more efficient. We don't actually care about the string so we
  // should not allocate it.
  Str(dummy);
end;

procedure TJsonReader.SkipKey;
var
  dummy: string;
begin    
  // TODO: Be more efficient. We don't actually care about the string so we
  // should not allocate it.
  Key(dummy);
end;

function TJsonReader.MatchString(const Str: string): Boolean;
var
  n: SizeInt;
  i: integer;
begin
  Result := false;

  if FLen - FPos < length(Str) then
  begin
    Move(FBuf[FPos], FBuf[0], FLen - FPos);
    FLen := FLen - FPos;
    FPos := 0;
    n := FStream.Read(FBuf[FLen], length(FBuf) - FLen);
    if n > 0 then
      FLen := FLen + n;
  end;

  if FLen < length(Str) then
    exit;

  for i := 0 to length(Str) - 1 do
    if FBuf[FPos + i] <> Str[i + 1] then
      exit;

  if (FLen > length(Str)) and not (FBuf[FPos + length(Str)] in [#0..#32, '[', ']', '{', '}', ':', ',', ';', '"']) then
    exit;

  Result := true;
end;

procedure TJsonReader.ParseNumber;
var
  Buf: array[0..768-1 + 1 { sign }] of char;
  i, n:   integer;
  Exponent:  integer;
  LeadingZeroes: integer;
  TmpExp:   integer;
  TmpExpSign: integer;

  function SkipZero: integer;
  var
    j: integer;
  begin
    Result := 0;
    while (FBuf[FPos] = '0') do
    begin
      for j := FPos to FLen do
      begin
        if FBuf[FPos] <> '0' then
          break;
        Inc(Result);
        Inc(FPos);
      end;
      RefillBuffer;
    end;
  end;

  function ReadDigits: integer;
  var
    j: integer;
  begin
    Result := 0;
    while (FLen >= 0) and (FBuf[FPos] in ['0'..'9']) do
    begin
      for j := FPos to FLen do
      begin
        if not (FBuf[FPos] in ['0'..'9']) then
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
  n        := 0;
  Exponent := 0;
  FNumber  := '';
  FNumberErr := false;

  if FBuf[FPos] in ['-','+'] then
  begin
    // Leading + not allowed by JSON
    if (FBuf[FPos] = '+') then
    begin
      FNumberErr := true;  
      FLastError := jeInvalidNumber;
      FLastErrorMessage := 'Number has leading `+`.';
    end;

    Buf[n] := FBuf[FPos];
    Inc(n);
    Inc(FPos);
    RefillBuffer;
  end;

  LeadingZeroes := SkipZero;

  RefillBuffer;

  // JSON does not allow leading zeroes
  if (LeadingZeroes > 1) or
     (LeadingZeroes > 0) and (FLen >= 0) and (FBuf[FPos] in ['0'..'9']) then
  begin
    FNumberErr := true;   
    FLastError := jeInvalidNumber;
    FLastErrorMessage := 'Number has leading zeroes.';
  end;

  if (LeadingZeroes > 0) and not ((FLen >= 0) and (FBuf[FPos] in ['0'..'9'])) then
  begin
    if (FLen >= 0) and (FBuf[FPos] = '.') then
    begin
      // 0.something
      Inc(FPos);
      RefillBuffer;
      // JSON required digit after decimal point
      if (FLen < 0) or not (FBuf[FPos] in ['0'..'9']) then
      begin
        FNumberErr := true;  
        FLastError := jeInvalidNumber;
        FLastErrorMessage := 'Expected digit after decimal point.';
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
    // JSON number must have a digit before the decimal point
    if ReadDigits <= 0 then
      FNumberErr := true;
    if FBuf[FPos] = '.' then
    begin
      Inc(FPos);
      RefillBuffer;
      // JSON required digit after decimal point
      if (FLen < 0) or not (FBuf[FPos] in ['0'..'9']) then
      begin
        FNumberErr := true; 
        FLastError := jeInvalidNumber;
        FLastErrorMessage := 'Expected digit after decimal point.';
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

    for i := FPos to FLen do
    begin
      if not (FBuf[FPos] in ['0'..'9']) then
        break;
      // The Exponent range for double is from like -324 to +308 or something,
      // we just want to make sure we don't overflow. Everything below or above
      // will be rounded to -INF or +INF anyway.
      if TmpExp < 10000 then
        TmpExp := TmpExp * 10 + (ord(FBuf[FPos]) - ord('0'));

      Inc(FPos);
    end;
    Exponent := Exponent + TmpExpSign * TmpExp;
  end;

  FNumber := Copy(Buf, 1, n);
  if Exponent <> 0 then
    FNumber := FNumber + 'e' + IntToStr(Exponent);


  // Check if there is garbage at the end
  RefillBuffer;
  if (FLen > 0) and not (FBuf[FPos] in [#0..#32, '[', ']', '{', '}', ':', ',', ';', '"']) then
  begin
    StackPop; // Was never a number to begin with
    StackPush(jsError);
    FState := jnError;
    FLastError := jeInvalidToken;
    FLastErrorMessage := 'Invalid token.';

    // Skip rest of token
    repeat
      while (FPos < FLen) and not (FBuf[FPos] in [#0..#32, '[', ']', '{', '}', ':', ',', ';', '"']) do
        Inc(FPos);

      RefillBuffer;
    until (FPos < FLen) or (FLen <= 0);

    exit;
  end;

  if FNumberErr then
  begin               
    FState := jnError;
    StackPush(jsError);
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

  case FBuf[FPos] of
    '{':      FToken := jtDict;
    '}':      FToken := jtDictEnd;
    '[':      FToken := jtList;
    ']':      FToken := jtListEnd;
    ',':      FToken := jtComma;
    ':':      FToken := jtColon;
    '0'..'9', '-', '+':
              FToken := jtNumber;
    '"':      FToken := jtString;
    't':
      if MatchString('true') then
        FToken := jtTrue
      else
        FToken := jtUnknown;
    'f':
      if MatchString('false') then
        FToken := jtFalse
      else
        FToken := jtUnknown;
    'n':
      if MatchString('null') then
        FToken := jtNull
      else
        FToken := jtUnknown;
    else
      FToken := jtUnknown;
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
      jsDictKey:
      begin
        StackPop;
        StackPush(jsAfterDictKey);
      end;
      jsString:
      begin
        StackPop;
      end;
      jsDictValue:
      begin
        StackPop;
        StackPop;
        StackPush(jsAfterDictItem);
      end;
      jsListHead, jsListItem:
      begin
        StackPop;
        StackPush(jsAfterListItem);
      end
      else
        break;
    end;
end;

function TJsonReader.Advance: TJsonState;
var
  NewSkip: integer;
  BeenSkipping: Boolean;
begin
  if StackTop in [jsListHead, jsDictHead] then
    NewSkip := High(FStack) - 1
  else
    NewSkip := High(FStack);

  if FSkip and (NewSkip < FSkipUntil) then
    FSkipUntil := NewSkip;

  while true do
  begin
    case InternalAdvance of
      jnError:
        break;
    end;  
    if High(FStack) <= FSkipUntil then
    begin
      BeenSkipping := FSkipUntil < MaxInt;  
      FSkipUntil := MaxInt;

      // When skiping from inside a structure like this:
      //
      // [
      //   *Skip*
      //
      // After skipping, we still get the closing ]. But the user who called Skip() is not interested in i
      // this token, so we have to eat it.
      if BeenSkipping and (StackTop in [jsAfterListItem, jsAfterDictItem]) then
        InternalAdvance;

      break;
    end;
  end;

  Result := FState;
  FSkip := Result in [jnDict, jnKey, jnList, jnNumber, jnString];
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

  if StackTop = jsError then
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
        jsListItem, jsListHead, jsAfterListItem:
        begin
          FState := jnListEnd;
          break;
        end;
        jsDictItem, jsDictHead, jsAfterDictItem:
        begin
          FState := jnDictEnd;
          break;
        end;
        jsInitial, jsEOF:
        begin
          FState := jnEOF;
          StackPush(jsEOF);
          break;
        end
      end;

    end;

    Result := FState;
    FSkip := false;
    Reduce;   

    // Note that the above loop only looks at FPopUntil and does not pay respect to FSkipUntil!
    // Therefore it can pop one more element than we actually want to pop. If this case happens,
    // push the item back on. (Unfortunately it is not trivial to integrate the check into the
    // loop condition itself, as we may only know whether we went to far after we called Reduce()).
    if (FSkipUntil < MaxInt) and (High(FStack) < FSkipUntil) then
      StackPush(PoppedItem);

    exit;
  end;

  case StackTop of
    jsInitial: 
      case FToken of
        jtEOF:
        begin
          FState := jnEOF;
          StackPop;
          StackPush(jsEOF);
        end;
        jtDict:
        begin
          FState := jnDict;
          StackPush(jsDictHead);
          Inc(FPos);
        end;
        jtList:
        begin
          FState := jnList;
          StackPush(jsListHead);
          Inc(FPos);
        end
        {
        jtNumber:
          FState := jnNumber;
          StackPush(jsNumber);
          ParseNumber;
        jtString:
          FState := jnString;
          StackPush(jsString);
          FFauxString := false;
          Inc(FPos);
        }
        else
        begin
          FState := jnError;
          InvalidOrUnexpectedToken('Expected `[` or `{`.');
          StackPush(jsError);
        end;
      end;
    jsEOF:
      FState := jnEOF;
    jsListItem, jsListHead:
      case FToken of
        jtDict:
        begin
          FState := jnDict;
          StackPush(jsDictHead);
          Inc(FPos);
        end;
        jtList:
        begin
          FState := jnList;
          StackPush(jsListHead);
          Inc(FPos);
        end;
        jtNumber:
        begin
          FState := jnNumber;
          StackPush(jsNumber);
          ParseNumber;
        end;
        jtTrue:
        begin
          FState := jnBoolean;
          StackPush(jsBoolean);
          Inc(FPos, Length('true'));
        end;
        jtFalse:
        begin
          FState := jnBoolean;
          StackPush(jsBoolean);
          Inc(FPos, Length('false'));
        end;
        jtNull:
        begin
          FState := jnNull;
          StackPush(jsNull);
          Inc(FPos, Length('null'));
        end;
        jtString:
        begin
          FState := jnString;
          StackPush(jsString);
          FFauxString := false;
          Inc(FPos);
        end;
        jtListEnd:
        begin
          if StackTop = jsListHead then
          begin
            FState := jnListEnd;
            StackPop;
            Reduce;
            Inc(FPos);
          end
          else
          begin
            FState := jnError;
            FLastError := jeUnexpectedListEnd;
            FLastErrorMessage := 'Trailing comma before end of list.';
            StackPush(jsError);
          end;
        end
        else
        begin
          FState := jnError;
          InvalidOrUnexpectedToken('Expected `[` or `{`, number, boolean, string or null.');
          StackPush(jsError);
        end;
      end;
    jsAfterListItem:
      case FToken of
        jtComma:
        begin
          StackPop;
          StackPush(jsListItem);
          Inc(FPos);    
          goto start;
        end;
        jtListEnd:
        begin
          FState := jnListEnd;
          StackPop;
          Reduce;
          Inc(FPos);
        end
        else
        begin
          FState := jnError;   
          InvalidOrUnexpectedToken('Expected `,` or `]`.');
          StackPush(jsError);
        end;
      end;
    jsDictItem, jsDictHead:
      case FToken of
        jtString:
        begin
          FState := jnKey;
          StackPush(jsDictKey);
          FFauxString := false;
          Inc(FPos);
        end;
        jtDictEnd:
        begin
          if StackTop = jsDictHead then
          begin
            FState := jnDictEnd;
            StackPop; // DictItem
            Reduce;
            Inc(FPos);
          end
          else
          begin
            FState := jnError;
            FLastError := jeUnexpectedDictEnd;    
            FLastErrorMessage := 'Trailing comma before end of dict.';
            StackPush(jsError);
          end;
        end
        else
        begin
          FState := jnError;   
          InvalidOrUnexpectedToken('Expected string or `}`.');
          StackPush(jsError);
        end;
      end;
    jsAfterDictKey:
      case FToken of
        jtColon:
        begin
          StackPop;
          StackPush(jsDictValue);
          Inc(FPos);
          goto start;
        end
        else
        begin
          FState := jnError;  
          InvalidOrUnexpectedToken('Expected `:`.');
          StackPush(jsError);
        end;
      end;
    jsDictValue: 
      case FToken of
        jtDict:
        begin
          FState := jnDict;
          StackPush(jsDictHead);
          Inc(FPos);
        end;
        jtList:
        begin
          FState := jnList;
          StackPush(jsListHead);
          Inc(FPos);
        end;
        jtNumber:
        begin
          FState := jnNumber;
          StackPush(jsNumber);   
          ParseNumber;
        end;
        jtTrue:
        begin
          FState := jnBoolean;
          StackPush(jsBoolean);
          Inc(FPos, Length('true'));
        end;
        jtFalse:
        begin
          FState := jnBoolean;
          StackPush(jsBoolean);
          Inc(FPos, Length('false'));
        end;
        jtNull:
        begin
          FState := jnNull;
          StackPush(jsNull);
          Inc(FPos, Length('null'));
        end;
        jtString:
        begin
          FState := jnString;
          StackPush(jsString);
          FFauxString := false;
          Inc(FPos);
        end
        else
        begin
          FState := jnError;    
          InvalidOrUnexpectedToken('Expected `[`, `{`, number, boolean, string or null.');
          StackPush(jsError);
        end;
      end;
    jsAfterDictItem:
      case FToken of
        jtComma:
        begin
          StackPop; // AfterDictItem
          StackPush(jsDictItem);
          Inc(FPos);
          goto start;
        end;
        jtDictEnd:
        begin
          FState := jnDictEnd;
          StackPop; // AfterDictItem
          Reduce;
          Inc(FPos);
        end
        else
        begin
          FState := jnError;    
          InvalidOrUnexpectedToken('Expected `,` or `}`.');
          StackPush(jsError);
        end;
      end;
    jsNumber:
      SkipNumber;
    jsBoolean:
      SkipBoolean;
    jsNull:
      SkipNull;
    jsString:
      SkipString;
    jsDictKey:
      SkipKey;
  end;
  Result := FState;
end;

procedure TJsonReader.InvalidOrUnexpectedToken(const Msg: string);
begin
  case FToken of
    jtUnknown:
    begin
      FLastError := jeInvalidToken;
      FLastErrorMessage := Format('Unexpected character `%s`. %s', [FBuf[FPos], Msg]);
    end;
    jtEOF:
    begin
      FLastError := jeUnexpectedEOF;
      FLastErrorMessage := Format('Unexpected end-of-file. %s', [Msg]);
    end;
    jtNumber:
    begin    
      FLastError := jeUnexpectedToken;
      FLastErrorMessage := Format('Unexpected numeric token. %s', [Msg]);
    end
    else
    begin
      FLastError := jeUnexpectedToken;
      FLastErrorMessage := Format('Unexpected `%s`. %s', [FBuf[FPos], Msg]);
    end;
  end;
end;

procedure TJsonReader.Skip;
begin
  FSkip := true;
end;


procedure TJsonReader.InternalProceed;
var
  i: integer;
  Needle: set of TJsonInternalState;
begin
  if FState <> jnError then
    exit;

  // Pop off the jsError state
  StackPop;

  // Treat garbage tokens as string
  if (FToken = jtUnknown) or
     (StackTop in [jsDictHead, jsDictItem]) and (FToken in [jtNumber, jtTrue, jtFalse, jtNull]) then
  begin
    if StackTop in [jsDictHead, jsDictItem] then
    begin
      StackPush(jsDictKey);
      FState := jnKey;
    end
    else
    begin
      StackPush(jsString);
      FState := jnString;
    end;
    FFauxString := true;
    FSkip := true;
    exit;
  end;

  // List: missing comma
  if (StackTop = jsAfterListItem) and
     (FToken in [jtDict, jtList, jtNumber, jtTrue, jtFalse, jtNull, jtString]) then
  begin
    StackPop;
    StackPush(jsListItem);
    exit;
  end;

  // List: trailing comma
  if (StackTop = jsListItem) and  (FToken = jtListEnd) then
  begin
    StackPop;
    StackPush(jsAfterListItem);
    exit;
  end;

  // Dict: missing comma
  if (StackTop = jsAfterDictItem) and
     (FToken in [jtDict, jtList, jtNumber, jtTrue, jtFalse, jtNull, jtString]) then
  begin
    StackPop;
    StackPush(jsDictItem);
    exit;
  end;

  // Dict: trailing comma
  if (StackTop = jsDictItem) and  (FToken = jtDictEnd) then
  begin
    StackPop;
    StackPush(jsAfterDictItem);
    exit;
  end;

  // Dict: missing colon
  if StackTop = jsAfterDictKey then
  begin
    StackPop; // AfterDictKey
    StackPush(jsDictValue);
    StackPush(jsNull);
    FState := jnNull;
    FSkip := true;
    exit;
  end;

  // Dict: missing value after colon
  if StackTop = jsDictValue then
  begin
    StackPush(jsNull);
    FState := jnNull;
    FSkip := true;
    exit;
  end;

  // Dict: Expected key, but got something else
  if (StackTop in [jsDictHead, jsDictItem]) and (FToken in [jtDict, jtList{, jtNumber, jtTrue, jtFalse, jtNull}]) then
  begin
    StackPush(jsDictValue);
    FSkip := true;
    exit;
  end;

  // List closed, but node is not a list or
  // Dict closed, but node is not a dict
  // (this rule also catches trailing comma)
  if ((FToken = jtListEnd) and not (StackTop in [jsListHead, jsListItem])) or
     ((FToken = jtDictEnd) and not (StackTop in [jsDictHead, jsDictItem])) then
  begin
    case FToken of
      jtListEnd: Needle := [jsListItem, jsListHead];
      jtDictEnd: Needle := [jsDictItem, jsDictHead];
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

  if StackTop = jsNumber then
  begin
    FState := jnNumber;
    FSkip := true;
    exit;
  end;

  // We could not fix the error. Pop the entire stack
  FPopUntil := 0;
  FSkip := false;
end;

function TJsonReader.Proceed: Boolean;
begin
  InternalProceed;
  if (High(FStack) >= FSkipUntil) then
    Advance;

  // If InternalProceed makes progress, the jsError state is always removed from the stack.
  // Therefore, if there is a jsError state on the stack, then it is a new error encountered during Advance().
  // This error needs to be handled by the caller.
  Result := StackTop = jsError;
end;

function TJsonReader.LastError: TJsonError;
begin
  Result := FLastError;
end;

function TJsonReader.LastErrorMessage: string;
begin
  Result := FLastErrorMessage;
end;

function TJsonReader.StrBufInternal(out Buf; BufSize: SizeInt): SizeInt;
var
  i0, i1, o0, o1: SizeInt;
  l: SizeInt;
  StopChars: set of char;
begin
  o0 := 0;

  if FFauxString then
    StopChars := [#0..#32, '\', ':', ',', '{', '}', '[', ']']
  else
    StopChars := ['\', '"'];

  while true do
  begin
    i0 := FPos;
    i1 := i0;
    o1 := o0;
    l  := Flen;

    while (i1 < l) and (o1 < BufSize) and not (FBuf[i1] in StopChars) do
    begin
      Inc(i1);
      Inc(o1);
    end;

    FPos := i1;

    Move(FBuf[i0], PChar(SizeInt(@Buf) + o0)^, o1 - o0);

    if o1 >= BufSize then
      break;

    if FLen = 0 then
    begin
      // EOF Before string end
      FState := jnError;
      StackPush(jsError);
      FLastError := jeUnexpectedEOF;
      FLastErrorMessage := 'Unexpected end-of-file.';
      break;
    end;

    if FPos >= FLen then
    begin
      RefillBuffer;
      continue;
    end;

    if FBuf[FPos] = '\' then
    begin
      Inc(FPos);
      RefillBuffer;
      if FLen = 0 then
      begin
        // EOF Before string end
        FState := jnError;    
        FLastError := jeUnexpectedEOF;
        FLastErrorMessage := 'Unexpected end-of-file.';
        break;
      end;

      // TODO: Handle \xAB escape codes

      PChar(SizeInt(@Buf) + o1)^ := FBuf[FPos];
      Inc(FPos);
      inc(o1);
    end
    else
    begin
      // End of string
      break;
    end;
  end;

  Result := o1;

  if (Result = 0) and (StackTop <> jsError) then
  begin
    if not FFauxString then
      Inc(FPos);
    Reduce;
  end;
end;

function TJsonReader.StrInternal(out S: String): Boolean;
var
  Len:   SizeInt;
  Delta: SizeInt;
begin
  SetLength(S, 32);
  Len := 0;
  while true do
  begin
    if Len = Length(S) then
      SetLength(S, Length(S) * 2);
    Delta := StrBufInternal(S[1], Length(S) - Len);
    if Delta <= 0 then
    begin
      Result := Delta = 0;
      break;
    end;
    Len := Len + Delta;
  end;
  SetLength(S, Len);
end;

function TJsonReader.Key(out K: String): Boolean;
begin
  if FState <> jnKey then
  begin
    Result := False;
    Exit;
  end;

  Result := StrInternal(K);
  FSkip  := false;
  if FState <> jnError then
    InternalAdvance;
end;

function TJsonReader.KeyBuf(out Buf; BufSize: SizeInt): SizeInt;
begin
  if FState <> jnKey then
  begin
    Result := -1;
    Exit;
  end;    

  Result := StrBufInternal(Buf, BufSize);
  FSkip  := false;

  if (Result = 0) and (BufSize > 0) then
    InternalAdvance;
end;

function TJsonReader.Str(out S: String): Boolean;
begin
  if FState <> jnString then
  begin
    Result := False;
    Exit;
  end;

  Result := StrInternal(S);
  FSkip  := false;
end;

function TJsonReader.StrBuf(out Buf; BufSize: SizeInt): SizeInt;
begin
  if FState <> jnString then
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

function TJsonReader.Number(out Num: integer): Boolean;
begin
  if (FState <> jnNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToInt(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: int64): Boolean;
begin
  if (FState <> jnNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToInt64(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: uint64): Boolean;
begin
  if (FState <> jnNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToUInt64(FNumber, Num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out Num: double): Boolean;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings.DecimalSeparator := '.';
  FormatSettings.ThousandSeparator := #0;

  if (FState <> jnNumber) then
  begin
    Result := False;
    exit;
  end;

  Result := TryStrToFloat(FNumber, Num, FormatSettings);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Bool(out Bool: Boolean): Boolean;
begin
  if FState <> jnBoolean then
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
  if FState <> jnNull then
  begin
    Result := false;
    exit;
  end;

  // When there is a parse error after a dict key, we inject a fake null value.
  // Don't want to reset the skip flag in that case.
  StackPop;
  Reduce;

  FSkip  := false;
  Result := true;
end;

function TJsonReader.Dict: Boolean;
begin
  if FState <> jnDict then
  begin
    Result := False;
    Exit;
  end;
  Result := true;
  FSkip  := false;
end;

function TJsonReader.List: Boolean;
begin
  if FState <> jnList then
  begin
    Result := False;
    Exit;
  end;
  Result := true;
  FSkip  := false;
end;

function TJsonReader.Error: Boolean;
begin
  Result := FState = jnError;
end;

end.
