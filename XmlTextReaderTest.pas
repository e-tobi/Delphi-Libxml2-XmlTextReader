{
  LibXml2-XmlTextReader wrapper class for Delphi

  Copyright (c) 2010 Tobias Grimm

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
}

unit XmlTextReaderTest;

interface

uses
  libxml2,
  XmlTextReader,
  TestFrameWork,
  Classes,
  Windows,
  SysUtils;

type
  TXmlTextReaderTest = class(TTestCase)
  private
    FXmlTextReader: TXmlTextReader;
    FDataStream: TStringStream;
  private
    procedure SetXmlData(const Data: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCreateFromStream;
    procedure TestCreateFromNonExistingFile;
    procedure TestCreateFromFile;
    procedure TestMultipleThreads;
    procedure TestReset;
    procedure TestRead;
    procedure TestReadOuterXml;
    procedure TestReadInnerXml;
    procedure TestSkip;
    procedure TestReadString;
    procedure TestReadInvalidXml;
    procedure TestReadInvalidXmlFile;
    procedure TestNodeType;
    procedure TestAttributeProperties;
    procedure TestElementProperties;
    procedure TestNameSpaceProperties;
    procedure TestGetAttributeMethods;
    procedure TestMoveMethods;
    procedure TestLookupNamespace;
    procedure TestParserProp;
    procedure TestReadmeSample;
  end;

  TTestThread = class(TThread)
  private
    FFileName: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const fileName: string); virtual;
  end;

implementation

{ TXmlreaderTest }

procedure TXmlTextReaderTest.SetUp;
begin
  inherited;
  FDataStream := TStringStream.Create('');
  FXmlTextReader := TXmlTextReader.Create(FDataStream);
end;

procedure TXmlTextReaderTest.SetXmlData(const Data: string);
begin
  FDataStream.Size := 0;
  FDataStream.WriteString(Data);
  FDataStream.Seek(0, soFromBeginning);
  FXmlTextReader.Reset;
end;

procedure TXmlTextReaderTest.TearDown;
begin
  FXmlTextReader.Free;
  FDataStream.Free;
  inherited;
end;

procedure TXmlTextReaderTest.TestCreateFromStream;
begin
  try
    TXmlTextReader.Create(nil).Free;
    Fail('Expected EArgumentNullException');
  except
    on E: EArgumentNullException do
      ;
  end;

  TXmlTextReader.Create(FDataStream).Free;
  Check(True, 'Construction from stream');
end;

procedure TXmlTextReaderTest.TestElementProperties;
begin
  SetXmlData('<?xml version="1.0"?>' + '<root>' + '<first>' + 'value' +
      '<empty/>' + '</first>' + '</root>');

  FXmlTextReader.Read;
  CheckEquals('root', FXmlTextReader.Name, 'Name property');
  CheckEquals(0, FXmlTextReader.Depth, 'property Depth');
  Check(not FXmlTextReader.HasValue, 'property HasValue');
  Check(not FXmlTextReader.IsEmptyElement, 'property IsEmptyElement');

  FXmlTextReader.Read;
  CheckEquals('first', FXmlTextReader.Name, 'Name property');
  CheckEquals(1, FXmlTextReader.Depth, 'property Depth');
  Check(not FXmlTextReader.HasValue, 'property HasValue');
  Check(not FXmlTextReader.IsEmptyElement, 'property IsEmptyElement');

  FXmlTextReader.Read;
  CheckEquals('#text', FXmlTextReader.Name, 'Name property');
  Check(FXmlTextReader.HasValue, 'property HasValue');
  CheckEquals('value', FXmlTextReader.Value, 'property Value');
  Check(not FXmlTextReader.IsEmptyElement, 'property IsEmptyElement');

  FXmlTextReader.Read;
  Check(FXmlTextReader.IsEmptyElement, 'property IsEmptyElement');
end;

procedure TXmlTextReaderTest.TestNameSpaceProperties;
begin
  SetXmlData('<?xml version="1.0"?>' +
      '<root xmlns:test="http://e-tobi.net">' + '<test:node/>' + '</root>');

  FXmlTextReader.Read;
  FXmlTextReader.Read;
  CheckEquals('test', FXmlTextReader.Prefix, 'Prefix property');
  CheckEquals('test:node', FXmlTextReader.Name, 'Name property');
  CheckEquals('node', FXmlTextReader.LocalName, 'LocalName property');
  CheckEquals('test', FXmlTextReader.Prefix, 'Prefix property');
  CheckEquals('http://e-tobi.net', FXmlTextReader.NameSpaceUri,
    'NameSpaceUri property');
end;

procedure TXmlTextReaderTest.TestAttributeProperties;
begin
  SetXmlData('<?xml version="1.0"?>' + '<root>' + '<first a1="1" a2="2"/>' +
      '</root>');

  while FXmlTextReader.Read and (FXmlTextReader.Name <> 'root') do
    ;

  CheckEquals(0, FXmlTextReader.AttributeCount, 'property AttributeCount');
  Check(not FXmlTextReader.HasAttributes, 'property HasAttributes');

  FXmlTextReader.Read;

  CheckEquals(2, FXmlTextReader.AttributeCount, 'property AttributeCount');
  Check(FXmlTextReader.HasAttributes, 'property HasAttributes');
end;

procedure TXmlTextReaderTest.TestReadInvalidXml;
begin
  // document = ''
  try
    FXmlTextReader.Read;
    Fail('Expected EXmlException');
  except
    on E: EXmlException do
      ;
  end;

  // document = invalid
  SetXmlData('<?xml version="1.0"?><x></y>');
  try
    FXmlTextReader.Read; // reads <x>
    FXmlTextReader.Read; // reads </y>
    Fail('Expected EXmlException');
  except
    on E: EXmlException do
      ;
  end;
end;

procedure TXmlTextReaderTest.TestReset;
begin
  SetXmlData('<?xml version="1.0"?><first_doc/>');
  // reset called within SetXmlData
  FXmlTextReader.Read;
  CheckEquals('first_doc', FXmlTextReader.Name, 'Reading first doc');

  SetXmlData('<?xml version="1.0"?><second_doc/>');
  // reset called within SetXmlData
  FXmlTextReader.Read;
  CheckEquals('second_doc', FXmlTextReader.Name,
    'Reading second doc with same XmlTextReader');
end;

procedure TXmlTextReaderTest.TestGetAttributeMethods;
begin
  SetXmlData('<?xml version="1.0"?>' +
      '<root xmlns:test="http://e-tobi.net">'
      + '<first a="1" b="2" test:a="3"/>' +
      '</root>');

  FXmlTextReader.Read;
  FXmlTextReader.Read;
  CheckEquals('1', FXmlTextReader.GetAttribute('a'), 'attribute by name');
  CheckEquals('2', FXmlTextReader.GetAttribute('b'), 'attribute by name');
  CheckEquals('1', FXmlTextReader.GetAttribute(0), 'attribute by number');
  CheckEquals('2', FXmlTextReader.GetAttribute(1), 'attribute by number');
  CheckEquals('3', FXmlTextReader.GetAttribute('a', 'http://e-tobi.net'),
    'attribute by namespace');
end;

procedure TXmlTextReaderTest.TestMoveMethods;
begin
  SetXmlData('<?xml version="1.0"?>' +
      '<root xmlns:test="http://e-tobi.net" a="2" test:a="3">' + '<first/>' +
      '</root>');

  FXmlTextReader.Read;

  Check(not FXmlTextReader.MoveToAttribute('x'),
    'move to non existing attribute by name returned true');
  Check(FXmlTextReader.MoveToAttribute('a'),
    'move to attribute returned false');
  CheckEquals('2', FXmlTextReader.Value, 'moved to wrong attribute by name');

  Check(not FXmlTextReader.MoveToAttribute('x', 'http://e-tobi.net'),
    'move to non existing attribute by namespace returned true');
  Check(not FXmlTextReader.MoveToAttribute('a', 'http://foo'),
    'move to attribute by non existing namespace returned true');
  Check(FXmlTextReader.MoveToAttribute('a', 'http://e-tobi.net'),
    'move to attribute returned false');
  CheckEquals('3', FXmlTextReader.Value,
    'moved to wrong attribute by namespac');

  try
    FXmlTextReader.MoveToAttribute(4);
    Fail('Expected EArgumentOutOfRangeException');
  except
    on E: EArgumentOutOfRangeException do
      ;
  end;

  FXmlTextReader.MoveToAttribute(1);
  CheckEquals('2', FXmlTextReader.Value, 'moved to wrong attribute by number');

  Check(FXmlTextReader.MoveToFirstAttribute, 'moved to first attribute failed');
  CheckEquals('http://e-tobi.net', FXmlTextReader.Value,
    'moved not to first attribute');

  Check(FXmlTextReader.MoveToNextAttribute, 'moved to next attribute failed');
  CheckEquals('2', FXmlTextReader.Value, 'moved not to next attribute');

  Check(FXmlTextReader.MoveToNextAttribute, 'moved to next attribute failed');
  CheckEquals('3', FXmlTextReader.Value, 'moved not to next attribute');

  Check(not FXmlTextReader.MoveToNextAttribute,
    'moved to last + 1 attribute returned true');

  Check(FXmlTextReader.MoveToElement, 'move from attribute to element failed');
  CheckEquals('root', FXmlTextReader.Name, 'moved back - wrong element');
  Check(not FXmlTextReader.MoveToElement,
    'move from attribute to element should fail');

  FXmlTextReader.Read;
  Check(not FXmlTextReader.MoveToFirstAttribute,
    'moved to first attribute, where no attribute exists');
end;

procedure TXmlTextReaderTest.TestLookupNamespace;
begin
  SetXmlData('<?xml version="1.0"?>' +
      '<root xmlns:ns1="http://e-tobi.net" xmlns:ns2="foo"/>');

  FXmlTextReader.Read;
  CheckEquals('http://e-tobi.net', FXmlTextReader.LookupNamespace('ns1'),
    'wrong namespace returned');
  CheckEquals('foo', FXmlTextReader.LookupNamespace('ns2'),
    'wrong namespace returned');
end;

procedure TXmlTextReaderTest.TestReadOuterXml;
begin
  SetXmlData(
    '<?xml version="1.0" encoding="iso-8859-1"?><root><first>äöüß</first></root>');
  CheckEquals('', FXmlTextReader.ReadOuterXml);
  FXmlTextReader.Read;
  CheckEquals('<root><first>äöüß</first></root>', FXmlTextReader.ReadOuterXml);
end;

procedure TXmlTextReaderTest.TestReadString;
begin
  SetXmlData('<?xml version="1.0"?><root>contents</root>');
  FXmlTextReader.Read;
  CheckEquals('contents', FXmlTextReader.ReadString, 'ReadString failed');
end;

procedure TXmlTextReaderTest.TestParserProp;
begin
  SetXmlData('<?xml version="1.0"?><root>contents</root>');

  FXmlTextReader.ParserProperties := [];
  Check([] = FXmlTextReader.ParserProperties,
    'no ParserProperties should be set');

  FXmlTextReader.ParserProperties := [XML_PARSER_LOADDTD];
  Check([XML_PARSER_LOADDTD] = FXmlTextReader.ParserProperties,
    'XML_PARSER_LOADDTD should be set');

  FXmlTextReader.ParserProperties := [XML_PARSER_DEFAULTATTRS];
  Check([XML_PARSER_LOADDTD] = FXmlTextReader.ParserProperties,
    'XML_PARSER_DEFAULTATTRS should be set');

  // XML_PARSER_LOADDTD,       // = 1
  // XML_PARSER_DEFAULTATTRS,  // = 2
  // XML_PARSER_VALIDATE,      // = 3
  // XML_PARSER_SUBST_ENTITIES // = 4

end;

procedure TXmlTextReaderTest.TestCreateFromFile;
var
  fileName: string;
  xmlData: AnsiString;
  fileStream: TFileStream;
begin
  xmlData := '<?xml version="1.0"?><root />';
  fileName := '.\temp.xml';

  fileStream := TFileStream.Create(fileName, fmCreate);
  try
    fileStream.Write(PAnsiString(xmlData)^, length(xmlData));
  finally
    fileStream.Free;
  end;

  try
    TXmlTextReader.Create(fileName).Free;
    Check(True, 'Construction from file');
  finally
    DeleteFile(fileName);
  end;
end;

procedure TXmlTextReaderTest.TestMultipleThreads;
var
  fileName: string;
  fileStream: TFileStream;
  thread1, thread2: TTestThread;
begin
  SetXmlData('<?xml version="1.0"?><root />');

  fileName := '.\temp.xml';

  fileStream := TFileStream.Create(fileName, fmCreate);
  FDataStream.Seek(0, soFromBeginning);
  try
    fileStream.CopyFrom(FDataStream, FDataStream.Size);
  finally
    fileStream.Free;
  end;

  thread1 := TTestThread.Create(fileName);
  thread2 := TTestThread.Create(fileName);
  try
    thread1.Start;
    thread2.Start;
    thread1.WaitFor;
    thread2.WaitFor;
    Check(True, 'Construction from file twice');
  finally
    thread1.Free;
    thread2.Free;
    DeleteFile(fileName);
  end;
end;

procedure TXmlTextReaderTest.TestCreateFromNonExistingFile;
begin
  try
    TXmlTextReader.Create('does not exist').Free;
    Fail('Expected EXmlException');
  except
    on E: EXmlException do
      ;
  end;
end;

procedure TXmlTextReaderTest.TestNodeType;
begin
  SetXmlData('<?xml version="1.0"?>' + '<!DOCTYPE root [' +
      '<!ELEMENT first EMPTY>' + '<!ATTLIST first a1 CDATA #IMPLIED>' +
      '<!ATTLIST first a2 CDATA #IMPLIED>' + '<!ATTLIST first a3 CDATA "3">' +
      ']>' + '<root>' + '<first a1="1" a2="2"/>' + '</root>');

  Check(ntNone = FXmlTextReader.NodeType, 'NodeType should be None');

  FXmlTextReader.Read;
  Check(ntDocumentType = FXmlTextReader.NodeType,
    'NodeType should be DocumentType');

  FXmlTextReader.Read;
  Check(ntElement = FXmlTextReader.NodeType, 'NodeType should be Element');
end;

procedure TXmlTextReaderTest.TestSkip;
begin
  SetXmlData('<?xml version="1.0"?><root><a><c/></a><b><c/></b></root>');
  FXmlTextReader.Read;
  FXmlTextReader.Read;
  CheckEquals('a', FXmlTextReader.Name);
  FXmlTextReader.Skip;
  CheckEquals('b', FXmlTextReader.Name);
end;

procedure TXmlTextReaderTest.TestReadInvalidXmlFile;
var
  xmlFile: TFileStream;
  xmlData: AnsiString;
  xmlreader: TXmlTextReader;
begin
  xmlData := '<?xml version="1.0"?><root><a></b></root>';
  xmlFile := TFileStream.Create('temp.xml', fmCreate);
  try
    xmlFile.Write(PAnsiString(xmlData)^, length(xmlData));
    FreeAndNil(xmlFile);
    try
      xmlreader := TXmlTextReader.Create('temp.xml');
      try
        xmlreader.Read;
        Fail('Expected EXmlException');
      finally
        xmlreader.Free;
      end;
    except
      on E: EXmlException do
        ;
    end;
  finally
    xmlFile.Free;
    DeleteFile('tem.xml');
  end;
end;

procedure TXmlTextReaderTest.TestReadmeSample;
var
  xmlFile: TFileStream;
  xmlData: AnsiString;
  reader: TXmlTextReader;
begin
  xmlData := '<root>' + '  <first something="foo" somethingElse="bar" />' +
    '  <second>Baz</second>' + '</root>';
  xmlFile := TFileStream.Create('temp.xml', fmCreate);
  try
    xmlFile.WriteBuffer(PAnsiChar(xmlData)^, length(xmlData));
    FreeAndNil(xmlFile);
    reader := TXmlTextReader.Create('temp.xml');
    try
      reader.Read;
      CheckEquals('root', reader.Name);
      reader.Read; // #text because of indentation
      reader.Read;
      CheckEquals('first', reader.Name);
      CheckEquals('foo', reader.GetAttribute('something'));
      CheckEquals('bar', reader.GetAttribute('somethingElse'));
      reader.Read; // #text because of indentation
      reader.Read;
      CheckEquals('second', reader.Name);
      CheckEquals('Baz', reader.ReadString); // read 'ahead' element content
      reader.Read; // #text
      CheckEquals('Baz', reader.Value);
      reader.Read;
      reader.Read;
      CheckFalse(reader.Read); // EOF!
    finally
      xmlFile.Free;
    end;
  finally
    xmlFile.Free;
    DeleteFile('tem.xml');
  end;
end;

procedure TXmlTextReaderTest.TestRead;
begin
  SetXmlData('<?xml version="1.0" encoding="iso-8859-1"?><äöüß>äöüß</äöüß>');

  CheckEquals(True, FXmlTextReader.Read);
  CheckEquals('äöüß', FXmlTextReader.Name);
  CheckEquals(True, FXmlTextReader.Read);
  CheckEquals('#text', FXmlTextReader.Name);
  CheckEquals('äöüß', FXmlTextReader.Value);
  CheckEquals(True, FXmlTextReader.Read);
  CheckEquals('äöüß', FXmlTextReader.Name);
  CheckEquals(false, FXmlTextReader.Read);
  CheckEquals(false, FXmlTextReader.Read);
end;

procedure TXmlTextReaderTest.TestReadInnerXml;
begin
  SetXmlData(
    '<?xml version="1.0" encoding="iso-8859-1"?><root><first>äöüß</first></root>');
  CheckEquals('', FXmlTextReader.ReadOuterXml);
  FXmlTextReader.Read;
  CheckEquals('<first>äöüß</first>', FXmlTextReader.ReadInnerXml);
end;

{ TTestThread }

constructor TTestThread.Create(const fileName: string);
begin
  inherited Create(True);
  FFileName := fileName;
end;

procedure TTestThread.Execute;
var
  x: TXmlTextReader;
  i: Integer;
begin
  inherited;
  for i := 1 to 1 do
  begin
    x := TXmlTextReader.Create(FFileName);
    x.Read;
    x.Free;
  end;
end;

initialization

RegisterTest('Constructors', TXmlTextReaderTest.Suite);

end.
