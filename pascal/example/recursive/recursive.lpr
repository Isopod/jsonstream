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

program recursive;

// This example loads a nested JSON structure from a file and constructs an
// in-memory representation. The resulting structure is then traversed and
// dumped to the console.
// Memory management has been omitted for brevity. Error handling is kept very
// basic.

uses
  Classes, Contnrs, jsonstream;

// Data types

type
  TRegion = class
  public
    Name:       String;
    Population: Int64;
    Children:   TObjectList;
  end;

// Parse routines

function ParseRegion(Reader: TJsonReader): TRegion; forward;

function ParseRegions(Reader: TJsonReader): TObjectList;
begin
  if not Reader.List then
    exit(nil);

  Result := TObjectList.Create;
  while Reader.Advance <> jsListEnd do
    Result.Add(ParseRegion(Reader));
end;

function ParseRegion(Reader: TJsonReader): TRegion;
var
  Key: String;
begin
  if not Reader.Dict then
    exit(nil);

  Result := TRegion.Create;
  while Reader.Advance <> jsDictEnd do
  begin
    if not Reader.Key(Key) then
      continue;

    if Key = 'name' then
      Reader.Str(Result.Name)
    else if Key = 'population' then
      Reader.Number(Result.Population)
    else if Key = 'children' then
      Result.Children := ParseRegions(Reader);
  end;
end;

// Output

procedure Dump(Region: TRegion; level:string='');
var
  i: integer;
begin
  WriteLn(level,'Region: ', Region.Name, ' Population: ', Region.Population);
  if Region.Children <> nil then
    for i := 0 to Region.Children.Count - 1 do
      Dump(TRegion(Region.Children[i]), level + '  ');
end;

var
  Root: TRegion;
  Stream: TStream;
  Reader: TJsonReader;
begin
  Stream := TFileStream.Create('regions.json', fmOpenRead);
  Reader := TJsonReader.Create(Stream);

  Root := ParseRegion(Reader);

  if Reader.LastError <> jeNoError then
    WriteLn('Parse error: ' + Reader.LastErrorMessage)
  else
    Dump(Root);
end.

