Option Explicit

Dim arrTables( ), arrColumns( ), i, idxTables
Dim objConn, objFSO, objRS, objSchema, objFile
Dim strConnect, strHeader, strOutput
Dim strFile, outFile, strPass, strResult, strSQL, strTable

Const adSchemaTables = 20

' File details
strFile = "database.mdb"
strPass = "Pass"
outFile = "database.sql"

' Script starts
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.CreateTextFile(outFile,True)

' Connect to the MS-Access database
Set objConn = CreateObject( "ADODB.Connection" )
objConn.Open "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=" & strFile & ";MS Access;pwd=" & strPass

' Search for tables and list them in an array
Set objSchema = objConn.OpenSchema( adSchemaTables )
idxTables = -1
Do While Not objSchema.EOF
    If objSchema.Fields.Item(3).Value = "TABLE" Then
        idxTables = idxTables + 1
        ReDim Preserve arrTables( idxTables )
        arrTables( idxTables ) = objSchema.Fields.Item(2).Value
    End If
    objSchema.MoveNext
Loop

' Create tables and their contents
For Each strTable In arrTables
    strSQL = "Select * From " & strTable
    ' WScript.Echo strSQL
    Set objRS = objConn.Execute( strSQL )
    If IsObject( objRS ) Then
        ReDim Preserve arrColumns(0)
        strHeader = ""
        For i = 0 To objRS.Fields.Count - 1
            ReDim Preserve arrColumns(i)
            arrColumns(i) = GetDataTypeDesc(objRS.Fields.Item(i).Type)
            strHeader = strHeader & ",`" & objRS.Fields.Item(i).Name & "` " & arrColumns(i)
        Next
        objFile.Write "CREATE TABLE " & strTable & " (" & Mid(strHeader, 2) & ");" & Chr(10)
        Do While Not objRS.EOF
            strResult = ""
            For i = 0 To objRS.Fields.Count - 1
                strResult = strResult & ",""" & sqlSafe(objRS.Fields.Item(i).Value, arrColumns(i)) & """"
            Next
            ' Add the current record to the output string
            objFile.Write "INSERT INTO " & strTable & " VALUES (" & Mid( strResult, 2 ) & ");" & Chr(10)
            ' Next record
            objRS.MoveNext
        Loop
    End If
Next

objRS.Close
objSchema.Close
objConn.Close
objFile.Close
Set objRS     = Nothing
Set objSchema = Nothing
Set objConn   = Nothing
Set objFile   = Nothing

Function sqlSafe(val, t)
    If IsNull(val) Then
        sqlSafe = ""
    Else
        If t = "Date" Then
            Dim p : p = Split(val, "/")
            sqlSafe = p(2) & "-" & p(0) & "-" & p(1)
        Else
            val = Replace(val, Chr(10), "")
            val = Replace(val, Chr(13), "")
            val = Replace(val, "'", "\'")
            sqlSafe = Replace(val, """", "\""")
        End If
    End If
End Function

Function GetDataTypeDesc( myTypeNum )
    Dim arrTypes( 8192 ), i
    For i = 0 To UBound( arrTypes )
        arrTypes( i ) = "????"
    Next
    arrTypes(0)     = "Empty"
    arrTypes(2)     = "SmallInt"
    arrTypes(3)     = "Integer"
    arrTypes(4)     = "Single"
    arrTypes(5)     = "Double"
    arrTypes(6)     = "Currency"
    arrTypes(7)     = "Date"
    arrTypes(8)     = "BSTR"
    arrTypes(9)     = "IDispatch"
    arrTypes(10)    = "Error"
    arrTypes(11)    = "Boolean"
    arrTypes(12)    = "Variant"
    arrTypes(13)    = "IUnknown"
    arrTypes(14)    = "Decimal"
    arrTypes(16)    = "TinyInt"
    arrTypes(17)    = "UnsignedTinyInt"
    arrTypes(18)    = "UnsignedSmallInt"
    arrTypes(19)    = "UnsignedInt"
    arrTypes(20)    = "BigInt"
    arrTypes(21)    = "UnsignedBigInt"
    arrTypes(64)    = "FileTime"
    arrTypes(72)    = "GUID"
    arrTypes(128)   = "Binary"
    arrTypes(129)   = "Char"
    arrTypes(130)   = "WChar"
    arrTypes(131)   = "Numeric"
    arrTypes(132)   = "UserDefined"
    arrTypes(133)   = "DBDate"
    arrTypes(134)   = "DBTime"
    arrTypes(135)   = "DBTimeStamp"
    arrTypes(136)   = "Chapter"
    arrTypes(138)   = "PropVariant"
    arrTypes(139)   = "VarNumeric"
    arrTypes(200)   = "VarChar"
    arrTypes(201)   = "LongVarChar"
    arrTypes(202)   = "TEXT"
    arrTypes(203)   = "LongVarWChar"
    arrTypes(204)   = "VarBinary"
    arrTypes(205)   = "LongVarBinary"
    arrTypes(8192)  = "Array"
    GetDataTypeDesc = arrTypes( myTypeNum )
End Function