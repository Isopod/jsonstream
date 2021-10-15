program addressbook;

uses
  sysutils, classes, contnrs, jsonstream;

type

  TPhoneNumber = class
    Number:             String;
    Role:               String;
  end;

  TContact = class
    FirstName:          String;
    MiddleName:         String;
    LastName:           String;
    PhoneNumbers:       TObjectList;
    Birthday:           TDate;
    BirthdaySet:        Boolean;

    constructor Create;
    destructor Destroy; override;
  end;

  TAddressBook = class
    Contacts:           TObjectList;
    Modified:           Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  { EMarkupError }

  EMarkupError = class(Exception)
    constructor Create;
  end;

constructor TContact.Create;
begin
  PhoneNumbers := TObjectList.Create(true);
end;

destructor TContact.Destroy;
begin
  FreeAndNil(PhoneNumbers);
  inherited Destroy;
end;

constructor TAddressBook.Create;
begin
  Contacts := TObjectList.Create;
end;

destructor TAddressBook.Destroy;
begin
  Contacts.Free;
  inherited Destroy;
end;

{ EMarkupError }

constructor EMarkupError.Create;
begin
  inherited Create('Markup contains error.');
end;
                
// Serialization / Deserialization ---------------------------------------------

// Helper

function DeserializeStr(Reader: TJsonReader): String;
begin
  if not Reader.Str(Result) then
    raise EMarkupError.Create;
end;

function DeserializeDate(Reader: TJsonReader): TDate;
begin
  if not Reader.Number(Result) then
    raise EMarkupError.Create;
end;

// PhoneNumber
                        
procedure SerializePhoneNumber(Number: TPhoneNumber; Writer: TJsonWriter);
begin
  Writer.Dict;

  Writer.Key('Number');
  Writer.Str(Number.Number);

  Writer.Key('Role');
  Writer.Str(Number.Role);

  Writer.DictEnd;
end;

function DeserializePhoneNumber(Reader: TJsonReader): TPhoneNumber;
var
  Key: String;
begin
  Result := TPhoneNumber.Create;

  if not Reader.Dict then
    raise EMarkupError.Create;

  while Reader.Advance <> jsDictEnd do
  begin
    if not Reader.Key(Key) then
      raise EMarkupError.Create;

    if Key = 'Number' then
      Result.Number := DeserializeStr(Reader)
    else if Key = 'Role' then
      Result.Role := DeserializeStr(Reader);
  end;
end;

// Contact

procedure SerializeContact(Contact: TContact; Writer: TJsonWriter);
var
  i: Integer;
begin
  Writer.Dict;

  Writer.Key('FirstName');
  Writer.Str(Contact.FirstName);

  Writer.Key('MiddleName');
  Writer.Str(Contact.MiddleName);

  Writer.Key('LastName');
  Writer.Str(Contact.LastName);

  Writer.Key('PhoneNumbers');
  Writer.List;
  for i := 0 to Contact.PhoneNumbers.Count - 1 do
    SerializePhoneNumber(TPhoneNumber(Contact.PhoneNumbers[i]), Writer);
  Writer.ListEnd;

  Writer.Key('Birthday');
  if Contact.BirthdaySet then
    Writer.Number(Contact.Birthday)
  else
    Writer.Null;

  Writer.DictEnd;
end;    

function DeserializeContact(Reader: TJsonReader): TContact;
var
  Key: String;
begin
  Result := TContact.Create;

  if not Reader.Dict then
    raise EMarkupError.Create;

  while Reader.Advance <> jsDictEnd do
  begin
    if not Reader.Key(Key) then
      raise EMarkupError.Create;

    if Key = 'FirstName' then
      Result.FirstName := DeserializeStr(Reader)
    else if Key = 'MiddleName' then
      Result.MiddleName := DeserializeStr(Reader)
    else if Key = 'LastName' then
      Result.LastName := DeserializeStr(Reader)
    else if (Key = 'PhoneNumbers') and Reader.List then
      while Reader.Advance <> jsListEnd do
        Result.PhoneNumbers.Add(DeserializePhoneNumber(Reader))
    else if (Key = 'Birthday') and not Reader.Null then
    begin
      Result.BirthdaySet := true;
      Result.Birthday := DeserializeDate(Reader);
    end;
  end;
end;

// Address Book

procedure SerializeAddressBook(AddressBook: TAddressBook; Writer: TJsonWriter);
var
  i: Integer;
begin
  Writer.Dict;

  Writer.Key('Contacts');
  Writer.List;
  for i := 0 to AddressBook.Contacts.Count - 1 do
    SerializeContact(TContact(AddressBook.Contacts[i]), Writer);
  Writer.ListEnd;

  Writer.DictEnd;
end;

function DeserializeAddressBook(Reader: TJsonReader): TAddressBook;
var
  Key: String;
begin
  Result := TAddressBook.Create;

  if not Reader.Dict then
    raise EMarkupError.Create;

  while Reader.Advance <> jsDictEnd do
  begin
    if not Reader.Key(Key) then
      raise EMarkupError.Create;
    if (Key = 'Contacts') and Reader.List then
      while Reader.Advance <> jsListEnd do
        Result.Contacts.Add(DeserializeContact(Reader));
  end;
end;

// Console interface------------------------------------------------------------

function QueryYesNo(Question: String): Boolean;
var
  s: String;
begin
  repeat
    WriteLn(Question, ' (y/n)');
    ReadLn(s);
  until (s = 'y') or (s = 'n');
  Result := s = 'y';
end;

function QueryString(Message: String; Default: String=''): String;
begin
  Write(Message);
  if Default <> '' then
    Write(' [default=', Default, ']');
  WriteLn;
  ReadLn(Result);
  if Result = '' then
    Result := Default;
end;

procedure ListAddressBook(AddressBook: TAddressBook);
var
  i: integer;
  Contact: TContact;
begin
  for i := 0 to AddressBook.Contacts.Count - 1 do
  begin
    Contact := TContact(AddressBook.Contacts[i]);
    WriteLn(i + 1, '. ', Contact.FirstName, ' ', Contact.MiddleName, ' ', Contact.LastName);
  end;
end;

procedure ListContact(Contact: TContact);
var
  i:           Integer;
  PhoneNumber: TPhoneNumber;
begin
  WriteLn('First Name:  ', Contact.FirstName);
  WriteLn('Middle Name: ', Contact.MiddleName);
  WriteLn('Last Name:   ', Contact.LastName);
  Write  ('Phone:       ');
  for i := 0 to Contact.PhoneNumbers.Count - 1 do
  begin
    PhoneNumber := TPhoneNumber(Contact.PhoneNumbers[i]);
    if i <> 0 then
      Write('             ');
    WriteLn(PhoneNumber.Number, ' (', PhoneNumber.Role, ')');
  end;
  if Contact.PhoneNumbers.Count = 0 then
    WriteLn;

  if Contact.BirthdaySet then
    WriteLn('Birthday:    ', DateToStr(Contact.Birthday));
end;

procedure AddContact(AddressBook: TAddressBook);
var
  Contact: TContact;
  Number:  TPhoneNumber;
  s:       String;
begin
  Contact := TContact.Create;

  Contact.FirstName  := QueryString('Enter first name:');
  Contact.MiddleName := QueryString('Enter middle name:');
  Contact.LastName   := QueryString('Enter last name:');

  while QueryYesNo('Add phone number?') do
  begin
    Number           := TPhoneNumber.Create;
    Number.Number    := QueryString('Enter phone number:');
    Number.Role      := QueryString('Enter description for this number (e.g. Home/Work/Mobile):', 'Home');
    Contact.PhoneNumbers.Add(Number);
  end;

  while true do
  begin
    s := QueryString('Enter Birthday (dd.mm.yyyy): [leave blank to skip]');
    if s = '' then
      break;

    if not TryStrToDate(s, Contact.Birthday) then
      continue;
    Contact.BirthdaySet := True;
    break;
  end;

  AddressBook.Contacts.Add(Contact);
  AddressBook.Modified := true;
end;

procedure DeleteContact(AddressBook: TAddressBook; Contact: TContact);
begin                                  
  WriteLn('Deleted contact "', Contact.FirstName, ' ', Contact.MiddleName, ' ', Contact.LastName, '".');
  AddressBook.Contacts.Remove(Contact);    
  AddressBook.Modified := true;
end;

function LoadFromFile(FileName: string): TAddressBook;
var
  Stream: TStream;
  Reader: TJsonReader;
begin
  try
    Stream := nil;
    Reader := nil;
    try
      Stream := TFileStream.Create(FileName, fmOpenRead);
      Reader := TJsonReader.Create(Stream);
      Result := DeserializeAddressBook(Reader);
    except
      Result := TAddressBook.Create;
    end;

  finally
    Reader.Free;
    Stream.Free;
  end;
end;

procedure SaveToFile(AddressBook: TAddressBook; FileName: String);
var
  Stream: TStream;
  Writer: TJsonWriter;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  Writer := TJsonWriter.Create(Stream,[],true);
  SerializeAddressBook(AddressBook, Writer);
  AddressBook.Modified := false;
  Writer.Free;
  Stream.Free;
end;
          
function CommandWithIndex(Input: String; const Command: String; out Index: Integer): Boolean;
begin
  Result :=
    (Copy(Input, 1, Length(Command)) = Command) and
    TryStrToInt(Copy(Input, Length(Command) + 1, MaxInt), Index);
end;

procedure Main;
var
  AddressBook: TAddressBook;
  Command:     String;
  Index:       Integer;
begin
  FormatSettings.DateSeparator   := '.';
  FormatSettings.ShortDateFormat := 'dd.mm.yyyy';
  FormatSettings.LongDateFormat  := 'dd.mm.yyyy';

  AddressBook := LoadFromFile('addressbook.json');

  while true do
  begin
    WriteLn('Enter a command (h for help):');
    ReadLn(Command);
    WriteLn;
    if Command = 'a' then
      AddContact(AddressBook)
    else if Command = 'l' then
      ListAddressBook(AddressBook)
    else if CommandWithIndex(Command, 'l', Index) then
    begin
      if (Index > 0) and (Index <= AddressBook.Contacts.Count) then
        ListContact(TContact(AddressBook.Contacts[Index-1]));
    end
    else if CommandWithIndex(Command, 'd', Index) then
    begin
      if (Index > 0) and (Index <= AddressBook.Contacts.Count) then
        DeleteContact(AddressBook, TContact(AddressBook.Contacts[Index-1]));
    end
    else if Command = 's' then
    begin
      SaveToFile(AddressBook, 'addressbook.json');
      WriteLn('Saved.');
    end
    else if Command = 'q' then
    begin
      if AddressBook.Modified then
      begin
        WriteLn('There are unsaved changes! Do you really want to quit without saving? (y/n)');
        ReadLn(Command);
        if Command <> 'y' then
          continue;
      end;
      exit;
    end
    else {if Command = 'h' then}
    begin
      WriteLn('Available commands:');
      WriteLn('a Add a contact');
      WriteLn('l List contacts');
      WriteLn('l <n> Show details of contact <n>');
      WriteLn('d <n> Delete contact <n>');
      WriteLn('s Save changes');
      WriteLn('q Quit');
    end;  
    WriteLn;
  end;
end;

begin
  Main;
end.

