unit json;

{$mode Delphi}

interface

uses
  SysUtils, Classes;

type

  TJsonToken = (
    jtError, jtEOF, jtDict, jtDictEnd, jtList, jtListEnd, jtComma, jtColon,
    jtNumber, jtString, jtFalse, jtTrue, jtNull
  );

  TJsonInternalState = (
    jsInitial,
    jsError,
    jsEOF,
    jsListItem,
    jsAfterListItem,
    jsDictItem,
    jsDictKey,
    jsAfterDictKey,
    jsDictValue,
    jsAfterDictItem,
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

    FStack:      array of TJsonInternalState;
    FSavedStack: array of TJsonInternalState;
    FState:      TJsonState;

    // Stack depth up until which we must pop after an error.
    FPopUntil:   integer;
    // Stack depth up until which a skip was issued.
    FSkipUntil:  integer;
    // Whether we encountered an error while skipping.
    FSkipError:  Boolean;
    // Whether current item should be skipped upon next call to Advance.
    FSkip:       Boolean;

    FLastError:  integer;
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
    function  MatchString(const str: string): Boolean;
    procedure ParseNumber;
    function  InitNumber: Boolean;
    procedure FinalizeNumber;

    // Skip helpers
    procedure SkipNumber;
    procedure SkipBoolean;
    procedure SkipString;
    procedure SkipKey;

    procedure SkipEx(AutoProceed: Boolean);
    function  InternalAdvance: TJsonState;

    // Key/Str helpers
    function  StrBufInternal(out Buf; BufSize: SizeInt): SizeInt;
    function  StrInternal(out S: String): Boolean;
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
    // represented by an integer and returns its value in num.
    function  Number(out num: integer): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an int64 and returns its value in num.
    function  Number(out num: int64): Boolean; overload;
    // Returns true iff the current element is a number that can be exactly
    // represented by an uint64 and returns its value in num.
    function  Number(out num: uint64): Boolean; overload;
    // Returns true iff the current element is a number and returns its value 
    // in num. If the number exceeds the representable precision or range of a
    // double precision float, it will be rounded to the closest approximation.
    function  Number(out num: double): Boolean; overload;

    // Returns true iff the current element is a boolean and returns its value
    // in bool.
    function  Bool(out bool: Boolean): Boolean;

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
    procedure Proceed;

    // Return last error code. A return value of 0 means that there was no
    // error. A return value other than 0 indicates that there was an error.
    function  LastError: integer;

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
var
  dummy: integer;
begin
  if FNumber = '' then
    ParseNumber;

  if FState <> jnNumber then
    Exit;

  FNumber := '';
  FSkip  := false;
  StackPop;
  Reduce;
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

function TJsonReader.MatchString(const str: string): Boolean;
var
  n: SizeInt;
  i: integer;
begin
  Result := false;

  if FLen - FPos < length(str) then
  begin
    Move(FBuf[FPos], FBuf[0], FLen - FPos);
    FLen := FLen - FPos;
    FPos := 0;
    n := FStream.Read(FBuf[FLen], length(FBuf) - FLen);
    if n > 0 then
      FLen := FLen + n;
  end;

  if FLen < length(str) then
    exit;

  for i := 0 to length(str) - 1 do
    if FBuf[FPos + i] <> str[i + 1] then
      exit;

  Result := true;
end;

procedure TJsonReader.ParseNumber;
var
  Buf: array[0..768-1 + 1 { sign }] of char;
  i, n, m:   integer;
  exponent:  integer;
  leading_zeroes: integer;
  tmp_exp:   integer;
  tmp_exp_sign: integer;
  dec_point: integer;
  error:        boolean;

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
  m        := 0;
  exponent := 0;
  FNumber  := '';
  FNumberErr := false;

  if FBuf[FPos] in ['-','+'] then
  begin
    // Leading + not allowed by JSON
    if (FBuf[FPos] = '+') then
      FNumberErr := true;

    Buf[n] := FBuf[FPos];
    Inc(n);
    Inc(FPos);
    RefillBuffer;
  end;

  leading_zeroes := SkipZero;

  // JSON does not allow leading zeroes
  if (leading_zeroes > 1) or
     (leading_zeroes > 0) and (FLen >= 0) and (FBuf[FPos] in ['0'..'9']) then
    FNumberErr := true;

  if (leading_zeroes > 0) and (FBuf[FPos] = '.') then
  begin
    Inc(FPos);
    RefillBuffer;
    // JSON required digit after decimal point
    if (FLen < 0) or not (FBuf[FPos] in ['0'..'9']) then
      FNumberErr := true;
    exponent := -SkipZero;
    exponent := exponent - ReadDigits;
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
        FNumberErr := true;
      exponent := -ReadDigits;
    end;
  end;

  if FBuf[FPos] in ['e', 'E'] then
  begin
    Inc(FPos);
    RefillBuffer;
    tmp_exp := 0;
    tmp_exp_sign := +1;
    if (FBuf[FPos] in ['-', '+']) then
    begin
      if FBuf[FPos] = '-' then
        tmp_exp_sign := -1;
      Inc(FPos);
      RefillBuffer;
    end;

    SkipZero;

    for i := FPos to FLen do
    begin
      if not (FBuf[FPos] in ['0'..'9']) then
        break;
      // The exponent range for double is from like -324 to +308 or something,
      // we just want to make sure we don't overflow. Everything below or above
      // will be rounded to -INF or +INF anyway.
      if tmp_exp < 10000 then
        tmp_exp := tmp_exp * 10 + (ord(FBuf[FPos]) - ord('0'));

      Inc(FPos);
    end;
    exponent := exponent + tmp_exp_sign * tmp_exp;
  end;

  FNumber := Copy(Buf, 1, n);
  if exponent <> 0 then
    FNumber := FNumber + 'e' + IntToStr(exponent);


  if FNumberErr then
  begin               
    FState := jnError;
    StackPush(jsError);
  end
  {else
    FState := jnNumber; }
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
    '0'..'9', '-', '+': //ParseNumber;
              FToken := jtNumber;
    '"':      FToken := jtString;
    't':
      if MatchString('true') then
        FToken := jtTrue
      else
        FToken := jtError;
    'f':
      if MatchString('false') then
        FToken := jtFalse
      else
        FToken := jtError;
    'n':
      if MatchString('null') then
        FToken := jtNull
      else
        FToken := jtError;
    else
      FToken := jtError;
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
      jsListItem:
      begin
        StackPop;
        StackPush(jsAfterListItem);
      end
      else
        break;
    end;
end;

function TJsonReader.Advance: TJsonState;
begin
  if FSkip then
    SkipEx(false);
  Result := InternalAdvance;
  FSkip := Result in [jnDict, jnKey, jnList, jnNumber, jnString];
end;

function TJsonReader.State: TJsonState;
begin
  Result := FState;
end;

function TJsonReader.InternalAdvance: TJsonState;
label
  start;
begin
  start:

  if (StackTop = jsError) and not FSkipError then
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
      case StackPop of
        jsListItem, jsAfterListItem:
        begin
          FState := jnListEnd;
          break;
        end;
        jsDictItem, jsAfterDictItem:
        begin
          FState := jnDictEnd;
          break;
        end;
        jsInitial:
        begin
          FState := jnEOF;
          StackPush(jsInitial);
          break;
        end;
      end;
    end;
    Result := FState;
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
          StackPush(jsDictItem);
          Inc(FPos);
        end;
        jtList:
        begin
          FState := jnList;
          StackPush(jsListItem);
          Inc(FPos);
        end
        {
        jtNumber:
          FState := jnNumber;
          StackPush(jsNumber);
          // DO NOT Inc(FPos)
        jtString:
          FState := jnString;
          StackPush(jsString);
          Inc(FPos);
        }
        else
        begin
          FState := jnError;
          StackPush(jsError);
        end;
      end;
    jsEOF:
      FState := jnEOF;
    jsListItem: 
      case FToken of
        jtDict:
        begin
          FState := jnDict;
          StackPush(jsDictItem);
          Inc(FPos);
        end;
        jtList:
        begin
          FState := jnList;
          StackPush(jsListItem);
          Inc(FPos);
        end;
        jtNumber:
        begin
          FState := jnNumber;
          StackPush(jsNumber);
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
          Inc(FPos);
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
          StackPush(jsError);
        end;
      end;
    jsDictItem: 
      case FToken of
        jtString:
        begin
          FState := jnKey;
          StackPush(jsDictKey);
          Inc(FPos);
        end;
        jtDictEnd:
        begin
          FState := jnDictEnd;
          Inc(FPos);
          StackPop;
        end
        else
        begin
          FState := jnError;
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
          StackPush(jsError);
        end;
      end;
    jsDictValue: 
      case FToken of
        jtDict:
        begin
          FState := jnDict;
          StackPush(jsDictItem);
          Inc(FPos);
        end;
        jtList:
        begin
          FState := jnList;
          StackPush(jsListItem);
          Inc(FPos);
        end;
        jtNumber:
        begin
          FState := jnNumber;
          StackPush(jsNumber);
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
          Inc(FPos);
        end
        else
        begin
          FState := jnError;
          StackPush(jsError);
        end;
      end;
    jsAfterDictItem:
      case FToken of
        jtComma:
        begin
          StackPop; // AfterDictItem
          //StackPop; // DictItem
          StackPush(jsDictItem);
          Inc(FPos);
          goto start;
        end;
        jtDictEnd:
        begin
          FState := jnDictEnd;
          StackPop; // AfterDictItem
          //StackPop; // DictItem
          Reduce;
          Inc(FPos);
        end
        else
        begin
          FState := jnError;
          StackPush(jsError);
        end;
      end;
    jsNumber:
      SkipNumber;
    jsBoolean:
      SkipBoolean;
    jsString:
      SkipString;
    jsDictKey:
      SkipKey;

    jsError:
    begin
      {if FSkipError then}
        FSkipError := false
      {else
        FPopUntil := 0;   }
    end;

  end;
  Result := FState;
end;

procedure TJsonReader.SkipEx(AutoProceed: Boolean);
begin
  // Consider what happens when an error occurs in an internal structure while
  // skipping an item.
  // In that case, when we return, the internal stack will have more items than
  // the user expects. This will cause errors because the user expects to get
  // the appropriate ListEnd / DictEnd states for the items that were on the
  // stack before Skip was called.
  // We can fix this by removing the internal items from the stack. However,
  // when the user calls Proceed on the error, we want to proceed from where we
  // left off internally, so instead of outright deleting the items here, we
  // back them up into FSavedStack, so that we can restore them in Proceed.

  if High(FStack) < FSkipUntil then
    FSkipUntil := High(FStack);

  repeat
    if InternalAdvance = jnError then
    begin
      if AutoProceed then
        Proceed
      else
      begin
        assert(High(FStack) > FSkipUntil);
        FSavedStack := Copy(FStack, FSkipUntil, Length(FStack) - FSkipUntil);
        SetLength(FStack, FSkipUntil);
        // We cut off jsError from stack, add it back:
        StackPush(jsError);
        FSkipError := True;
        exit;
      end;
    end;
  until (High(FStack) < FSkipUntil);
  FSkipUntil := MaxInt;//-1;
end;



procedure TJsonReader.Skip;
begin
  //SkipEx(false);
  FSkip := true;
end;

procedure TJsonReader.Proceed;
var
  i: integer;
  Needle: TJsonInternalState;
begin
  if FState <> jnError then
    exit;

  FSkipError := false;

  // Restore internal stack if necessary (see comment in SkipEx)
  if Length(FSavedStack) > 0 then
  begin
    SetLength(FStack, FSkipUntil + Length(FSavedStack));
    Move(FSavedStack[0], FStack[FSkipUntil], Length(FSavedStack));
  end;

  // Pop off the jsError state
  StackPop;

  // Skip past garbage tokens
  if FToken = jtError then
  begin
    while FToken = jtError do
    begin
      Inc(FPos);
      GetToken;
    end;
  end;

  // List: missing comma
  if (StackTop = jsAfterListItem) and
     (FToken in [jtDict, jtList, jtNumber, jtTrue, jtFalse, jtNull, jtString]) then
  begin
    StackPop;
    StackPush(jsListItem);
    exit;
  end;

  // Dict: missing comma
  if (StackTop = jsAfterDictItem) {and (FToken = jtString)} then
  begin
    StackPop;
    StackPush(jsDictItem);
    exit;
  end;

  // Dict: missing colon
  if StackTop = jsAfterDictKey then
  begin
    StackPop; // AfterDictKey
    StackPop; // DictItem
    StackPush(jsAfterDictItem);
    exit;
  end;

  // Dict: missing value after colon
  if StackTop = jsDictValue then
  begin  
    StackPop; // DictValue
    StackPop; // DictItem
    StackPush(jsAfterDictItem);
    exit;
  end;

  // Dict: Expected key, but got something else
  if (StackTop = jsDictItem) and (FToken in [jtDict, jtList, jtNumber, jtTrue, jtFalse, jtNull]) then
  begin
    StackPush(jsDictValue);
    SkipEx(true);
    exit;
  end;

  // List closed, but node is not a list or
  // Dict closed, but node is not a dict
  if ((FToken = jtListEnd) and not (StackTop in [jsListItem, jsAfterListItem])) or
     ((FToken = jtDictEnd) and not (StackTop in [jsDictItem, jsAfterDictItem])) then
  begin
    case FToken of
      jtListEnd: Needle := jsListItem;
      jtDictEnd: Needle := jsDictItem;
      else       assert(false);
    end;

    // Check if there is a list further up the stack
    // TODO: This is O(stack depth), therefore a potential performance bottle-
    // neck. It could be implemented in O(1).
    i := High(FStack);
    while (i >= 0) and (FStack[i] <> Needle) do
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
    //StackPop;
    //Reduce;
    FState := jnNumber;
    exit;
  end;

  // If we could not fix the error, push the error state back on
  // TODO: Close stack
  StackPush(jsError);
end;

function TJsonReader.LastError: integer;
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
begin
  o0 := 0;

  while true do
  begin
    i0 := FPos;
    i1 := i0;
    o1 := o0;
    l  := Flen;

    while (i1 < l) and (o1 < BufSize) and not (FBuf[i1] in ['\', '"']) do
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
      break;
    end;

    if FPos >= FLen then
    begin
      RefillBuffer;
      continue;
    end;

    if FBuf[FPos] = '"' then
    begin
      // End of string
      //inc(FPos);
      //StackPop;
      //Reduce;
      break;
    end
    else if FBuf[FPos] = '\' then
    begin
      Inc(FPos);
      RefillBuffer;
      if FLen = 0 then
      begin
        // EOF Before string end
        FState := jnError;
        break;
      end;

      // TODO: Handle \xAB escape codes

      PChar(SizeInt(@Buf) + o1)^ := FBuf[FPos];
      Inc(FPos);
      inc(o1);
    end;
  end;

  Result := o1;

  if (Result = 0) and (StackTop <> jsError) then
  begin
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

  //StackPop;
  //Reduce;
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
  Advance;
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
    Advance;
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

function TJsonReader.InitNumber: Boolean;
begin
  if (FState <> jnNumber) or (FToken <> jtNumber) then
  begin
    Result := False;
    exit;
  end;

  if FNumber = '' then
    ParseNumber;

  Result := FState = jnNumber;
end;

procedure TJsonReader.FinalizeNumber;
begin
  FNumber := '';
  FSkip  := false;
  StackPop;
  Reduce;
end;

function TJsonReader.Number(out num: integer): Boolean;
begin
  Result := InitNumber and TryStrToInt(FNumber, num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out num: int64): Boolean;
begin
  Result := InitNumber and TryStrToInt64(FNumber, num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out num: uint64): Boolean;
begin
  Result := InitNumber and TryStrToUInt64(FNumber, num);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Number(out num: double): Boolean;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings.DecimalSeparator := '.';
  FormatSettings.ThousandSeparator := #0;

  Result := InitNumber and TryStrToFloat(FNumber, num, FormatSettings);

  if Result then
    FinalizeNumber;
end;

function TJsonReader.Bool(out bool: Boolean): Boolean;
begin
  if FState <> jnBoolean then
  begin
    Result := false;
    exit;
  end;

  case FToken of
    jtTrue:  bool := true;
    jtFalse: bool := false;
    else     assert(false);
  end;

  StackPop;
  Reduce;

  Result := true;
end;

function TJsonReader.Null: Boolean;
begin
  if FState <> jnNull then
  begin
    Result := false;
    exit;
  end;

  StackPop;
  Reduce;

  Result := true;
end;

function TJsonReader.Dict: Boolean;
begin
  if FState <> jnDict then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  FSkip  := false;
end;

function TJsonReader.List: Boolean;
begin
  if FState <> jnList then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  FSkip  := false;
end;

function TJsonReader.Error: Boolean;
begin
  Result := FState = jnError;
end;

end.
