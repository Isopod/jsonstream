# JsonStream Pascal Implementation

## Files

| File                               | Description                                     |
|------------------------------------|-------------------------------------------------|
| [example](example)                 | Examples showing how to use the library         |
| [package](package)                 | Contains a Lazarus package file                 |
| [test](test)                       | Automated tests                                 |
| [jsonstream.pas](jsonstream.pas)   | Contains the entire source code of the library. |

## How to use

To use JsonStream in your project, you can either copy `jsonstream.pas` into
your project folder directly, or you can add the provided Lazarus package as a
dependency.

This implementation was tested under FreePascal 3.2.2. If you are using a
different compiler and have trouble getting the source code to build, please
open an issue.  Pull Requests are welcome.

## Reference

### TJsonString (type)

Alias for `string`.

### TJsonFeature (enum)

| Value      | Meaning                                                         |
|------------|-----------------------------------------------------------------|
| jsJson5    | Enable JSON5 features.                                          |

### TJsonFeatures (set)

Set of `TJsonFeature`.

### TJsonState (enum)

Describes the state of a `TJsonReader`.

| Value      | Meaning                                                         |
|------------|-----------------------------------------------------------------|
| jsError    | Parser encountered a syntax error                               |
| jsEOF      | End of the file has been reached                                |
| jsDict     | Current element is the beginning of a dict ({)                  | 
| jsDictEnd  | Current element is the end of a dict (})                        |
| jsList     | Current element is the beginning of a list ([)                  |
| jsListEnd  | Current element is the end of a list (])                        |
| jsNumber   | Current element is a number                                     |
| jsBoolean  | Current element is a boolean                                    |
| jsNull     | Current element is a null value                                 |
| jsString   | Current element is a string                                     |
| jsKey      | Current element is the key of a dict entry                      |

### TJsonError (enum)

Gives additional information about an error.

| Value                    | Meaning                                                                |
|--------------------------|------------------------------------------------------------------------|
| jeNoError = 0            | There is no error                                                      |
| jeInvalidToken           | Got a character sequence that is not a valid JSON token.               |
| jeInvalidNumber          | Token was recognized as a number, but does not conform to JSON syntax. |
| jeUnexpectedToken        | Token is a valid JSON token, but there is a syntax error.              |
| jeTrailingComma          | A list or dict contains a trailing comma.                              |
| jeUnexpectedEOF          | End of file was unexpectedly encountered.                              |
| jeInvalidEscapeSequence  | There was an invalid escape sequence in a string, or a character that must be escaped was not escaped. |
| jeNestingTooDeep         | The maximum nesting limit set by the user was reached.                 |


### TJsonReader (class)

This class is used for parsing JSON markup.

<dl>

<dt>constructor TJsonReader.Create(Stream: TStream; Features: TJsonFeatures=[]; MaxNestingDepth: integer=MaxInt)
<dd>Construct a <code>TJsonReader</code> object. The input will be read from
<code>Stream</code>.  Pass <code>[jfJson5]</code> as Features to create a JSON5
parser instead of a regular JSON parser. You can specify a maximum allowable
nesting depth via <code>MaxNestingDepth</code>. If this depth is exceeded, the
parser will abort.

<dt>function TJsonReader.Advance: TJsonState
<dd>Move to the next element and return the new parse state.

<dt>function TJsonReader.State: TJsonState
<dd>Return the current parse state.

<dt>function TJsonReader.Key(out K: TJsonString): Boolean;
<dd>Returns <code>true</code> iff the current element is a dict entry and stores
its key in <code>K</code>. If <code>true</code> is returned, then the key is
stored in <code>K</code> and the reader is automatically advanced to the
corresponding value.  If <code>false</code> is returned, the current element is
either not a key or an error ocurred during decoding (such as an invalid escape
sequence or premature end of file) and the contents of <code>K</code>
are undefined.  If an error occured, you may call <code>Proceed()</code> to
ignore it and call <code>Key()</code> again.

<dt>function  TJsonReader.KeyBuf(out Buf; BufSize: SizeInt): SizeInt;
<dd>This function is like <code>Key</code>, except that it does not return the
full key, but only reads part of it. This is intended for situations where the
key could be very large and it would not be efficient to allocate it in memory
its entirety. The semantics are the same as the <code>read()</code> syscall on
Unix: Up to <code>BufSize</code> bytes are read and stored in <code>Buf</code>.

<p>Return value:

<ul>
<li> &gt; 0: The number of bytes actually read.
<li> = 0: Indicates the end of the key.
<li> &lt; 0: An error occurred (invalid escape sequence or missing trailing ")
          or the value is not a key.
</ul>

If an error occurred, you can call <code>Proceed()</code> to ignore it and try
to continue reading.

<dt>function  TJsonReader.Str(out S: TJsonString): Boolean;
<dd>Returns <code>true</code> iff the current element is a valid string value.
If <code>true</code> is returned, then the decoded string value is stored in
<code>S</code>.  If <code>false</code> is returned, the current element is
either not a string or an error occurred during decoding (such as an invalid
escape sequence or premature end of file) and the contents of
<code>S</code> are undefined.  If an error occurred, you may call
<code>Proceed()</code> to ignore it and call <code>Str()</code> again. This
function only returns <code>true</code> once per element.

<dt>function  TJsonReader.StrBuf(out Buf; BufSize: SizeInt): SizeInt;
<dd> This function is like <code>Str</code>, except that it does not return the
full string, but only reads part of it. This is intended for situations where
the string could be very large and it would not be efficient to allocate it in
memory in its entirety. The semantics are the same as the <code>read()</code>
syscall on Unix: Up to <code>BufSize</code> bytes are read and stored in
<code>Buf</code>.  

<p>Return value:

<ul>
<li> &gt; 0: The number of bytes actually read.
<li> = 0: Indicates the end of the string.  
<li> &lt; 0: An error occurred (invalid escape sequence or missing trailing ")
or the value is not a string.  
</ul>

If an error occurred, you can call <code>Proceed()</code> to ignore it and try
to continue reading.

<dt>function  TJsonReader.Number(out Num: integer): Boolean; overload;
<dd>Returns <code>true</code> iff the current element is a number that can be
exactly represented by an integer and returns its value in <code>Num</code>.
This function only returns <code>true</code> once per element.

<dt>function  TJsonReader.Number(out Num: int64): Boolean; overload;
<dd>Returns <code>true</code> iff the current element is a number that can be
exactly represented by an int64 and returns its value in <code>Num</code>. This
function only returns <code>true</code> once per element.
<dt>function  TJsonReader.Number(out Num: uint64): Boolean; overload;
<dd>Returns <code>true</code> iff the current element is a number that can be
exactly represented by an uint64 and returns its value in <code>Num</code>. This
function only returns <code>true</code> once per element.

<dt>function  TJsonReader.Number(out Num: double): Boolean; overload;
<dd>Returns <code>true</code> iff the current element is a number and returns its
value in <code>Num</code>. If the number exceeds the representable precision or
range of a double precision float, it will be rounded to the closest
approximation. This function only returns <code>true</code> once per element.

<dt>function  TJsonReader.Bool(out Bool: Boolean): Boolean;
<dd>Returns <code>true</code> iff the current element is a boolean and returns
its value in bool. This function only returns <code>true</code> once per
element.

<dt>function  TJsonReader.Null: Boolean;
<dd>Returns <code>true</code> iff the current element is a null value. This
function only returns <code>true</code> once per element.

<dt>function  TJsonReader.Dict: Boolean;
<dd>Returns <code>true</code> iff the current element is a dict. If
<code>true</code> is returned, then the next element will be the first child of
the dict.

<dt>function  TJsonReader.List: Boolean;
<dd>Returns <code>true</code> iff the current element is a list. If
<code>true</code> is returned, then the next element will be the first child of
the list.

<dt>function  TJsonReader.Error: Boolean;
<dd>Returns <code>true</code> if the last operation resulted in an error. You
can then check the <code>LastError</code> and <code>LastErrorMessage</code>
functions to learn more about the error. You can call <code>Proceed</code> to
try to recover from the error and continue parsing. Otherwise no further tokens
will be consumed and all open elements  will be closed.

<dt>function  TJsonReader.Proceed: Boolean;
<dd>Proceed after a parse error. If this is <em>not</em> called after an error,
parsing is aborted and no further tokens in the file will be processed.

<dt>function  TJsonReader.LastError: TJsonError;
<dd>Return last error code. A return value of 0 means that there was no
error. A return value other than 0 indicates that there was an error.

<dt>function  TJsonReader.LastErrorMessage: TJsonString;
<dd>Return error message for last error.

<dt>function  TJsonReader.LastErrorPosition: SizeInt;
<dd>Byte offset of the last error.

</dl>


### TJsonWriter (class)

This class is used for writing JSON output.

<dl>
<dt>constructor TJsonWriter.Create(Stream: TStream; Features: TJsonFeatures=[]; PrettyPrint: Boolean=false; const Indentation: string='  ');
<dd>Construct a <code>TJsonWriter</code> object. Pass <code>[jfJson5]</code> as
<code>Features</code> to enable JSON5 features. Pass <code>true</code> as
<code>PrettyPrint</code> to produce formatted, human-readable output.
Pretty-printed output is by default indented with two spaces. Pass a string to
<code>Indentation</code> to change the characters used for indenting.

<dt>procedure TJsonWriter.Key(const K: TJsonString);
<dd>Append a key to the output. May only be used inside a dict. Must be followed
by a value.

<dt>procedure TJsonWriter.KeyBuf(const Buf; BufSize: SizeInt);
<dd>Streaming equivalent of the <code>Key()</code> method. See
<code>StrBuf()</code>.

<dt>procedure TJsonWriter.Str(const S: TJsonString);
<dd>Append a string to the output.

<dt>procedure TJsonWriter.StrBuf(const Buf; BufSize: SizeInt);
<dd>Streaming equivalent of the <code>Str()</code> method. To indicate the end
of the string, call once with <code>BufSize</code> set to <code>0</code>.

<p>Note: To write an empty string, you have to call the method twice:
<pre>
StrBuf(..., 0); // Write 0 bytes
StrBuf(..., 0); // Signal end of string
</pre>

<dt>procedure TJsonWriter.Number(Num: integer); overload;<br>
procedure TJsonWriter.Number(Num: int64); overload;<br>
procedure TJsonWriter.Number(Num: uint64); overload;<br>
procedure TJsonWriter.Number(Num: double); overload;
<dd>Append a number to the output. Note: The values <code>NaN</code> and
<code>Infinity</code> are only allowed in JSON5 mode.

<dt>procedure TJsonWriter.NumberHex(Num: uint64); overload;
<dd>Append a number in hexadecimal format, if possible. This requires
<code>jfJson5</code> to be included in <code>Features</code>. If
<code>jfJson5</code> is not included in <code>Features</code>, a decimal number
will be written, instead.

<dt>procedure TJsonWriter.Bool(Bool: Boolean);
<dd>Append a boolean.

<dt>procedure TJsonWriter.Null;
<dd>Append a <code>null</code> value.

<dt>procedure TJsonWriter.Dict;
<dd>Begin writing a dict.

<dt>procedure TJsonWriter.DictEnd;
<dd>Stop writing a dict.

<dt>procedure TJsonWriter.List;
<dd>Begin writing a list.

<dt>procedure TJsonWriter.ListEnd;
<dd>Stop writing a list.
</dl>
